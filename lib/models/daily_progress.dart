class DailyProgress {
  const DailyProgress({
    required this.dateKey,
    required this.reviewCount,
    required this.isGoalCompleted,
    required this.streakAwarded,
  });

  factory DailyProgress.initial(String dateKey) {
    return DailyProgress(
      dateKey: dateKey,
      reviewCount: 0,
      isGoalCompleted: false,
      streakAwarded: false,
    );
  }

  factory DailyProgress.fromMap(Map<String, Object?> map) {
    return DailyProgress(
      dateKey: map['date_key']! as String,
      reviewCount: map['review_count']! as int,
      isGoalCompleted: map['is_goal_completed'] == 1,
      streakAwarded: map['streak_awarded'] == 1,
    );
  }

  final String dateKey;
  final int reviewCount;
  final bool isGoalCompleted;
  final bool streakAwarded;

  Map<String, Object?> toMap() {
    return {
      'date_key': dateKey,
      'review_count': reviewCount,
      'is_goal_completed': isGoalCompleted ? 1 : 0,
      'streak_awarded': streakAwarded ? 1 : 0,
    };
  }
}

class StreakState {
  const StreakState({required this.currentStreak, this.lastCompletedDate});

  factory StreakState.fromMap(Map<String, Object?> map) {
    final date = map['last_completed_date'];
    return StreakState(
      currentStreak: map['current_streak']! as int,
      lastCompletedDate: date == null ? null : DateTime.parse(date as String),
    );
  }

  final int currentStreak;
  final DateTime? lastCompletedDate;

  Map<String, Object?> toMap() {
    return {
      'current_streak': currentStreak,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
    };
  }
}

class DailyProgressSnapshot {
  const DailyProgressSnapshot({
    required this.progress,
    required this.streak,
    this.justCompleted = false,
  });

  final DailyProgress progress;
  final StreakState streak;
  final bool justCompleted;
}

String localDateKey(DateTime date) {
  final local = date.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

DateTime? parseLocalDateKey(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.tryParse(match.group(1)!);
  final month = int.tryParse(match.group(2)!);
  final day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}
