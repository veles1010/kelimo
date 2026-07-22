import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/quiz_attempt.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:sqflite/sqflite.dart';

int quizXpForScore(int scorePercent) => scorePercent == 100 ? 25 : 0;

class QuizCompletion {
  const QuizCompletion({required this.attempt, required this.xpState});

  final QuizAttempt attempt;
  final XpState xpState;
}

abstract interface class QuizStore {
  Future<QuizCompletion> saveCompletedQuiz({
    required String categoryId,
    required int correctCount,
    required int totalQuestions,
    required int scorePercent,
    DateTime? completedAt,
  });
  Future<List<QuizAttempt>> getAllAttempts();
  Future<List<QuizAttempt>> getAttemptsByCategory(String categoryId);
  Future<int> getHighestScore(String categoryId);
  Future<int> getTotalQuizCount();
  Future<QuizStatistics> getStatistics();
  void clearCachedData();
}

class QuizRepository implements QuizStore {
  QuizRepository(this._databaseService, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DatabaseService _databaseService;
  final DateTime Function() _now;

  @override
  Future<QuizCompletion> saveCompletedQuiz({
    required String categoryId,
    required int correctCount,
    required int totalQuestions,
    required int scorePercent,
    DateTime? completedAt,
  }) async {
    final possibleXp = quizXpForScore(scorePercent);
    final completionDate = completedAt ?? _now();

    try {
      final database = await _databaseService.database;
      return database.transaction((transaction) async {
        var xpAwarded = 0;
        if (possibleXp > 0) {
          final claimId = await transaction.insert('quiz_xp_claims', {
            'category_id': categoryId,
            'date_key': _localDateKey(completionDate),
            'awarded_xp': possibleXp,
            'awarded_at': completionDate.toUtc().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (claimId != 0) xpAwarded = possibleXp;
        }
        final attempt = QuizAttempt(
          categoryId: categoryId,
          correctCount: correctCount,
          totalQuestions: totalQuestions,
          scorePercent: scorePercent,
          completedAt: completionDate,
          xpAwarded: xpAwarded,
        );
        final xpRows = await transaction.query(
          'xp_state',
          where: 'id = 1',
          limit: 1,
        );
        final currentXp = xpRows.isEmpty
            ? XpState.initial()
            : XpState.fromMap(xpRows.first);
        final updatedXp = XpState(
          totalXp: currentXp.totalXp + xpAwarded,
          updatedAt: completionDate,
        );

        if (xpAwarded > 0 || xpRows.isEmpty) {
          await transaction.insert(
            'xp_state',
            updatedXp.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        final id = await transaction.insert('quiz_attempts', attempt.toMap());

        return QuizCompletion(
          attempt: attempt.withId(id),
          xpState: xpAwarded > 0 ? updatedXp : currentXp,
        );
      });
    } catch (error, stackTrace) {
      debugPrint('Quiz sonucu kaydedilemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<List<QuizAttempt>> getAllAttempts() => _queryAttempts();

  @override
  Future<List<QuizAttempt>> getAttemptsByCategory(String categoryId) {
    return _queryAttempts(where: 'category_id = ?', whereArgs: [categoryId]);
  }

  Future<List<QuizAttempt>> _queryAttempts({
    String? where,
    List<Object?>? whereArgs,
  }) async {
    try {
      final database = await _databaseService.database;
      final rows = await database.query(
        'quiz_attempts',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'completed_at DESC',
      );
      return rows.map(QuizAttempt.fromMap).toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Quiz denemeleri yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<int> getHighestScore(String categoryId) async {
    try {
      final database = await _databaseService.database;
      final rows = await database.rawQuery(
        'SELECT MAX(score_percent) AS highest_score '
        'FROM quiz_attempts WHERE category_id = ?',
        [categoryId],
      );
      return (rows.first['highest_score'] as int?) ?? 0;
    } catch (error, stackTrace) {
      debugPrint('En yüksek quiz skoru yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<int> getTotalQuizCount() async {
    try {
      final database = await _databaseService.database;
      final rows = await database.rawQuery(
        'SELECT COUNT(*) AS quiz_count FROM quiz_attempts',
      );
      return (rows.first['quiz_count'] as int?) ?? 0;
    } catch (error, stackTrace) {
      debugPrint('Toplam quiz sayısı yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<QuizStatistics> getStatistics() async {
    try {
      final database = await _databaseService.database;
      final totals = await database.rawQuery('''
        SELECT
          COUNT(*) AS quiz_count,
          COALESCE(SUM(correct_count), 0) AS correct_count,
          COALESCE(SUM(total_questions), 0) AS question_count
        FROM quiz_attempts
      ''');
      final highestScores = await database.rawQuery('''
        SELECT category_id, MAX(score_percent) AS highest_score
        FROM quiz_attempts
        GROUP BY category_id
      ''');
      final totalQuizCount = totals.first['quiz_count']! as int;
      final totalCorrectCount = totals.first['correct_count']! as int;
      final totalQuestionCount = totals.first['question_count']! as int;
      final generalSuccessPercentage = totalQuestionCount == 0
          ? 0
          : ((totalCorrectCount / totalQuestionCount) * 100).round();

      return QuizStatistics(
        totalQuizCount: totalQuizCount,
        totalCorrectCount: totalCorrectCount,
        totalQuestionCount: totalQuestionCount,
        generalSuccessPercentage: generalSuccessPercentage,
        highestScoreByCategory: {
          for (final row in highestScores)
            row['category_id']! as String: row['highest_score']! as int,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('Quiz istatistikleri yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  void clearCachedData() {
    // QuizRepository reads attempts directly from SQLite and has no cache.
  }
}

String _localDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
