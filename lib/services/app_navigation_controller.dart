import 'package:flutter/foundation.dart';
import 'package:kelimo/services/notification_service.dart';

class AppNavigationController extends ChangeNotifier {
  AppNavigationController({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  bool _dailyReviewPending = false;
  String? _lastPayload;
  DateTime? _lastHandledAt;

  bool handlePayload(String? payload) {
    final now = _now();
    final isDuplicate =
        payload == _lastPayload &&
        _lastHandledAt != null &&
        now.difference(_lastHandledAt!) < const Duration(seconds: 2);
    if (payload != LocalNotificationService.dailyReminderPayload ||
        _dailyReviewPending ||
        isDuplicate) {
      return false;
    }
    _lastPayload = payload;
    _lastHandledAt = now;
    _dailyReviewPending = true;
    notifyListeners();
    return true;
  }

  bool consumeDailyReviewRequest() {
    if (!_dailyReviewPending) return false;
    _dailyReviewPending = false;
    return true;
  }
}
