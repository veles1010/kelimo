import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

enum NotificationPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  unknown,
}

abstract interface class NotificationService {
  Stream<String> get payloads;

  Future<void> initialize();
  Future<NotificationPermissionStatus> requestPermission();
  Future<NotificationPermissionStatus> notificationPermissionStatus();
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  });
  Future<void> scheduleTestNotification({
    required String title,
    required String body,
    required String payload,
    Duration delay = const Duration(seconds: 10),
  });
  Future<void> cancelDailyReminder();
  Future<void> cancelTestNotification();
  Future<void> cancelAllReminders();
  Future<String?> getLaunchPayload();
  void dispose();
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const dailyReminderId = 42001;
  static const testReminderId = 42002;
  static const dailyReminderChannelId = 'kelimo_daily_reminder';
  static const dailyReminderPayload = 'daily_review';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _payloadController =
      StreamController<String>.broadcast();
  bool _initialized = false;

  @override
  Stream<String> get payloads => _payloadController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
      debugPrint('Algılanan cihaz saat dilimi: ${localTimezone.identifier}');
    } catch (error, stackTrace) {
      debugPrint('Yerel saat dilimi belirlenemedi: $error\n$stackTrace');
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      ),
    );
    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          _payloadController.add(payload);
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            dailyReminderChannelId,
            'Günlük çalışma hatırlatıcıları',
            description: 'Kelimo günlük çalışma hatırlatıcıları',
            importance: Importance.defaultImportance,
          ),
        );
    _initialized = true;
  }

  @override
  Future<NotificationPermissionStatus> notificationPermissionStatus() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final enabled = await android.areNotificationsEnabled();
      return enabled == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      return permissions?.isEnabled == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }
    return NotificationPermissionStatus.unknown;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.denied;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted == true
          ? NotificationPermissionStatus.granted
          : NotificationPermissionStatus.permanentlyDenied;
    }
    return NotificationPermissionStatus.denied;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    final now = timezone.TZDateTime.now(timezone.local);
    final next = nextDailyReminderTime(
      now: now,
      location: timezone.local,
      hour: hour,
      minute: minute,
    );
    debugPrint(
      'Günlük bildirim planı (yerel): $next | '
      'ISO 8601 UTC: ${next.toUtc().toIso8601String()}',
    );

    await cancelDailyReminder();
    await _plugin.zonedSchedule(
      id: dailyReminderId,
      title: title,
      body: body,
      scheduledDate: next,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          dailyReminderChannelId,
          'Günlük çalışma hatırlatıcıları',
          channelDescription: 'Kelimo günlük çalışma hatırlatıcıları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  @override
  Future<void> cancelDailyReminder() => _plugin.cancel(id: dailyReminderId);

  @override
  Future<void> scheduleTestNotification({
    required String title,
    required String body,
    required String payload,
    Duration delay = const Duration(seconds: 10),
  }) async {
    final scheduledDate = timezone.TZDateTime.now(timezone.local).add(delay);
    await cancelTestNotification();
    debugPrint(
      'Test bildirimi planı (yerel): $scheduledDate | '
      'ISO 8601 UTC: ${scheduledDate.toUtc().toIso8601String()}',
    );
    await _plugin.zonedSchedule(
      id: testReminderId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          dailyReminderChannelId,
          'Günlük çalışma hatırlatıcıları',
          channelDescription: 'Kelimo günlük çalışma hatırlatıcıları',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: 'ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          presentBanner: true,
          presentList: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancelTestNotification() => _plugin.cancel(id: testReminderId);

  @override
  Future<void> cancelAllReminders() async {
    await cancelDailyReminder();
    await cancelTestNotification();
  }

  @override
  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details?.notificationResponse?.payload;
    return payload == null || payload.isEmpty ? null : payload;
  }

  @override
  void dispose() => _payloadController.close();
}

timezone.TZDateTime nextDailyReminderTime({
  required timezone.TZDateTime now,
  required timezone.Location location,
  required int hour,
  required int minute,
}) {
  var scheduled = timezone.TZDateTime(
    location,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!scheduled.isAfter(now)) {
    scheduled = timezone.TZDateTime(
      location,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
  return scheduled;
}
