import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/repositories/settings_repository.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class DataResetStore {
  Future<void> resetLearningData({required bool resetSettings});
}

class DataResetRepository implements DataResetStore {
  DataResetRepository(this._databaseService);

  static const learningDataTables = [
    'word_progress',
    'daily_progress',
    'quiz_attempts',
    'streak_state',
    'xp_state',
  ];

  final DatabaseService _databaseService;

  @override
  Future<void> resetLearningData({required bool resetSettings}) async {
    try {
      final database = await _databaseService.database;
      await database.transaction((transaction) async {
        for (final table in learningDataTables) {
          await transaction.delete(table);
        }

        await transaction.insert('streak_state', {
          'id': 1,
          'current_streak': 0,
          'last_completed_date': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await transaction.insert(
          'xp_state',
          XpState.initial().toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (resetSettings) {
          await transaction.delete('app_settings');
          await SettingsRepository.writeDefaults(transaction);
        }
      });
    } catch (error, stackTrace) {
      debugPrint('Kullanıcı verileri sıfırlanamadı: $error\n$stackTrace');
      rethrow;
    }
  }
}
