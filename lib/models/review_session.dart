import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/services/learning_engine.dart';

class ReviewSessionItem {
  const ReviewSessionItem({
    required this.category,
    required this.word,
    required this.nextReviewAt,
  });

  final LearningCategory category;
  final Word word;
  final DateTime nextReviewAt;
}

class ReviewSessionSummary {
  const ReviewSessionSummary({
    required this.totalCount,
    required this.easyCount,
    required this.againCount,
    required this.hardCount,
  });

  final int totalCount;
  final int easyCount;
  final int againCount;
  final int hardCount;
}

class ReviewSessionCounter {
  int _easyCount = 0;
  int _againCount = 0;
  int _hardCount = 0;

  void record(LearningRating rating) {
    switch (rating) {
      case LearningRating.easy:
        _easyCount++;
        break;
      case LearningRating.again:
        _againCount++;
        break;
      case LearningRating.hard:
        _hardCount++;
        break;
    }
  }

  ReviewSessionSummary summary(int totalCount) {
    return ReviewSessionSummary(
      totalCount: totalCount,
      easyCount: _easyCount,
      againCount: _againCount,
      hardCount: _hardCount,
    );
  }
}
