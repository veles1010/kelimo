import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/progress_statistics.dart';

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
}
