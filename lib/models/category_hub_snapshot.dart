import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/data/category_catalog.dart';

class CategoryHubSnapshot {
  const CategoryHubSnapshot({
    required this.progressByCategoryId,
    required this.recentCategories,
  });

  final Map<String, CategoryProgressStatistics> progressByCategoryId;
  final List<LearningCategory> recentCategories;

  LearningCategory? get lastCategory =>
      recentCategories.isEmpty ? null : recentCategories.first;

  CategoryProgressStatistics? progressFor(String categoryId) =>
      progressByCategoryId[categoryId];

  CategoryHubSelection? nextLearningCategory(Set<String> unlockedIds) {
    CategoryHubSelection? recentPick(
      bool Function(CategoryProgressStatistics) test,
      CategoryHubSelectionKind kind,
    ) {
      for (final recent in recentCategories) {
        final progress = progressFor(recent.id);
        if (unlockedIds.contains(recent.id) &&
            progress != null &&
            test(progress)) {
          return CategoryHubSelection(recent, progress, kind);
        }
      }
      return null;
    }

    CategoryHubSelection? catalogPick(
      bool Function(CategoryProgressStatistics) test,
      CategoryHubSelectionKind kind,
    ) {
      for (final entry in progressByCategoryId.entries) {
        if (unlockedIds.contains(entry.key) && test(entry.value)) {
          final category = CategoryCatalog.findById(entry.key);
          if (category != null) {
            return CategoryHubSelection(category, entry.value, kind);
          }
        }
      }
      return null;
    }

    return recentPick(
          (p) =>
              p.learnedWordCount > 0 && p.learnedWordCount < p.totalWordCount,
          CategoryHubSelectionKind.partial,
        ) ??
        catalogPick(
          (p) =>
              p.learnedWordCount > 0 && p.learnedWordCount < p.totalWordCount,
          CategoryHubSelectionKind.partial,
        ) ??
        catalogPick(
          (p) => p.learnedWordCount == 0,
          CategoryHubSelectionKind.unstarted,
        ) ??
        recentPick((p) => true, CategoryHubSelectionKind.completed) ??
        catalogPick((p) => true, CategoryHubSelectionKind.completed);
  }
}

enum CategoryHubSelectionKind { partial, unstarted, completed }

class CategoryHubSelection {
  const CategoryHubSelection(this.category, this.progress, this.kind);
  final LearningCategory category;
  final CategoryProgressStatistics progress;
  final CategoryHubSelectionKind kind;
}
