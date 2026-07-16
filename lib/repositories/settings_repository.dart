import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class SettingsStore {
  Future<AppSettings> load();
  Future<void> setDailyGoal(int dailyGoal);
  Future<void> setSpeechRate(SpeechRatePreference speechRate);
  Future<void> resetToDefaults();
  Future<int> resolveDailyGoalForDate({
    required String dateKey,
    required int selectedDailyGoal,
  });
}

class SettingsRepository implements SettingsStore {
  SettingsRepository(this._databaseService);

  static const dailyGoalKey = 'daily_goal';
  static const speechRateKey = 'speech_rate';
  static const activeDailyGoalKey = 'active_daily_goal';
  static const activeDailyGoalDateKey = 'active_daily_goal_date';

  final DatabaseService _databaseService;

  @override
  Future<AppSettings> load() async {
    try {
      final values = await _loadValues();
      return AppSettings(
        dailyGoal: AppSettings.safeDailyGoal(values[dailyGoalKey]),
        speechRate: SpeechRatePreference.fromStorage(values[speechRateKey]),
      );
    } catch (error, stackTrace) {
      debugPrint('Ayarlar yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> setDailyGoal(int dailyGoal) async {
    if (!AppSettings.allowedDailyGoals.contains(dailyGoal)) {
      throw ArgumentError.value(dailyGoal, 'dailyGoal', 'Desteklenmeyen hedef');
    }
    await _writeValue(dailyGoalKey, '$dailyGoal');
  }

  @override
  Future<void> setSpeechRate(SpeechRatePreference speechRate) {
    return _writeValue(speechRateKey, speechRate.storageValue);
  }

  @override
  Future<void> resetToDefaults() async {
    final database = await _databaseService.database;
    await database.transaction((transaction) async {
      await transaction.delete(
        'app_settings',
        where: 'key IN (?, ?)',
        whereArgs: [dailyGoalKey, speechRateKey],
      );
      await _writeDefaults(transaction);
    });
  }

  @override
  Future<int> resolveDailyGoalForDate({
    required String dateKey,
    required int selectedDailyGoal,
  }) async {
    final safeSelectedGoal =
        AppSettings.allowedDailyGoals.contains(selectedDailyGoal)
        ? selectedDailyGoal
        : AppSettings.defaults.dailyGoal;
    final database = await _databaseService.database;
    return database.transaction((transaction) async {
      final rows = await transaction.query('app_settings');
      final values = {
        for (final row in rows) row['key']! as String: row['value']! as String,
      };
      if (values[activeDailyGoalDateKey] == dateKey) {
        return AppSettings.safeDailyGoal(values[activeDailyGoalKey]);
      }

      final now = DateTime.now().toIso8601String();
      await _upsert(
        transaction,
        activeDailyGoalDateKey,
        dateKey,
        updatedAt: now,
      );
      await _upsert(
        transaction,
        activeDailyGoalKey,
        '$safeSelectedGoal',
        updatedAt: now,
      );
      return safeSelectedGoal;
    });
  }

  Future<Map<String, String>> _loadValues() async {
    final database = await _databaseService.database;
    final rows = await database.query('app_settings');
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }

  Future<void> _writeValue(String key, String value) async {
    try {
      final database = await _databaseService.database;
      await _upsert(database, key, value);
    } catch (error, stackTrace) {
      debugPrint('Ayar kaydedilemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  static Future<void> writeDefaults(DatabaseExecutor database) {
    return _writeDefaults(database);
  }

  static Future<void> _writeDefaults(DatabaseExecutor database) async {
    final now = DateTime.now().toIso8601String();
    await _upsert(
      database,
      dailyGoalKey,
      '${AppSettings.defaults.dailyGoal}',
      updatedAt: now,
    );
    await _upsert(
      database,
      speechRateKey,
      AppSettings.defaults.speechRate.storageValue,
      updatedAt: now,
    );
  }

  static Future<void> _upsert(
    DatabaseExecutor database,
    String key,
    String value, {
    String? updatedAt,
  }) async {
    await database.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
