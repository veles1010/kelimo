import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/category_hub_snapshot.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/statistics_service.dart';

class CategoryHubService {
  const CategoryHubService({
    required this.wordProgressStore,
    required this.quizStore,
    required this.statisticsService,
  });

  final WordProgressStore wordProgressStore;
  final QuizStore quizStore;
  final StatisticsService statisticsService;

  Future<CategoryHubSnapshot> load() async {
    final categories = CategoryCatalog.categories
        .where((category) => category.isAvailable)
        .toList(growable: false);
    final categoryByWordId = <String, LearningCategory>{
      for (final category in categories)
        for (final word in category.words) word.id: category,
    };
    final latestActivityByCategoryId = <String, DateTime>{};

    for (final progress in wordProgressStore.getAllProgress()) {
      if (!isReviewedProgress(progress)) continue;
      final category = categoryByWordId[progress.wordId];
      if (category == null) continue;
      _keepLatest(
        latestActivityByCategoryId,
        category.id,
        progress.lastReviewedAt ?? progress.updatedAt,
      );
    }

    for (final attempt in await quizStore.getAllAttempts()) {
      if (CategoryCatalog.findById(attempt.categoryId)?.isAvailable != true) {
        continue;
      }
      _keepLatest(
        latestActivityByCategoryId,
        attempt.categoryId,
        attempt.completedAt,
      );
    }

    final catalogIndex = {
      for (var index = 0; index < categories.length; index++)
        categories[index].id: index,
    };
    final recentCategories =
        categories
            .where(
              (category) => latestActivityByCategoryId.containsKey(category.id),
            )
            .toList()
          ..sort((a, b) {
            final dateComparison = latestActivityByCategoryId[b.id]!.compareTo(
              latestActivityByCategoryId[a.id]!,
            );
            if (dateComparison != 0) return dateComparison;
            return catalogIndex[a.id]!.compareTo(catalogIndex[b.id]!);
          });

    final progressEntries = await Future.wait(
      categories.map((category) async {
        final progress = await statisticsService.loadCategory(category.id);
        return MapEntry(category.id, progress);
      }),
    );

    return CategoryHubSnapshot(
      progressByCategoryId: Map.unmodifiable(Map.fromEntries(progressEntries)),
      recentCategories: List.unmodifiable(recentCategories),
    );
  }
}

void _keepLatest(
  Map<String, DateTime> latestByCategoryId,
  String categoryId,
  DateTime candidate,
) {
  final current = latestByCategoryId[categoryId];
  if (current == null || candidate.isAfter(current)) {
    latestByCategoryId[categoryId] = candidate;
  }
}
