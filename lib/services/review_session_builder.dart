import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/review_session.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';

class ReviewSessionBuilder {
  ReviewSessionBuilder({
    required this.wordProgressStore,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final WordProgressStore wordProgressStore;
  final DateTime Function() _now;

  Future<List<ReviewSessionItem>> build() async {
    await wordProgressStore.initialize();
    final now = _now().toUtc();
    final progressByWordId = <String, WordProgress>{
      for (final progress in wordProgressStore.getAllProgress())
        progress.wordId: progress,
    };
    final candidates = <({ReviewSessionItem item, int category, int word})>[];
    final seen = <String>{};

    for (
      var categoryIndex = 0;
      categoryIndex < CategoryCatalog.categories.length;
      categoryIndex++
    ) {
      final category = CategoryCatalog.categories[categoryIndex];
      for (var wordIndex = 0; wordIndex < category.words.length; wordIndex++) {
        final word = category.words[wordIndex];
        final progress = progressByWordId[word.id];
        final nextReviewAt = progress?.nextReviewAt;
        if (nextReviewAt == null || nextReviewAt.isAfter(now)) continue;
        if (!seen.add('${category.id}:${word.id}')) continue;

        candidates.add((
          item: ReviewSessionItem(
            category: category,
            word: word,
            nextReviewAt: nextReviewAt,
          ),
          category: categoryIndex,
          word: wordIndex,
        ));
      }
    }

    candidates.sort((left, right) {
      final dateComparison = left.item.nextReviewAt.compareTo(
        right.item.nextReviewAt,
      );
      if (dateComparison != 0) return dateComparison;
      final categoryComparison = left.category.compareTo(right.category);
      if (categoryComparison != 0) return categoryComparison;
      return left.word.compareTo(right.word);
    });

    return List.unmodifiable(candidates.map((candidate) => candidate.item));
  }
}
