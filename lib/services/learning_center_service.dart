import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/statistics_service.dart';

class LearningCenterService {
  const LearningCenterService({required this.wordProgressStore});

  final WordProgressStore wordProgressStore;

  LearningCenterSnapshot load() {
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
        words.add(
          LearningCenterWord(
            category: category,
            word: word,
            progress: progress,
            status: _statusFor(progress),
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
