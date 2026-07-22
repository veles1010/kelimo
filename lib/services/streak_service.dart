import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kelimo/models/daily_progress.dart';
import 'package:kelimo/repositories/daily_progress_repository.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/streak_calculator.dart';

class StreakService extends ChangeNotifier {
  StreakService({
    int dailyGoal = 5,
    this.repository,
    this.settingsService,
    DateTime Function()? now,
  }) : _fallbackDailyGoal = dailyGoal,
       _now = now ?? DateTime.now,
       assert(dailyGoal > 0),
       _currentStreak = 0;

  final int _fallbackDailyGoal;
  final DailyProgressStore? repository;
  final SettingsService? settingsService;
  final DateTime Function() _now;
  final Set<DateTime> _inMemoryActivityTimes = {};

  int _todayCount = 0;
  int _currentStreak;
  bool _isTodayCompleted = false;

  int get todayCount => _todayCount;
  int get currentStreak => _currentStreak;
  bool get isTodayCompleted => _isTodayCompleted;
  int get dailyGoal => settingsService?.activeDailyGoal ?? _fallbackDailyGoal;
  int get remainingForToday => math.max(0, dailyGoal - _todayCount);

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    final progressRepository = repository;
    if (progressRepository == null) return;

    try {
      final snapshot = await progressRepository.loadToday(now: _now());
      _applySnapshot(snapshot);
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Seri servisi başlatılamadı: $error\n$stackTrace');
    }
  }

  Future<bool> recordEvaluation() async {
    await settingsService?.refreshActiveDailyGoal();
    final progressRepository = repository;
    if (progressRepository != null) {
      try {
        final snapshot = await progressRepository.incrementReview(
          dailyGoal: dailyGoal,
          now: _now(),
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
    final now = _now();
    _todayCount++;
    _inMemoryActivityTimes.add(now);
    _currentStreak = const StreakCalculator().calculate(
      _inMemoryActivityTimes,
      now: now,
    );
    var justCompleted = false;

    if (!_isTodayCompleted && _todayCount >= dailyGoal) {
      _isTodayCompleted = true;
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

  void resetAfterDataClear() {
    _todayCount = 0;
    _currentStreak = 0;
    _isTodayCompleted = false;
    _inMemoryActivityTimes.clear();
    notifyListeners();
  }
}
