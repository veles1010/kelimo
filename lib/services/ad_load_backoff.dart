/// Reklam yükleme hatalarından sonra SDK isteklerini seyrekleştirir.
///
/// Bu sınıf yalnızca zaman kararını verir; platforma özgü yükleme ve timer
/// yaşam döngüsü ilgili reklam servisinde kalır.
class AdLoadBackoff {
  AdLoadBackoff({DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const retryDelays = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
    Duration(seconds: 300),
  ];

  final DateTime Function() _now;
  int _failureCount = 0;
  DateTime? _nextAttemptAt;

  bool get isWaiting => retryAfter != null;

  Duration? get retryAfter {
    final nextAttemptAt = _nextAttemptAt;
    if (nextAttemptAt == null) return null;
    final remaining = nextAttemptAt.difference(_now());
    return remaining.isNegative || remaining == Duration.zero
        ? null
        : remaining;
  }

  Duration recordFailure() {
    final delay = retryDelayForFailure(_failureCount);
    _failureCount++;
    _nextAttemptAt = _now().add(delay);
    return delay;
  }

  void recordSuccess() {
    _failureCount = 0;
    _nextAttemptAt = null;
  }

  void clearWait() => _nextAttemptAt = null;
}

Duration retryDelayForFailure(int failureIndex) {
  return AdLoadBackoff.retryDelays[failureIndex.clamp(
    0,
    AdLoadBackoff.retryDelays.length - 1,
  )];
}
