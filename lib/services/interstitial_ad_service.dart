import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimo/models/ad_display_state.dart';
import 'package:kelimo/repositories/ad_frequency_repository.dart';

abstract class InterstitialAdService extends ChangeNotifier {
  bool get privacyOptionsRequired;
  bool get canShow;
  bool get canRequestAds => false;
  bool get adsSdkReady => canRequestAds;

  Future<void> initialize();
  Future<void> requestConsentIfNeeded();
  Future<void> preload();
  Future<void> recordQuizCompleted();
  Future<bool> showIfEligible();
  Future<bool> showTestAd();
  Future<bool> showPrivacyOptions();
  void setForeground(bool isForeground);
}

class InterstitialAdPolicy {
  const InterstitialAdPolicy({
    this.minimumQuizCount = 3,
    this.minimumInterval = const Duration(minutes: 15),
  });

  final int minimumQuizCount;
  final Duration minimumInterval;

  bool isEligible({
    required AdDisplayState state,
    required DateTime now,
    required bool isForeground,
    required bool canRequestAds,
    required bool isAdReady,
  }) {
    if (!isForeground || !canRequestAds || !isAdReady) return false;
    if (state.completedQuizCountSinceLastAd < minimumQuizCount) return false;
    final lastShownAt = state.lastInterstitialShownAt;
    if (lastShownAt == null) return true;
    return !now.toUtc().isBefore(lastShownAt.add(minimumInterval));
  }
}

class GoogleInterstitialAdService extends InterstitialAdService {
  GoogleInterstitialAdService(this._repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const minimumQuizCount = 3;
  static const minimumInterval = Duration(minutes: 15);
  static const androidTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const iosTestInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/4411468910';

  final AdFrequencyStore _repository;
  final DateTime Function() _now;
  final InterstitialAdPolicy _policy = const InterstitialAdPolicy();
  AdDisplayState _state = AdDisplayState.initial;
  InterstitialAd? _ad;
  bool _canRequestAds = false;
  bool _adsSdkReady = false;
  bool _privacyOptionsRequired = false;
  bool _isForeground = true;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _isDisposed = false;
  Future<void>? _consentRequest;
  bool _mobileAdsInitialized = false;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  bool get adsSdkReady => _adsSdkReady;

  @override
  bool get canShow =>
      !_isShowing &&
      _policy.isEligible(
        state: _state,
        now: _now(),
        isForeground: _isForeground,
        canRequestAds: _canRequestAds,
        isAdReady: _ad != null,
      );

  @override
  Future<void> initialize() async {
    try {
      _state = await _repository.load();
      await requestConsentIfNeeded();
    } catch (error, stackTrace) {
      debugPrint('Reklam servisi başlatılamadı: $error\n$stackTrace');
    }
  }

  @override
  Future<void> requestConsentIfNeeded() async {
    final activeRequest = _consentRequest;
    if (activeRequest != null) return activeRequest;
    final request = _requestConsentIfNeeded();
    _consentRequest = request;
    try {
      await request;
    } finally {
      if (identical(_consentRequest, request)) _consentRequest = null;
    }
  }

  Future<void> _requestConsentIfNeeded() async {
    if (kDebugMode) debugPrint('[Ads] Consent initialization started');
    final updateCompleter = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (kDebugMode) debugPrint('[Ads] Consent initialization completed');
        updateCompleter.complete();
      },
      (error) {
        debugPrint(
          '[Ads] Consent initialization failed: code=${error.errorCode}, '
          'message=${error.message}',
        );
        updateCompleter.complete();
      },
    );
    await updateCompleter.future;

