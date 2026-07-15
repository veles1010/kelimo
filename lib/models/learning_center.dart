import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/models/word_progress.dart';

enum LearningCenterFilter { repeatPending, favorites, learned, all }

enum LearningCenterWordStatus {
  newWord('Yeni'),
  learning('Öğreniliyor'),
  learned('Öğrenildi');

  const LearningCenterWordStatus(this.label);

  final String label;
}

class LearningCenterWord {
  const LearningCenterWord({
    required this.category,
    required this.word,
    required this.progress,
    required this.status,
  });

  final LearningCategory category;
  final Word word;
  final WordProgress progress;
  final LearningCenterWordStatus status;
}

class LearningCenterSnapshot {
  const LearningCenterSnapshot({required this.allWords});

  final List<LearningCenterWord> allWords;

  List<LearningCenterWord> wordsFor(LearningCenterFilter filter) {
    return switch (filter) {
      LearningCenterFilter.repeatPending =>
        allWords
            .where(
              (entry) =>
                  entry.progress.mastery == 'again' ||
                  entry.progress.mastery == 'hard',
            )
            .toList(growable: false),
      LearningCenterFilter.favorites =>
        allWords
            .where((entry) => entry.progress.isFavorite)
            .toList(growable: false),
      LearningCenterFilter.learned =>
        allWords
            .where((entry) => entry.status == LearningCenterWordStatus.learned)
            .toList(growable: false),
      LearningCenterFilter.all => allWords,
    };
  }

  int get totalCount => allWords.length;
  int get repeatPendingCount =>
      wordsFor(LearningCenterFilter.repeatPending).length;
  int get favoriteCount => wordsFor(LearningCenterFilter.favorites).length;
  int get learnedCount => wordsFor(LearningCenterFilter.learned).length;
}
