import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/utils/review_time_label.dart';

class LearningCenterService {
  LearningCenterService({
    required this.wordProgressStore,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final WordProgressStore wordProgressStore;
  final DateTime Function() _now;

  LearningCenterSnapshot load() {
    final now = _now();
    final progressByWordId = {
      for (final progress in wordProgressStore.getAllProgress())
        progress.wordId: progress,
    };
    final words = <LearningCenterWord>[];

    for (final category in CategoryCatalog.categories) {
      if (!category.isAvailable) continue;
      for (final word in category.words) {
        final progress =
            progressByWordId[word.id] ?? WordProgress.initial(word.id);
        final nextReviewAt = progress.nextReviewAt;
        words.add(
          LearningCenterWord(
            category: category,
            word: word,
            progress: progress,
            status: _statusFor(progress),
            isReviewDue:
                nextReviewAt != null && !nextReviewAt.isAfter(now.toUtc()),
            reviewTimeLabel: nextReviewAt == null
                ? null
                : reviewTimeLabel(nextReviewAt, now: now),
          ),
        );
      }
    }

    return LearningCenterSnapshot(allWords: List.unmodifiable(words));
  }

  LearningCenterWordStatus _statusFor(WordProgress progress) {
    if (isLearnedProgress(progress)) return LearningCenterWordStatus.learned;
    if (isReviewedProgress(progress)) return LearningCenterWordStatus.learning;
    return LearningCenterWordStatus.newWord;
  }
}
