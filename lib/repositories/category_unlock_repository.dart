import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/category_unlock.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class CategoryUnlockStore {
  Future<List<CategoryUnlock>> loadUnlocks();
  Future<bool> unlock(CategoryUnlock unlock);
  Future<void> replaceWithDefaults(Iterable<CategoryUnlock> unlocks);
}

class CategoryUnlockRepository implements CategoryUnlockStore {
  CategoryUnlockRepository(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<List<CategoryUnlock>> loadUnlocks() async {
    try {
      final database = await _databaseService.database;
      final rows = await database.query('category_unlocks');
      return rows.map(CategoryUnlock.fromMap).toList(growable: false);
    } catch (error, stackTrace) {
      debugPrint('Kategori kilitleri yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<bool> unlock(CategoryUnlock unlock) async {
    try {
      final database = await _databaseService.database;
      final inserted = await database.insert(
        'category_unlocks',
        unlock.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return inserted != 0;
    } catch (error, stackTrace) {
      debugPrint('Kategori açılamadı: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> replaceWithDefaults(Iterable<CategoryUnlock> unlocks) async {
    final database = await _databaseService.database;
    await database.transaction((transaction) async {
      await transaction.delete('category_unlocks');
      for (final unlock in unlocks) {
        await transaction.insert('category_unlocks', unlock.toMap());
      }
    });
  }
}

class MemoryCategoryUnlockStore implements CategoryUnlockStore {
  MemoryCategoryUnlockStore([Iterable<CategoryUnlock> unlocks = const []]) {
    _values.addEntries(unlocks.map((item) => MapEntry(item.categoryId, item)));
  }

  final Map<String, CategoryUnlock> _values = {};

  @override
  Future<List<CategoryUnlock>> loadUnlocks() async => _values.values.toList();

  @override
  Future<bool> unlock(CategoryUnlock unlock) async {
    if (_values.containsKey(unlock.categoryId)) return false;
    _values[unlock.categoryId] = unlock;
    return true;
  }

  @override
  Future<void> replaceWithDefaults(Iterable<CategoryUnlock> unlocks) async {
    _values
      ..clear()
      ..addEntries(unlocks.map((item) => MapEntry(item.categoryId, item)));
  }
}
