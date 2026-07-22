import 'package:kelimo/models/xp_state.dart';

class RewardedBonusState {
  const RewardedBonusState({required this.dateKey, required this.usedCount});

  static const dailyLimit = 2;
  static const xpPerReward = 15;

  final String dateKey;
  final int usedCount;

  int get remainingCount => (dailyLimit - usedCount).clamp(0, dailyLimit);
  bool get isExhausted => remainingCount == 0;
}

class RewardedBonusClaim {
  const RewardedBonusClaim({
    required this.wasAwarded,
    required this.xpState,
    required this.bonusState,
  });

  final bool wasAwarded;
  final XpState xpState;
  final RewardedBonusState bonusState;
}

enum RewardedAdOutcome { rewarded, dismissed, unavailable, failed }

class RewardedAdResult {
  const RewardedAdResult({required this.outcome, this.claimId});

  final RewardedAdOutcome outcome;
  final String? claimId;
}

enum RewardedBonusResult { awarded, exhausted, unavailable, dismissed, failed }
