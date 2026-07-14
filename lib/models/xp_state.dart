class XpState {
  const XpState({required this.totalXp, required this.updatedAt})
    : assert(totalXp >= 0);

  factory XpState.initial({DateTime? now}) {
    return XpState(totalXp: 0, updatedAt: now ?? DateTime.now());
  }

  factory XpState.fromMap(Map<String, Object?> map) {
    return XpState(
      totalXp: map['total_xp']! as int,
      updatedAt: DateTime.parse(map['updated_at']! as String),
    );
  }

  final int totalXp;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'total_xp': totalXp,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
