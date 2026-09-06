import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'interstitial_ad_service.dart';

/// Small abstraction around a banner so screens can be tested without ads.
abstract class BannerAdService extends ChangeNotifier {
  bool get isLoaded;
  bool get isLoading;
  double get height;

  Future<void> load({required double width});
  Widget buildAdWidget();
}

class GoogleBannerAdService extends BannerAdService {
  GoogleBannerAdService(this._adsService) {
    _adsService.addListener(_handleAdsStateChanged);
  }

  final InterstitialAdService _adsService;
  BannerAd? _ad;
  AdSize? _size;
  bool _isLoading = false;
  bool _attempted = false;
  bool _isDisposed = false;

  @override
  bool get isLoaded => _ad != null;

  @override
  bool get isLoading => _isLoading;

  @override
  double get height => (_size?.height ?? 50).toDouble();

  @override
  Future<void> load({required double width}) async {
    if (_isDisposed ||
        _adsService.isAdsRemoved ||
        _isLoading ||
        isLoaded ||
        _attempted ||
        width <= 0) {
      return;
    }
    if (!_adsService.adsSdkReady || !_adsService.canRequestAds) return;

    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      width.truncate(),
    );
    if (_isDisposed || size == null) return;

    _attempted = true;
    _isLoading = true;
    notifyListeners();
    final adUnitId = _adUnitId;
    if (adUnitId == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    BannerAd(
      adUnitId: adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _isLoading = false;
          if (_isDisposed || ad is! BannerAd) {
            unawaited(ad.dispose());
            return;
          }
          _ad = ad;
          _size = size;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          _isLoading = false;
          unawaited(ad.dispose());
          if (kDebugMode) {
            debugPrint(
              '[Ads] Banner load failed: ${error.code}/${error.domain} '
              '${error.message}',
            );
          }
          notifyListeners();
        },
      ),
    ).load();
  }

  String? get _adUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
      if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
      return null;
    }
    final value = Platform.isAndroid
        ? const String.fromEnvironment('ADMOB_ANDROID_BANNER_AD_UNIT_ID')
        : Platform.isIOS
        ? const String.fromEnvironment('ADMOB_IOS_BANNER_AD_UNIT_ID')
        : '';
    if (value.isEmpty || value.startsWith('ca-app-pub-3940256099942544/')) {
      debugPrint('[Ads] Banner disabled: release ad unit is not configured.');
      return null;
    }
    return value;
  }

  @override
  Widget buildAdWidget() =>
      _ad == null ? const SizedBox.shrink() : AdWidget(ad: _ad!);

  @override
  void dispose() {
    _isDisposed = true;
    final ad = _ad;
    _ad = null;
    if (ad != null) unawaited(ad.dispose());
    _adsService.removeListener(_handleAdsStateChanged);
    super.dispose();
  }

  void _handleAdsStateChanged() {
    if (!_adsService.isAdsRemoved) return;
    final ad = _ad;
    _ad = null;
    _size = null;
    if (ad != null) unawaited(ad.dispose());
    notifyListeners();
  }
}

/// Adds no layout space until the banner has loaded successfully.
class LearningBannerSlot extends StatefulWidget {
  const LearningBannerSlot({required this.service, super.key});

  final BannerAdService service;

  @override
  State<LearningBannerSlot> createState() => _LearningBannerSlotState();
}

class _LearningBannerSlotState extends State<LearningBannerSlot> {
  bool _loadScheduled = false;

  void _scheduleLoad(double width) {
    if (_loadScheduled || widget.service.isLoaded || widget.service.isLoading) {
      return;
    }
    _loadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScheduled = false;
      if (mounted) unawaited(widget.service.load(width: width));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            if (!widget.service.isLoaded) {
              _scheduleLoad(constraints.maxWidth);
              return const SizedBox.shrink();
            }
            return SafeArea(
              top: false,
              child: SizedBox(
                height: widget.service.height,
                width: double.infinity,
                child: Center(child: widget.service.buildAdWidget()),
              ),
            );
          },
        );
      },
    );
  }
}
