import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kelimo/models/daily_progress.dart';
import 'package:kelimo/repositories/daily_progress_repository.dart';

class StreakService extends ChangeNotifier {
  StreakService({this.dailyGoal = 5, int initialStreak = 7, this.repository})
    : _initialStreak = initialStreak,
      assert(dailyGoal > 0),
      _currentStreak = initialStreak;

  final int dailyGoal;
  final DailyProgressStore? repository;
  final int _initialStreak;

  int _todayCount = 0;
  int _currentStreak;
  bool _isTodayCompleted = false;

  int get todayCount => _todayCount;
  int get currentStreak => _currentStreak;
  bool get isTodayCompleted => _isTodayCompleted;
  int get remainingForToday => math.max(0, dailyGoal - _todayCount);

  Future<void> initialize() async {
    final progressRepository = repository;
    if (progressRepository == null) return;

    try {
      final snapshot = await progressRepository.loadToday(
        initialStreak: _initialStreak,
      );
      _applySnapshot(snapshot);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Seri servisi başlatılamadı: $error\n$stackTrace');
    }
  }

  Future<bool> recordEvaluation() async {
    final progressRepository = repository;
    if (progressRepository != null) {
      try {
        final snapshot = await progressRepository.incrementReview(
          dailyGoal: dailyGoal,
          initialStreak: _initialStreak,
        );
        _applySnapshot(snapshot);
        notifyListeners();
        return snapshot.justCompleted;
      } catch (error, stackTrace) {
        debugPrint('Seri ilerlemesi kalıcılaştırılamadı: $error\n$stackTrace');
      }
    }

    return _recordInMemory();
  }

  bool _recordInMemory() {
    _todayCount++;
    var justCompleted = false;

    if (!_isTodayCompleted && _todayCount >= dailyGoal) {
      _isTodayCompleted = true;
      _currentStreak++;
      justCompleted = true;
    }

    notifyListeners();
    return justCompleted;
  }

  void _applySnapshot(DailyProgressSnapshot snapshot) {
    _todayCount = snapshot.progress.reviewCount;
    _isTodayCompleted = snapshot.progress.isGoalCompleted;
    _currentStreak = snapshot.streak.currentStreak;
  }
}
