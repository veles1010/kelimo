import 'package:flutter/foundation.dart';
import 'package:kelimo/models/rewarded_bonus.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/services/rewarded_ad_service.dart';
import 'package:kelimo/services/xp_service.dart';

class RewardedBonusService extends ChangeNotifier {
  RewardedBonusService({
    required this.repository,
    required this.adService,
    required this.xpService,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final RewardedXpStore repository;
  final RewardedAdService adService;
  final XpService xpService;
  final DateTime Function() _now;

  RewardedBonusState _state = const RewardedBonusState(
    dateKey: '',
    usedCount: 0,
  );
  bool _isBusy = false;

  int get remainingCount => _state.remainingCount;
  bool get isExhausted => _state.isExhausted;
  bool get isBusy =>
      _isBusy || adService.isLoading || adService.isWaitingForRetry;
  bool get isAdLoading => adService.isLoading;
  bool get isWaitingForRetry => adService.isWaitingForRetry;
  Duration? get retryAfter => adService.retryAfter;
  bool get isAdReady => adService.isReady;
  bool get isEnabled => adService.isEnabled;

  Future<void> initialize() async {
    await refresh();
    await adService.initialize();
    adService.addListener(_handleAdChanged);
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _state = await repository.loadRewardedBonusState(_now());
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Günlük XP bonusu yüklenemedi: $error\n$stackTrace');
    }
  }

  Future<RewardedBonusResult> watchAd() async {
    if (_isBusy) return RewardedBonusResult.unavailable;
    await refresh();
    if (_state.isExhausted) return RewardedBonusResult.exhausted;
    _isBusy = true;
    notifyListeners();
    try {
      if (!adService.isEnabled) return RewardedBonusResult.unavailable;
      if (!await adService.ensureReady()) {
        return RewardedBonusResult.unavailable;
      }
      final result = await adService.show();
      if (result.outcome != RewardedAdOutcome.rewarded ||
          result.claimId == null) {
        return switch (result.outcome) {
          RewardedAdOutcome.dismissed => RewardedBonusResult.dismissed,
          RewardedAdOutcome.unavailable => RewardedBonusResult.unavailable,
          _ => RewardedBonusResult.failed,
        };
      }
      final claim = await repository.claimRewardedBonus(
        claimId: result.claimId!,
        awardedAt: _now(),
      );
      _state = claim.bonusState;
      xpService.applyPersistedState(claim.xpState);
      return claim.wasAwarded
          ? RewardedBonusResult.awarded
          : _state.isExhausted
          ? RewardedBonusResult.exhausted
          : RewardedBonusResult.failed;
    } catch (error, stackTrace) {
      debugPrint('Günlük XP bonusu uygulanamadı: $error\n$stackTrace');
      return RewardedBonusResult.failed;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void resetAfterDataClear() {
    _state = RewardedBonusState(dateKey: _localDateKey(_now()), usedCount: 0);
    notifyListeners();
  }

  void _handleAdChanged() => notifyListeners();

  @override
  void dispose() {
    adService.removeListener(_handleAdChanged);
    adService.dispose();
    super.dispose();
  }
}

String _localDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
