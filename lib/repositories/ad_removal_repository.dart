import 'package:kelimo/data/local/database_service.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class AdRemovalStore {
  Future<bool> loadAdsRemoved();
  Future<void> saveAdsRemoved(bool value);
}

/// Locally remembers a store-confirmed non-consumable entitlement.
class AdRemovalRepository implements AdRemovalStore {
  AdRemovalRepository(this._databaseService);

  static const adsRemovedKey = 'ads_removed_entitlement';
  final DatabaseService _databaseService;

  @override
  Future<bool> loadAdsRemoved() async {
    final database = await _databaseService.database;
    final rows = await database.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [adsRemovedKey],
      limit: 1,
    );
    return rows.isNotEmpty && rows.first['value'] == 'true';
  }

  @override
  Future<void> saveAdsRemoved(bool value) async {
    final database = await _databaseService.database;
    await database.insert('app_settings', {
      'key': adsRemovedKey,
      'value': '$value',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
