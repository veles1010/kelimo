import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/ad_display_state.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class AdFrequencyStore {
  Future<AdDisplayState> load();
  Future<AdDisplayState> recordQuizCompleted();
  Future<AdDisplayState> recordInterstitialShown(DateTime shownAt);
}

class AdFrequencyRepository implements AdFrequencyStore {
  AdFrequencyRepository(this._databaseService);

  static const completedQuizCountKey = 'interstitial_quiz_count';
  static const lastInterstitialShownAtKey = 'interstitial_last_shown_at';

  final DatabaseService _databaseService;

  @override
  Future<AdDisplayState> load() async {
    final database = await _databaseService.database;
    final rows = await database.query(
      'app_settings',
      where: 'key IN (?, ?)',
      whereArgs: [completedQuizCountKey, lastInterstitialShownAtKey],
    );
    return _fromValues({
      for (final row in rows) row['key']! as String: row['value']! as String,
    });
  }

  @override
  Future<AdDisplayState> recordQuizCompleted() async {
    final database = await _databaseService.database;
    return database.transaction((transaction) async {
      final state = await _loadFrom(transaction);
      final updated = AdDisplayState(
        completedQuizCountSinceLastAd: state.completedQuizCountSinceLastAd + 1,
        lastInterstitialShownAt: state.lastInterstitialShownAt,
      );
      await _write(transaction, updated);
      return updated;
    });
  }

  @override
  Future<AdDisplayState> recordInterstitialShown(DateTime shownAt) async {
    final database = await _databaseService.database;
    return database.transaction((transaction) async {
      final updated = AdDisplayState(
        completedQuizCountSinceLastAd: 0,
        lastInterstitialShownAt: shownAt.toUtc(),
      );
      await _write(transaction, updated);
      return updated;
    });
  }

  Future<AdDisplayState> _loadFrom(DatabaseExecutor database) async {
    final rows = await database.query(
      'app_settings',
      where: 'key IN (?, ?)',
      whereArgs: [completedQuizCountKey, lastInterstitialShownAtKey],
    );
    return _fromValues({
      for (final row in rows) row['key']! as String: row['value']! as String,
    });
  }

  static AdDisplayState _fromValues(Map<String, String> values) {
    final count = int.tryParse(values[completedQuizCountKey] ?? '') ?? 0;
    DateTime? lastShownAt;
    final storedDate = values[lastInterstitialShownAtKey];
    if (storedDate != null) {
      try {
        lastShownAt = DateTime.parse(storedDate).toUtc();
      } catch (error) {
        debugPrint('Geçersiz reklam gösterim tarihi yok sayıldı: $error');
      }
    }
    return AdDisplayState(
      completedQuizCountSinceLastAd: count < 0 ? 0 : count,
      lastInterstitialShownAt: lastShownAt,
    );
  }

  static Future<void> _write(
    DatabaseExecutor database,
    AdDisplayState state,
  ) async {
    final updatedAt = DateTime.now().toUtc().toIso8601String();
    await _upsert(
      database,
      completedQuizCountKey,
      '${state.completedQuizCountSinceLastAd}',
      updatedAt,
    );
    final lastShownAt = state.lastInterstitialShownAt;
    if (lastShownAt == null) {
      await database.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: [lastInterstitialShownAtKey],
      );
    } else {
      await _upsert(
        database,
        lastInterstitialShownAtKey,
        lastShownAt.toUtc().toIso8601String(),
        updatedAt,
      );
    }
  }

  static Future<void> _upsert(
    DatabaseExecutor database,
    String key,
    String value,
    String updatedAt,
  ) {
    return database.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': updatedAt,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
