import 'package:kelimo/models/quiz_attempt.dart';

class WordLearningDistribution {
  const WordLearningDistribution({
    required this.totalCount,
    required this.newCount,
    required this.learningCount,
    required this.learnedCount,
  });

  final int totalCount;
  final int newCount;
  final int learningCount;
  final int learnedCount;

  double ratioFor(int count) => totalCount == 0 ? 0 : count / totalCount;
}

class GeneralProgressStatistics {
  const GeneralProgressStatistics({
    required this.currentLevel,
    required this.totalXp,
    required this.currentStreak,
    required this.todayReviewCount,
    required this.startedWordCount,
    required this.favoriteWordCount,
    required this.distribution,
    required this.quizStatistics,
    required this.bestCategoryName,
    required this.highestQuizScore,
    required this.recentAttempts,
  });

  final int currentLevel;
  final int totalXp;
  final int currentStreak;
  final int todayReviewCount;
  final int startedWordCount;
  final int favoriteWordCount;
  final WordLearningDistribution distribution;
  final QuizStatistics quizStatistics;
  final String? bestCategoryName;
  final int highestQuizScore;
  final List<QuizAttempt> recentAttempts;
}

class CategoryProgressStatistics {
  const CategoryProgressStatistics({
    required this.categoryId,
    required this.categoryName,
    required this.totalWordCount,
    required this.reviewedWordCount,
    required this.learnedWordCount,
    required this.favoriteWordCount,
    required this.averageMasteryPercentage,
    required this.completedQuizCount,
    required this.highestQuizScore,
    required this.averageQuizPercentage,
  });

  final String categoryId;
  final String categoryName;
  final int totalWordCount;
  final int reviewedWordCount;
  final int learnedWordCount;
  final int favoriteWordCount;
  final int averageMasteryPercentage;
  final int completedQuizCount;
  final int highestQuizScore;
  final int averageQuizPercentage;
}
