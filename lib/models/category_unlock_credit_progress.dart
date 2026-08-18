class CategoryUnlockCreditProgress {
  const CategoryUnlockCreditProgress({
    required this.newCreditsEarned,
    required this.availableCredits,
    required this.lockedCategoryCount,
    required this.xpUntilNextCredit,
    required this.currentXp,
    this.progressStartXp,
    this.nextCreditXp,
  }) : assert(newCreditsEarned >= 0),
       assert(availableCredits >= 0),
       assert(lockedCategoryCount >= 0),
       assert(xpUntilNextCredit >= 0),
       assert(currentXp >= 0),
       assert(
         (progressStartXp == null && nextCreditXp == null) ||
             (progressStartXp != null &&
                 nextCreditXp != null &&
                 nextCreditXp >= progressStartXp),
       );

  final int newCreditsEarned;
  final int availableCredits;
  final int lockedCategoryCount;
  final int xpUntilNextCredit;
  final int currentXp;
  final int? progressStartXp;
  final int? nextCreditXp;

  bool get hasLockedCategories => lockedCategoryCount > 0;

  double get progressToNextCredit {
    final start = progressStartXp;
    final target = nextCreditXp;
    if (start == null || target == null || target <= start) return 0;
    return ((currentXp - start) / (target - start)).clamp(0.0, 1.0);
  }
}
