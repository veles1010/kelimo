import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/daily_progress.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class DailyProgressStore {
  Future<DailyProgressSnapshot> loadToday({
    int initialStreak = 7,
    DateTime? now,
  });
  Future<DailyProgressSnapshot> incrementReview({
    required int dailyGoal,
    int initialStreak = 7,
    DateTime? now,
  });
  Future<void> saveStreak(StreakState streak);
}

class DailyProgressRepository implements DailyProgressStore {
  DailyProgressRepository(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<DailyProgressSnapshot> loadToday({
    int initialStreak = 7,
    DateTime? now,
  }) async {
    try {
      final database = await _databaseService.database;
      final dateKey = localDateKey(now ?? DateTime.now());
      final dailyRows = await database.query(
        'daily_progress',
        where: 'date_key = ?',
        whereArgs: [dateKey],
        limit: 1,
      );
      final streakRows = await database.query(
        'streak_state',
        where: 'id = 1',
        limit: 1,
      );

      return DailyProgressSnapshot(
        progress: dailyRows.isEmpty
            ? DailyProgress.initial(dateKey)
            : DailyProgress.fromMap(dailyRows.first),
        streak: streakRows.isEmpty
            ? StreakState(currentStreak: initialStreak)
            : StreakState.fromMap(streakRows.first),
      );
    } catch (error, stackTrace) {
      debugPrint('Günlük ilerleme yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<DailyProgressSnapshot> incrementReview({
    required int dailyGoal,
    int initialStreak = 7,
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
        final streakRows = await transaction.query(
          'streak_state',
          where: 'id = 1',
          limit: 1,
        );

        final currentProgress = dailyRows.isEmpty
            ? DailyProgress.initial(dateKey)
            : DailyProgress.fromMap(dailyRows.first);
        final currentStreak = streakRows.isEmpty
            ? StreakState(currentStreak: initialStreak)
            : StreakState.fromMap(streakRows.first);
        final reviewCount = currentProgress.reviewCount + 1;
        final justCompleted =
            !currentProgress.isGoalCompleted && reviewCount >= dailyGoal;
        final progress = DailyProgress(
          dateKey: dateKey,
          reviewCount: reviewCount,
          isGoalCompleted: currentProgress.isGoalCompleted || justCompleted,
          streakAwarded: currentProgress.streakAwarded || justCompleted,
        );
        final streak = justCompleted
            ? StreakState(
                currentStreak: currentStreak.currentStreak + 1,
                lastCompletedDate: DateTime(
                  reviewDate.year,
                  reviewDate.month,
                  reviewDate.day,
                ),
              )
            : currentStreak;

        await transaction.insert(
          'daily_progress',
          progress.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await transaction.insert('streak_state', {
          'id': 1,
          ...streak.toMap(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);

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
}
