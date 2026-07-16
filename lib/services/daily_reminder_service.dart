import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/notification_service.dart';
import 'package:kelimo/services/settings_service.dart';

enum ReminderUpdateResult {
  success,
  permissionDenied,
  permanentlyDenied,
  failed,
}

class DailyReminderService extends ChangeNotifier {
  DailyReminderService({
    required this.settingsService,
    required this.notificationService,
    required this.learningCenterService,
  });

  final SettingsService settingsService;
  final NotificationService notificationService;
  final LearningCenterService learningCenterService;

  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.unknown;
  bool _isLoading = true;
  Future<void> _scheduleQueue = Future.value();

  NotificationPermissionStatus get permissionStatus => _permissionStatus;
  bool get isLoading => _isLoading;
  bool get isEnabled => settingsService.reminderEnabled;
  int get hour => settingsService.reminderHour;
  int get minute => settingsService.reminderMinute;
  Stream<String> get payloads => notificationService.payloads;

  Future<void> initialize() async {
    _isLoading = true;
    try {
      await notificationService.initialize();
      _permissionStatus = await notificationService
          .notificationPermissionStatus();
      if (isEnabled) {
        if (_permissionStatus == NotificationPermissionStatus.granted) {
          await refreshSchedule();
        } else {
          await settingsService.setReminderEnabled(false);
          await _cancelSafely();
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Hatırlatıcı servisi başlatılamadı: $error\n$stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<NotificationPermissionStatus> requestPermission() async {
    try {
      _permissionStatus = await notificationService.requestPermission();
    } catch (error, stackTrace) {
      debugPrint('Bildirim izni istenemedi: $error\n$stackTrace');
      _permissionStatus = NotificationPermissionStatus.denied;
    }
    notifyListeners();
    return _permissionStatus;
  }

  Future<ReminderUpdateResult> setEnabled(bool enabled) async {
    if (!enabled) {
      try {
        await settingsService.setReminderEnabled(false);
        await notificationService.cancelDailyReminder();
        notifyListeners();
        return ReminderUpdateResult.success;
      } catch (error, stackTrace) {
        debugPrint('Hatırlatıcı kapatılamadı: $error\n$stackTrace');
        return ReminderUpdateResult.failed;
      }
    }

    var status = _permissionStatus;
    if (status != NotificationPermissionStatus.granted) {
      status = await requestPermission();
    }
    if (status != NotificationPermissionStatus.granted) {
      try {
        await settingsService.setReminderEnabled(false);
        await _cancelSafely();
        return status == NotificationPermissionStatus.permanentlyDenied
            ? ReminderUpdateResult.permanentlyDenied
            : ReminderUpdateResult.permissionDenied;
      } catch (error, stackTrace) {
        debugPrint('Hatırlatıcı tercihi kapatılamadı: $error\n$stackTrace');
        return ReminderUpdateResult.failed;
      }
    }

    try {
      await settingsService.setReminderEnabled(true);
      if (!await refreshSchedule()) {
        await settingsService.setReminderEnabled(false);
        await _cancelSafely();
        return ReminderUpdateResult.failed;
      }
      notifyListeners();
      return ReminderUpdateResult.success;
    } catch (error, stackTrace) {
      debugPrint('Hatırlatıcı açılamadı: $error\n$stackTrace');
      await _cancelSafely();
      return ReminderUpdateResult.failed;
    }
  }

  Future<bool> setTime({required int hour, required int minute}) async {
    try {
      await settingsService.setReminderTime(hour: hour, minute: minute);
      final scheduled = !isEnabled || await refreshSchedule();
      notifyListeners();
      return scheduled;
    } catch (error, stackTrace) {
      debugPrint('Hatırlatma saati güncellenemedi: $error\n$stackTrace');
      return false;
    }
  }

  Future<ReminderUpdateResult> scheduleTestNotification() async {
    var status = _permissionStatus;
    if (status != NotificationPermissionStatus.granted) {
      status = await requestPermission();
    }
    if (status != NotificationPermissionStatus.granted) {
      return status == NotificationPermissionStatus.permanentlyDenied
          ? ReminderUpdateResult.permanentlyDenied
          : ReminderUpdateResult.permissionDenied;
    }
    try {
      await notificationService.scheduleTestNotification(
        title: 'Kelimo test bildirimi',
        body: 'Günlük çalışma hatırlatıcın hazır.',
        payload: LocalNotificationService.dailyReminderPayload,
      );
      return ReminderUpdateResult.success;
    } catch (error, stackTrace) {
      debugPrint('Test bildirimi planlanamadı: $error\n$stackTrace');
      return ReminderUpdateResult.failed;
    }
  }

  Future<bool> refreshSchedule() {
    final completer = Completer<bool>();
    _scheduleQueue = _scheduleQueue.then((_) async {
      if (!isEnabled) {
        await _cancelSafely();
        completer.complete(true);
        return;
      }
      try {
        _permissionStatus = await notificationService
            .notificationPermissionStatus();
        if (_permissionStatus != NotificationPermissionStatus.granted) {
          completer.complete(false);
          notifyListeners();
          return;
        }
        final hasDueReviews =
            learningCenterService.load().repeatPendingCount > 0;
        await notificationService.scheduleDailyReminder(
          hour: hour,
          minute: minute,
          title: hasDueReviews
              ? 'Tekrar zamanı!'
              : 'Bugünün kelimelerine hazır mısın?',
          body: hasDueReviews
              ? 'Çalışma zamanı gelen kelimelerin seni bekliyor.'
              : 'Kelimo’da birkaç kelime çalışarak serini koru.',
          payload: LocalNotificationService.dailyReminderPayload,
        );
        completer.complete(true);
        notifyListeners();
      } catch (error, stackTrace) {
        debugPrint('Günlük hatırlatıcı planlanamadı: $error\n$stackTrace');
        completer.complete(false);
      }
    });
    return completer.future;
  }

  Future<void> resetPreferences() async {
    await settingsService.resetToDefaults();
    await notificationService.cancelAllReminders();
    notifyListeners();
  }

  Future<void> resetAllNotifications() async {
    await notificationService.cancelAllReminders();
    notifyListeners();
  }

  Future<String?> getLaunchPayload() => notificationService.getLaunchPayload();

  Future<void> _cancelSafely() async {
    try {
      await notificationService.cancelDailyReminder();
    } catch (error, stackTrace) {
      debugPrint('Hatırlatıcı iptal edilemedi: $error\n$stackTrace');
    }
  }
}
