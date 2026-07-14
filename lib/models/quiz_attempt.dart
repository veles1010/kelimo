class QuizAttempt {
  const QuizAttempt({
    this.id,
    required this.categoryId,
    required this.correctCount,
    required this.totalQuestions,
    required this.scorePercent,
    required this.completedAt,
    required this.xpAwarded,
  }) : assert(correctCount >= 0),
       assert(totalQuestions > 0),
       assert(correctCount <= totalQuestions),
       assert(scorePercent >= 0 && scorePercent <= 100),
       assert(xpAwarded >= 0);

  factory QuizAttempt.fromMap(Map<String, Object?> map) {
    return QuizAttempt(
      id: map['id']! as int,
      categoryId: map['category_id']! as String,
      correctCount: map['correct_count']! as int,
      totalQuestions: map['total_questions']! as int,
      scorePercent: map['score_percent']! as int,
      completedAt: DateTime.parse(map['completed_at']! as String),
      xpAwarded: map['xp_awarded']! as int,
    );
  }

  final int? id;
  final String categoryId;
  final int correctCount;
  final int totalQuestions;
  final int scorePercent;
  final DateTime completedAt;
  final int xpAwarded;

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'category_id': categoryId,
      'correct_count': correctCount,
      'total_questions': totalQuestions,
      'score_percent': scorePercent,
      'completed_at': completedAt.toIso8601String(),
      'xp_awarded': xpAwarded,
    };
  }

  QuizAttempt withId(int value) {
    return QuizAttempt(
      id: value,
      categoryId: categoryId,
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      scorePercent: scorePercent,
      completedAt: completedAt,
      xpAwarded: xpAwarded,
    );
  }
}

class QuizStatistics {
  const QuizStatistics({
    required this.totalQuizCount,
    required this.totalCorrectCount,
    required this.totalQuestionCount,
    required this.generalSuccessPercentage,
    required this.highestScoreByCategory,
  });

  final int totalQuizCount;
  final int totalCorrectCount;
  final int totalQuestionCount;
  final int generalSuccessPercentage;
  final Map<String, int> highestScoreByCategory;
}
