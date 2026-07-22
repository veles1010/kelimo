class CategoryUnlock {
  const CategoryUnlock({
    required this.categoryId,
    required this.unlockedAt,
    required this.consumesCredit,
  });

  factory CategoryUnlock.fromMap(Map<String, Object?> map) {
    return CategoryUnlock(
      categoryId: map['category_id']! as String,
      unlockedAt: DateTime.parse(map['unlocked_at']! as String).toUtc(),
      consumesCredit: map['consumes_credit'] == 1,
    );
  }

  final String categoryId;
  final DateTime unlockedAt;
  final bool consumesCredit;

  Map<String, Object?> toMap() => {
    'category_id': categoryId,
    'unlocked_at': unlockedAt.toUtc().toIso8601String(),
    'consumes_credit': consumesCredit ? 1 : 0,
  };
}
