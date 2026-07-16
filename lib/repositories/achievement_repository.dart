import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/achievement.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class AchievementStore {
  Future<List<AchievementUnlock>> loadUnlocked();
  bool isUnlocked(String id);
  Future<bool> unlock(String id, DateTime unlockedAt);
  Future<void> clearAll();
  void clearCachedData();
}

class AchievementRepository implements AchievementStore {
  AchievementRepository(this._databaseService);

  final DatabaseService _databaseService;
  final Map<String, AchievementUnlock> _unlocks = {};

  @override
  Future<List<AchievementUnlock>> loadUnlocked() async {
    try {
      final database = await _databaseService.database;
      final rows = await database.query('achievement_unlocks');
      _unlocks
        ..clear()
        ..addEntries(
          rows.map((row) {
            final unlock = AchievementUnlock.fromMap(row);
            return MapEntry(unlock.achievementId, unlock);
          }),
        );
      return List.unmodifiable(_unlocks.values);
    } catch (error, stackTrace) {
      debugPrint('Başarımlar yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  bool isUnlocked(String id) => _unlocks.containsKey(id);

  @override
  Future<bool> unlock(String id, DateTime unlockedAt) async {
    if (_unlocks.containsKey(id)) return false;
    final unlock = AchievementUnlock(
      achievementId: id,
      unlockedAt: unlockedAt.toUtc(),
    );
    try {
      final database = await _databaseService.database;
      final insertedId = await database.insert(
        'achievement_unlocks',
        unlock.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (insertedId == 0) {
        await loadUnlocked();
        return false;
      }
      _unlocks[id] = unlock;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Başarım kaydedilemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> clearAll() async {
    final database = await _databaseService.database;
    await database.delete('achievement_unlocks');
    _unlocks.clear();
  }

  @override
  void clearCachedData() => _unlocks.clear();
}
