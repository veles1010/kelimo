import 'package:flutter/foundation.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/models/rewarded_bonus.dart';
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

abstract interface class RewardedXpStore {
  Future<RewardedBonusState> loadRewardedBonusState(DateTime localNow);
  Future<RewardedBonusClaim> claimRewardedBonus({
    required String claimId,
    required DateTime awardedAt,
  });
}

class XpRepository implements XpStore, XpAwardStore, RewardedXpStore {
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
  Future<RewardedBonusState> loadRewardedBonusState(DateTime localNow) async {
    final dateKey = _localDateKey(localNow);
    final database = await _databaseService.database;
    final count = Sqflite.firstIntValue(
      await database.rawQuery(
        'SELECT COUNT(*) FROM rewarded_xp_claims WHERE date_key = ?',
        [dateKey],
      ),
    );
    return RewardedBonusState(dateKey: dateKey, usedCount: count ?? 0);
  }

  @override
  Future<RewardedBonusClaim> claimRewardedBonus({
    required String claimId,
    required DateTime awardedAt,
  }) async {
    if (claimId.trim().isEmpty) throw ArgumentError.value(claimId, 'claimId');
    final localAwardedAt = awardedAt.toLocal();
    final dateKey = _localDateKey(localAwardedAt);
    final database = await _databaseService.database;
    final claim = await database.transaction((transaction) async {
      final usedCount =
          Sqflite.firstIntValue(
            await transaction.rawQuery(
              'SELECT COUNT(*) FROM rewarded_xp_claims WHERE date_key = ?',
              [dateKey],
            ),
          ) ??
          0;
      final xpRows = await transaction.query(
        'xp_state',
        where: 'id = 1',
        limit: 1,
      );
      final currentXp = xpRows.isEmpty
          ? XpState.initial()
          : XpState.fromMap(xpRows.first);
      if (usedCount >= RewardedBonusState.dailyLimit) {
        return RewardedBonusClaim(
          wasAwarded: false,
          xpState: currentXp,
          bonusState: RewardedBonusState(
            dateKey: dateKey,
            usedCount: usedCount,
          ),
        );
      }

      final inserted = await transaction.insert('rewarded_xp_claims', {
        'claim_id': claimId,
        'date_key': dateKey,
        'awarded_xp': RewardedBonusState.xpPerReward,
        'awarded_at': awardedAt.toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (inserted == 0) {
        return RewardedBonusClaim(
          wasAwarded: false,
          xpState: currentXp,
          bonusState: RewardedBonusState(
            dateKey: dateKey,
            usedCount: usedCount,
          ),
        );
      }

      final nextXp = XpState(
        totalXp: currentXp.totalXp + RewardedBonusState.xpPerReward,
        updatedAt: awardedAt,
      );
      await transaction.insert(
        'xp_state',
        nextXp.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return RewardedBonusClaim(
        wasAwarded: true,
        xpState: nextXp,
        bonusState: RewardedBonusState(
          dateKey: dateKey,
          usedCount: usedCount + 1,
        ),
      );
    });
    _state = claim.xpState;
    return claim;
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

class MemoryRewardedXpStore implements RewardedXpStore {
  MemoryRewardedXpStore({XpState? initialXp})
    : _xpState = initialXp ?? XpState.initial();

  XpState _xpState;
  final Map<String, ({String dateKey, int amount})> _claims = {};

  @override
  Future<RewardedBonusState> loadRewardedBonusState(DateTime localNow) async {
    final dateKey = _localDateKey(localNow);
    return RewardedBonusState(
      dateKey: dateKey,
      usedCount: _claims.values
          .where((claim) => claim.dateKey == dateKey)
          .length,
    );
  }

  @override
  Future<RewardedBonusClaim> claimRewardedBonus({
    required String claimId,
    required DateTime awardedAt,
  }) async {
    final state = await loadRewardedBonusState(awardedAt);
    if (_claims.containsKey(claimId) || state.isExhausted) {
      return RewardedBonusClaim(
        wasAwarded: false,
        xpState: _xpState,
        bonusState: state,
      );
    }
    _claims[claimId] = (
      dateKey: state.dateKey,
      amount: RewardedBonusState.xpPerReward,
    );
    _xpState = XpState(
      totalXp: _xpState.totalXp + RewardedBonusState.xpPerReward,
      updatedAt: awardedAt,
    );
    return RewardedBonusClaim(
      wasAwarded: true,
      xpState: _xpState,
      bonusState: RewardedBonusState(
        dateKey: state.dateKey,
        usedCount: state.usedCount + 1,
      ),
    );
  }
}
