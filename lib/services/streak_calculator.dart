class StreakCalculator {
  const StreakCalculator({this.toLocal});

  final DateTime Function(DateTime)? toLocal;

  int calculate(Iterable<DateTime> activityTimes, {required DateTime now}) {
    final today = _localDay(now);
    final activityDays = activityTimes
        .map(_localDay)
        .where((day) => !day.isAfter(today))
        .toSet();

    var cursor = activityDays.contains(today)
        ? today
        : _previousCalendarDay(today);
    if (!activityDays.contains(cursor)) return 0;

    var streak = 0;
    while (activityDays.contains(cursor)) {
      streak++;
      cursor = _previousCalendarDay(cursor);
    }
    return streak;
  }

  DateTime? latestValidActivity(
    Iterable<DateTime> activityTimes, {
    required DateTime now,
  }) {
    final today = _localDay(now);
    DateTime? latest;
    for (final time in activityTimes) {
      final day = _localDay(time);
      if (day.isAfter(today)) continue;
      if (latest == null || day.isAfter(latest)) latest = day;
    }
    return latest;
  }

  DateTime _localDay(DateTime value) {
    final local = toLocal?.call(value) ?? value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime _previousCalendarDay(DateTime day) {
    return DateTime(day.year, day.month, day.day - 1);
  }
}
