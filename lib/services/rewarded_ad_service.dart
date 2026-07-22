import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimo/models/rewarded_bonus.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';

abstract class RewardedAdService extends ChangeNotifier {
  bool get isEnabled;
  bool get isLoading;
  bool get isReady;

  Future<void> initialize();
  Future<void> preload();
  Future<bool> ensureReady({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (isReady) return true;
    await preload();
    if (isReady) return true;
    final completer = Completer<bool>();
    late final VoidCallback listener;
    Timer? timer;
    listener = () {
      if (isReady && !completer.isCompleted) completer.complete(true);
    };
    addListener(listener);
    timer = Timer(timeout, () {
      if (!completer.isCompleted) completer.complete(false);
    });
    try {
      return await completer.future;
    } finally {
      timer.cancel();
      removeListener(listener);
    }
  }

  Future<RewardedAdResult> show();
}

class RewardedLoadGate {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  bool tryStart() {
    if (_isLoading) return false;
    _isLoading = true;
    return true;
  }

  void finish() => _isLoading = false;
}

Duration rewardedRetryDelay(int attempt) {
  const delays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  return delays[attempt.clamp(0, delays.length - 1)];
}

String? resolveRewardedAdUnitId({
  required bool isRelease,
  required String platform,
  required String releaseId,
}) {
  if (isRelease) return releaseId.trim().isEmpty ? null : releaseId.trim();
  return switch (platform) {
    'android' => GoogleRewardedAdService.androidTestRewardedAdUnitId,
    'ios' => GoogleRewardedAdService.iosTestRewardedAdUnitId,
    _ => null,
  };
}

class GoogleRewardedAdService extends RewardedAdService {
  GoogleRewardedAdService(this._consentService);

  static const androidTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const iosTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/1712485313';

  final InterstitialAdService _consentService;
  final RewardedLoadGate _loadGate = RewardedLoadGate();
  RewardedAd? _ad;
  bool _isShowing = false;
  bool _isDisposed = false;
  int _claimSequence = 0;
  int _retryAttempt = 0;
  Timer? _retryTimer;
  Future<void>? _consentWait;

  @override
  bool get isEnabled => _adUnitId != null;

  @override
  bool get isLoading => _loadGate.isLoading;

  @override
  bool get isReady => !_isShowing && _ad != null;

  @override
  Future<void> initialize() async {
    if (kDebugMode) debugPrint('[Ads] Rewarded service initialization started');
    _consentService.addListener(_handleConsentChanged);
    await _ensureConsentThenPreload();
  }

  void _handleConsentChanged() {
    if (_consentService.adsSdkReady) unawaited(preload());
  }

  Future<void> _ensureConsentThenPreload() async {
    if (_isDisposed || !isEnabled) return;
    if (_consentService.adsSdkReady) {
      await preload();
      return;
    }
    final activeWait = _consentWait;
    if (activeWait != null) return activeWait;
    final wait = () async {
      await _consentService.requestConsentIfNeeded();
      if (_consentService.adsSdkReady) await preload();
    }();
    _consentWait = wait;
    try {
      await wait;
    } finally {
      if (identical(_consentWait, wait)) _consentWait = null;
    }
  }

