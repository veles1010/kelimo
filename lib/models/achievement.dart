enum AchievementType {
  totalReviews,
  learnedWords,
  favorites,
  completedQuizzes,
  perfectQuiz,
  streak,
  mosaicCompletion,
}

class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.target,
    required this.type,
  });

  final String id;
  final String title;
  final String description;
  final String emoji;
  final int target;
  final AchievementType type;

  int progress(AchievementMetrics metrics) {
    return switch (type) {
      AchievementType.totalReviews => metrics.totalReviewCount,
      AchievementType.learnedWords => metrics.learnedWordCount,
      AchievementType.favorites => metrics.favoriteWordCount,
      AchievementType.completedQuizzes => metrics.completedQuizCount,
      AchievementType.perfectQuiz => metrics.hasPerfectQuiz ? 1 : 0,
      AchievementType.streak => metrics.currentStreak,
      AchievementType.mosaicCompletion => metrics.learnedWordCount,
    };
  }

  bool isMet(AchievementMetrics metrics) => progress(metrics) >= target;
}

class AchievementMetrics {
  const AchievementMetrics({
    required this.totalReviewCount,
    required this.learnedWordCount,
    required this.favoriteWordCount,
    required this.completedQuizCount,
    required this.hasPerfectQuiz,
    required this.currentStreak,
  });

  static const empty = AchievementMetrics(
    totalReviewCount: 0,
    learnedWordCount: 0,
    favoriteWordCount: 0,
    completedQuizCount: 0,
    hasPerfectQuiz: false,
    currentStreak: 0,
  );

  final int totalReviewCount;
  final int learnedWordCount;
  final int favoriteWordCount;
  final int completedQuizCount;
  final bool hasPerfectQuiz;
  final int currentStreak;
}

class AchievementUnlock {
  const AchievementUnlock({
    required this.achievementId,
    required this.unlockedAt,
  });

  factory AchievementUnlock.fromMap(Map<String, Object?> map) {
    return AchievementUnlock(
      achievementId: map['achievement_id']! as String,
      unlockedAt: DateTime.parse(map['unlocked_at']! as String).toUtc(),
    );
  }

  final String achievementId;
  final DateTime unlockedAt;

  Map<String, Object?> toMap() {
    return {
      'achievement_id': achievementId,
      'unlocked_at': unlockedAt.toUtc().toIso8601String(),
    };
  }
}