    final formCompleter = Completer<void>();
    await ConsentForm.loadAndShowConsentFormIfRequired((error) {
      if (error != null) {
        debugPrint(
          '[Ads] Consent form failed: code=${error.errorCode} ${error.message}',
        );
      }
      formCompleter.complete();
    });
    await formCompleter.future;
    await _refreshConsentState();
  }

  Future<void> _refreshConsentState() async {
    try {
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      _privacyOptionsRequired =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (kDebugMode) {
        debugPrint('[Ads] Consent status: canRequestAds=$_canRequestAds');
        debugPrint(
          '[Ads] Privacy options requirement status: '
          '${_privacyOptionsRequired ? 'required' : 'not_required'}',
        );
        debugPrint('[Ads] canRequestAds: $_canRequestAds');
      }
      if (!_canRequestAds) {
        _adsSdkReady = false;
        notifyListeners();
        return;
      }
      if (!_mobileAdsInitialized) {
        if (kDebugMode) debugPrint('[Ads] MobileAds initialization started');
        await MobileAds.instance.initialize();
        _mobileAdsInitialized = true;
        if (kDebugMode) debugPrint('[Ads] MobileAds initialization completed');
      }
      _adsSdkReady = true;
      notifyListeners();
      await preload();
    } catch (error, stackTrace) {
      debugPrint('[Ads] Consent state read failed: $error\n$stackTrace');
    }
  }

  @override
  Future<void> preload() async {
    if (!_canRequestAds || _isLoading || _ad != null || _isDisposed) return;
    final adUnitId = _adUnitId;
    if (adUnitId == null) {
      debugPrint('Release interstitial Ad Unit ID yapılandırılmamış.');
      return;
    }
    _isLoading = true;
    await InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          if (_isDisposed) {
            unawaited(ad.dispose());
            return;
          }
          _ad = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          debugPrint('Interstitial reklam yüklenemedi: $error');
          notifyListeners();
        },
      ),
    );
  }

  @override
  Future<void> recordQuizCompleted() async {
    try {
      _state = await _repository.recordQuizCompleted();
      notifyListeners();
      await preload();
    } catch (error, stackTrace) {
      debugPrint('Reklam quiz sayacı kaydedilemedi: $error\n$stackTrace');
    }
  }

  @override
  Future<bool> showIfEligible() async {
    if (!canShow) return false;
    return _show(recordFrequency: true);
  }

  @override
  Future<bool> showTestAd() async {
    if (!_isForeground || !_canRequestAds || _ad == null || _isShowing) {
      return false;
    }
    return _show(recordFrequency: false);
  }

  Future<bool> _show({required bool recordFrequency}) async {
    final ad = _ad;
    if (ad == null) return false;
    _ad = null;
    _isShowing = true;
    notifyListeners();
    final completer = Completer<bool>();

    void finish(bool shown) {
      if (!completer.isCompleted) completer.complete(shown);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (dismissedAd) async {
        await dismissedAd.dispose();
        _isShowing = false;
        if (recordFrequency) {
          try {
            _state = await _repository.recordInterstitialShown(_now().toUtc());
          } catch (error, stackTrace) {
            debugPrint(
              'Reklam gösterim durumu kaydedilemedi: $error\n$stackTrace',
            );
          }
        }
        finish(true);
        notifyListeners();
        unawaited(preload());
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) async {
        debugPrint('Interstitial reklam gösterilemedi: $error');
        await failedAd.dispose();
        _isShowing = false;
        finish(false);
        notifyListeners();
        unawaited(preload());
      },
    );
    try {
      await ad.show();
    } catch (error, stackTrace) {
      debugPrint('Interstitial reklam açılamadı: $error\n$stackTrace');
      await ad.dispose();
      _isShowing = false;
      finish(false);
      notifyListeners();
      unawaited(preload());
    }
    return completer.future;
  }

  @override
  Future<bool> showPrivacyOptions() async {
    final completer = Completer<bool>();
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) {
          debugPrint(
            'Gizlilik seçenekleri açılamadı: ${error.errorCode} '
            '${error.message}',
          );
          completer.complete(false);
          return;
        }
        completer.complete(true);
      });
      final shown = await completer.future;
      await _refreshConsentState();
      return shown;
    } catch (error, stackTrace) {
      debugPrint('Gizlilik seçenekleri açılamadı: $error\n$stackTrace');
      return false;
    }
  }

  @override
  void setForeground(bool isForeground) {
    _isForeground = isForeground;
    notifyListeners();
    if (isForeground) unawaited(preload());
  }

  String? get _adUnitId {
    if (!kReleaseMode) {
      if (Platform.isAndroid) return androidTestInterstitialAdUnitId;
      if (Platform.isIOS) return iosTestInterstitialAdUnitId;
      return null;
    }
    const releaseAdUnitId = String.fromEnvironment(
      'ADMOB_INTERSTITIAL_AD_UNIT_ID',
    );
    return releaseAdUnitId.isEmpty ? null : releaseAdUnitId;
  }

  @override
  void dispose() {
    _isDisposed = true;
    final ad = _ad;
    _ad = null;
    if (ad != null) unawaited(ad.dispose());
    super.dispose();
  }
}