  @override
  Future<void> preload() async {
    if (_isDisposed || !isEnabled || _ad != null) {
      return;
    }
    if (!_consentService.adsSdkReady) {
      unawaited(_ensureConsentThenPreload());
      return;
    }
    if (!_loadGate.tryStart()) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    final adUnitId = _adUnitId;
    if (adUnitId == null) {
      _loadGate.finish();
      return;
    }
    notifyListeners();
    if (kDebugMode) {
      debugPrint('[Ads] Rewarded load requested');
      debugPrint('[Ads] Platform: $_platformName');
      debugPrint(
        '[Ads] Test/production configuration: '
        '${kReleaseMode ? 'production' : 'test'}',
      );
    }
    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _loadGate.finish();
            _retryAttempt = 0;
            if (_isDisposed) {
              unawaited(ad.dispose());
              return;
            }
            _ad = ad;
            if (kDebugMode) {
              debugPrint('[Ads] Rewarded loaded');
            }
            notifyListeners();
          },
          onAdFailedToLoad: (error) {
            _loadGate.finish();
            _logLoadError(error);
            notifyListeners();
            _scheduleRetry();
          },
        ),
      );
    } catch (error, stackTrace) {
      _loadGate.finish();
      debugPrint('[Ads] Rewarded load request failed: $error\n$stackTrace');
      notifyListeners();
      _scheduleRetry();
    }
  }

  @override
  Future<RewardedAdResult> show() async {
    final ad = _ad;
    if (!isEnabled || !_consentService.adsSdkReady || ad == null) {
      if (kDebugMode) {
        debugPrint('[Ads] Rewarded show requested while preparing');
      }
      unawaited(preload());
      return const RewardedAdResult(outcome: RewardedAdOutcome.unavailable);
    }
    if (_isShowing) {
      return const RewardedAdResult(outcome: RewardedAdOutcome.unavailable);
    }

    _ad = null;
    _isShowing = true;
    if (kDebugMode) debugPrint('[Ads] Rewarded show requested');
    notifyListeners();
    var earnedReward = false;
    final claimId =
        'reward-${DateTime.now().toUtc().microsecondsSinceEpoch}-'
        '${_claimSequence++}';
    final completer = Completer<RewardedAdResult>();

    void finish(RewardedAdOutcome outcome) {
      if (!completer.isCompleted) {
        completer.complete(
          RewardedAdResult(
            outcome: outcome,
            claimId: earnedReward ? claimId : null,
          ),
        );
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (dismissedAd) async {
        await dismissedAd.dispose();
        _isShowing = false;
        if (kDebugMode) debugPrint('[Ads] Ad dismissed');
        finish(
          earnedReward
              ? RewardedAdOutcome.rewarded
              : RewardedAdOutcome.dismissed,
        );
        notifyListeners();
        unawaited(preload());
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) async {
        debugPrint('Ödüllü reklam gösterilemedi: $error');
        await failedAd.dispose();
        _isShowing = false;
        finish(RewardedAdOutcome.failed);
        notifyListeners();
        unawaited(preload());
      },
    );
    try {
      await ad.show(
        onUserEarnedReward: (_, reward) {
          if (kDebugMode) debugPrint('[Ads] Reward callback received');
          earnedReward = true;
          finish(RewardedAdOutcome.rewarded);
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Ödüllü reklam açılamadı: $error\n$stackTrace');
      await ad.dispose();
      _isShowing = false;
      finish(RewardedAdOutcome.failed);
      notifyListeners();
      unawaited(preload());
    }
    return completer.future;
  }

  String? get _adUnitId {
    const releaseId = String.fromEnvironment('ADMOB_REWARDED_AD_UNIT_ID');
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
        ? 'ios'
        : 'other';
    return resolveRewardedAdUnitId(
      isRelease: kReleaseMode,
      platform: platform,
      releaseId: releaseId,
    );
  }

  void _scheduleRetry() {
    if (_isDisposed ||
        !isEnabled ||
        !_consentService.adsSdkReady ||
        _retryTimer != null ||
        _retryAttempt >= 3) {
      return;
    }
    final delay = rewardedRetryDelay(_retryAttempt);
    _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (!_isDisposed) unawaited(preload());
    });
  }

  void _logLoadError(LoadAdError error) {
    if (!kDebugMode) {
      debugPrint('Ödüllü reklam yüklenemedi.');
      return;
    }
    debugPrint(
      '[Ads] Rewarded load failed: platform=$_platformName, tür=test, '
      'code=${error.code}, domain=${error.domain}, message=${error.message}, '
      'responseInfo=${error.responseInfo}',
    );
  }

  String get _platformName => Platform.isAndroid
      ? 'android'
      : Platform.isIOS
      ? 'ios'
      : 'other';

  @override
  void dispose() {
    _isDisposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _consentService.removeListener(_handleConsentChanged);
    final ad = _ad;
    _ad = null;
    if (ad != null) unawaited(ad.dispose());
    super.dispose();
  }
}

class DisabledRewardedAdService extends RewardedAdService {
  @override
  bool get isEnabled => false;
  @override
  bool get isLoading => false;
  @override
  bool get isReady => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> preload() async {}
  @override
  Future<RewardedAdResult> show() async =>
      const RewardedAdResult(outcome: RewardedAdOutcome.unavailable);
}
