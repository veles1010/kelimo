import 'package:flutter/foundation.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';

const _learnedMasteryScore = 3;

int masteryScore(String mastery) {
  return switch (mastery) {
    'again' => 1,
    'hard' => 2,
    'easy' => 3,
    _ => 0,
  };
}

bool isReviewedProgress(WordProgress progress) {
  return progress.repetitionCount > 0 || progress.lastReviewedAt != null;
}

bool isLearnedProgress(WordProgress progress) {
  return isReviewedProgress(progress) &&
      masteryScore(progress.mastery) >= _learnedMasteryScore;
}

WordLearningDistribution calculateWordDistribution(
  List<Word> words,
  Iterable<WordProgress> progressRecords,
) {
  final progressById = {
    for (final progress in progressRecords) progress.wordId: progress,
  };
  var learningCount = 0;
  var learnedCount = 0;

  for (final word in words) {
    final progress = progressById[word.id];
    if (progress == null || !isReviewedProgress(progress)) continue;
    if (isLearnedProgress(progress)) {
      learnedCount++;
    } else {
      learningCount++;
    }
  }

  return WordLearningDistribution(
    totalCount: words.length,
    newCount: words.length - learningCount - learnedCount,
    learningCount: learningCount,
    learnedCount: learnedCount,
  );
}

String categoryNameForId(String categoryId) {
  return CategoryCatalog.findById(categoryId)?.title ?? categoryId;
}

String formatTurkishDate(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  final local = date.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

class StatisticsService extends ChangeNotifier {
  StatisticsService({
    required this.wordProgressStore,
    required this.quizStore,
    required this.streakService,
    required this.xpService,
  });

  final WordProgressStore wordProgressStore;
  final QuizStore quizStore;
  final StreakService streakService;
  final XpService xpService;

  bool _isLoading = false;
  Object? _error;
  GeneralProgressStatistics? _statistics;

  bool get isLoading => _isLoading;
  Object? get error => _error;
  GeneralProgressStatistics? get statistics => _statistics;

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final quizStatistics = await quizStore.getStatistics();
      final attempts = await quizStore.getAllAttempts();
      final wordProgress = wordProgressStore.getAllProgress();
      final words = CategoryCatalog.categories
          .where((category) => category.isAvailable)
          .expand((category) => category.words)
          .toList(growable: false);
      final knownWordIds = words.map((word) => word.id).toSet();
      final relevantProgress = wordProgress
          .where((progress) => knownWordIds.contains(progress.wordId))
          .toList(growable: false);
      final distribution = calculateWordDistribution(words, relevantProgress);
      final sortedAttempts = [...attempts]
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
      final recentAttempts = sortedAttempts.take(5).toList(growable: false);
      String? bestCategoryName;
      var highestQuizScore = 0;
      for (final entry in quizStatistics.highestScoreByCategory.entries) {
        if (bestCategoryName == null || entry.value > highestQuizScore) {
          highestQuizScore = entry.value;
          bestCategoryName = categoryNameForId(entry.key);
        }
      }

      _statistics = GeneralProgressStatistics(
        currentLevel: xpService.currentLevel,
        totalXp: xpService.totalXp,
        currentStreak: streakService.currentStreak,
        todayReviewCount: streakService.todayCount,
        startedWordCount: relevantProgress.where(isReviewedProgress).length,
        favoriteWordCount: relevantProgress
            .where((progress) => progress.isFavorite)
            .length,
        distribution: distribution,
        quizStatistics: quizStatistics,
        bestCategoryName: bestCategoryName,
        highestQuizScore: highestQuizScore,
        recentAttempts: recentAttempts,
      );
    } catch (error, stackTrace) {
      _error = error;
      debugPrint('İstatistikler yüklenemedi: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CategoryProgressStatistics> loadCategory(String categoryId) async {
    final words = _wordsForCategory(categoryId);
    final wordIds = words.map((word) => word.id).toSet();
    final progressById = {
      for (final progress in wordProgressStore.getAllProgress())
        if (wordIds.contains(progress.wordId)) progress.wordId: progress,
    };
    final attempts = await quizStore.getAttemptsByCategory(categoryId);
    final reviewedProgress = progressById.values
        .where(isReviewedProgress)
        .toList(growable: false);
    final totalMasteryPoints = words.fold<int>(
      0,
      (total, word) =>
          total + masteryScore(progressById[word.id]?.mastery ?? 'new'),
    );
    final averageMasteryPercentage = words.isEmpty
        ? 0
        : ((totalMasteryPoints / (words.length * _learnedMasteryScore)) * 100)
              .round();
    final totalQuizQuestions = attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.totalQuestions,
    );
    final totalCorrectAnswers = attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.correctCount,
    );

    return CategoryProgressStatistics(
      categoryId: categoryId,
      categoryName: categoryNameForId(categoryId),
      totalWordCount: words.length,
      reviewedWordCount: reviewedProgress.length,
      learnedWordCount: reviewedProgress.where(isLearnedProgress).length,
      favoriteWordCount: progressById.values
          .where((progress) => progress.isFavorite)
          .length,
      averageMasteryPercentage: averageMasteryPercentage,
      completedQuizCount: attempts.length,
      highestQuizScore: attempts.fold<int>(
        0,
        (highest, attempt) =>
            attempt.scorePercent > highest ? attempt.scorePercent : highest,
      ),
      averageQuizPercentage: totalQuizQuestions == 0
          ? 0
          : ((totalCorrectAnswers / totalQuizQuestions) * 100).round(),
    );
  }

  List<Word> _wordsForCategory(String categoryId) {
    return CategoryCatalog.findById(categoryId)?.words ?? const [];
  }
}
