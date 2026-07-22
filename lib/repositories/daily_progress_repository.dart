import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/daily_progress.dart';
import 'package:kelimo/services/streak_calculator.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class DailyProgressStore {
  Future<DailyProgressSnapshot> loadToday({DateTime? now});
  Future<DailyProgressSnapshot> incrementReview({
    required int dailyGoal,
    DateTime? now,
  });
  Future<void> saveStreak(StreakState streak);
}

class DailyProgressRepository implements DailyProgressStore {
  DailyProgressRepository(
    this._databaseService, {
    this.streakCalculator = const StreakCalculator(),
  });

  final DatabaseService _databaseService;
  final StreakCalculator streakCalculator;

  @override
  Future<DailyProgressSnapshot> loadToday({DateTime? now}) async {
    try {
      final database = await _databaseService.database;
      final currentTime = now ?? DateTime.now();
      final dateKey = localDateKey(currentTime);
      final dailyRows = await database.query(
        'daily_progress',
        where: 'date_key = ?',
        whereArgs: [dateKey],
        limit: 1,
      );
      final activityTimes = await _loadActivityTimes(database);
      final streak = _streakFromActivities(activityTimes, now: currentTime);
      await _saveStreak(database, streak);

      return DailyProgressSnapshot(
        progress: dailyRows.isEmpty
            ? DailyProgress.initial(dateKey)
            : DailyProgress.fromMap(dailyRows.first),
        streak: streak,
      );
    } catch (error, stackTrace) {
      debugPrint('Günlük ilerleme yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<DailyProgressSnapshot> incrementReview({
    required int dailyGoal,
    DateTime? now,
  }) async {
    final reviewDate = (now ?? DateTime.now()).toLocal();
    try {
      final database = await _databaseService.database;
      return database.transaction((transaction) async {
        final dateKey = localDateKey(reviewDate);
        final dailyRows = await transaction.query(
          'daily_progress',
          where: 'date_key = ?',
          whereArgs: [dateKey],
          limit: 1,
        );
        final currentProgress = dailyRows.isEmpty
            ? DailyProgress.initial(dateKey)
            : DailyProgress.fromMap(dailyRows.first);
        final reviewCount = currentProgress.reviewCount + 1;
        final justCompleted =
            !currentProgress.isGoalCompleted && reviewCount >= dailyGoal;
        final progress = DailyProgress(
          dateKey: dateKey,
          reviewCount: reviewCount,
          isGoalCompleted: currentProgress.isGoalCompleted || justCompleted,
          streakAwarded: currentProgress.streakAwarded || justCompleted,
        );
        await transaction.insert(
          'daily_progress',
          progress.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        final activityTimes = await _loadActivityTimes(transaction);
        final streak = _streakFromActivities(activityTimes, now: reviewDate);
        await _saveStreak(transaction, streak);

        return DailyProgressSnapshot(
          progress: progress,
          streak: streak,
          justCompleted: justCompleted,
        );
      });
    } catch (error, stackTrace) {
      debugPrint('Günlük değerlendirme kaydedilemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> saveStreak(StreakState streak) async {
    try {
      final database = await _databaseService.database;
      await database.insert('streak_state', {
        'id': 1,
        ...streak.toMap(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (error, stackTrace) {
      debugPrint('Seri bilgisi kaydedilemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  Future<List<DateTime>> _loadActivityTimes(DatabaseExecutor database) async {
    final dailyRows = await database.query(
      'daily_progress',
      columns: ['date_key'],
      where: 'review_count > 0',
    );
    final quizRows = await database.query(
      'quiz_attempts',
      columns: ['completed_at'],
    );

    return [
      for (final row in dailyRows)
        ?parseLocalDateKey(row['date_key'] as String?),
      for (final row in quizRows)
        ?DateTime.tryParse(row['completed_at'] as String? ?? ''),
    ];
  }

  StreakState _streakFromActivities(
    List<DateTime> activityTimes, {
    required DateTime now,
  }) {
    return StreakState(
      currentStreak: streakCalculator.calculate(activityTimes, now: now),
      lastCompletedDate: streakCalculator.latestValidActivity(
        activityTimes,
        now: now,
      ),
    );
  }

  Future<void> _saveStreak(
    DatabaseExecutor database,
    StreakState streak,
  ) async {
    await database.insert('streak_state', {
      'id': 1,
      ...streak.toMap(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
