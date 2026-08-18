import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:sqflite/sqflite.dart';

abstract interface class XpStore {
  Future<XpState> loadState();
  Future<XpState> addXp(int amount);
  int get currentTotalXp;
  void synchronizeState(XpState state);
  Future<void> resetXp();
}

abstract interface class XpAwardStore {
  Future<XpState> awardWordReview({
    required String wordId,
    required LearningRating rating,
    required int amount,
    DateTime? awardedAt,
  });
}

class XpRepository implements XpStore, XpAwardStore {
  XpRepository(this._databaseService);

  final DatabaseService _databaseService;
  XpState _state = XpState.initial();

  @override
  int get currentTotalXp => _state.totalXp;

  @override
  void synchronizeState(XpState state) {
    _state = state;
  }

  @override
  Future<XpState> loadState() async {
    try {
      final database = await _databaseService.database;
      final rows = await database.query('xp_state', where: 'id = 1', limit: 1);
      if (rows.isEmpty) {
        final initial = XpState.initial();
        await database.insert(
          'xp_state',
          initial.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        _state = initial;
      } else {
        _state = XpState.fromMap(rows.first);
      }
      return _state;
    } catch (error, stackTrace) {
      debugPrint('XP durumu yüklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<XpState> addXp(int amount) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'XP miktarı pozitif olmalı');
    }

    try {
      final database = await _databaseService.database;
      final updated = await database.transaction((transaction) async {
        final rows = await transaction.query(
          'xp_state',
          where: 'id = 1',
          limit: 1,
        );
        final current = rows.isEmpty
            ? XpState.initial()
            : XpState.fromMap(rows.first);
        final next = XpState(
          totalXp: current.totalXp + amount,
          updatedAt: DateTime.now(),
        );
        await transaction.insert(
          'xp_state',
          next.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return next;
      });
      _state = updated;
      return updated;
    } catch (error, stackTrace) {
      debugPrint('XP eklenemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<XpState> awardWordReview({
    required String wordId,
    required LearningRating rating,
    required int amount,
    DateTime? awardedAt,
  }) async {
    if (amount <= 0) return _state;
    final localDate = awardedAt ?? DateTime.now();
    final dateKey = _localDateKey(localDate);
    try {
      final database = await _databaseService.database;
      final updated = await database.transaction((transaction) async {
        final claimId = await transaction.insert('word_xp_claims', {
          'word_id': wordId,
          'date_key': dateKey,
          'awarded_xp': amount,
          'awarded_at': localDate.toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        final rows = await transaction.query(
          'xp_state',
          where: 'id = 1',
          limit: 1,
        );
        final current = rows.isEmpty
            ? XpState.initial()
            : XpState.fromMap(rows.first);
        if (claimId == 0) return current;
        final next = XpState(
          totalXp: current.totalXp + amount,
          updatedAt: localDate,
        );
        await transaction.insert(
          'xp_state',
          next.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return next;
      });
      _state = updated;
      return updated;
    } catch (error, stackTrace) {
      debugPrint('Kelime XP ödülü kaydedilemedi: $error\n$stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> resetXp() async {
    final reset = XpState.initial();
    try {
      final database = await _databaseService.database;
      await database.insert(
        'xp_state',
        reset.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _state = reset;
    } catch (error, stackTrace) {
      debugPrint('XP sıfırlanamadı: $error\n$stackTrace');
      rethrow;
    }
  }
}

String _localDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
