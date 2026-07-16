import 'package:kelimo/services/learning_engine.dart';

class ReviewSchedule {
  const ReviewSchedule({required this.reviewStage, required this.nextReviewAt});

  final int reviewStage;
  final DateTime nextReviewAt;
}

class ReviewScheduler {
  ReviewScheduler({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const maxStage = 6;
  static const _easyIntervals = <int, Duration>{
    1: Duration(days: 1),
    2: Duration(days: 3),
    3: Duration(days: 7),
    4: Duration(days: 14),
    5: Duration(days: 30),
    6: Duration(days: 60),
  };

  final DateTime Function() _now;

  DateTime get currentTime => _now().toUtc();

  static ReviewSchedule? legacySchedule({
    required String mastery,
    required DateTime migratedAt,
    DateTime? lastReviewedAt,
    DateTime? existingNextReviewAt,
  }) {
    final migrationTime = migratedAt.toUtc();
    if (mastery == 'again' || mastery == 'hard') {
      return ReviewSchedule(reviewStage: 0, nextReviewAt: migrationTime);
    }
    if (mastery != 'easy') return null;

    return ReviewSchedule(
      reviewStage: 1,
      nextReviewAt:
          existingNextReviewAt?.toUtc() ??
          (lastReviewedAt?.toUtc() ?? migrationTime).add(
            const Duration(days: 1),
          ),
    );
  }

  ReviewSchedule schedule({
    required LearningRating rating,
    required int currentStage,
    DateTime? reviewedAt,
  }) {
    final now = (reviewedAt ?? _now()).toUtc();
    final safeStage = currentStage.clamp(0, maxStage);

    return switch (rating) {
      LearningRating.again => ReviewSchedule(reviewStage: 0, nextReviewAt: now),
      LearningRating.hard => ReviewSchedule(
        reviewStage: (safeStage - 1).clamp(0, maxStage),
        nextReviewAt: now.add(const Duration(days: 1)),
      ),
      LearningRating.easy => _scheduleEasy(safeStage, now),
    };
  }

  ReviewSchedule _scheduleEasy(int currentStage, DateTime now) {
    final nextStage = (currentStage + 1).clamp(1, maxStage);
    return ReviewSchedule(
      reviewStage: nextStage,
      nextReviewAt: now.add(_easyIntervals[nextStage]!),
    );
  }
}
