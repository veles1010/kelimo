import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class StreakService extends ChangeNotifier {
  StreakService({this.dailyGoal = 5, int initialStreak = 7})
    : assert(dailyGoal > 0),
      _currentStreak = initialStreak;

  final int dailyGoal;

  int _todayCount = 0;
  int _currentStreak;
  bool _isTodayCompleted = false;

  int get todayCount => _todayCount;
  int get currentStreak => _currentStreak;
  bool get isTodayCompleted => _isTodayCompleted;
  int get remainingForToday => math.max(0, dailyGoal - _todayCount);

  bool recordEvaluation() {
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
}
