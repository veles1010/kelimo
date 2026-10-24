import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/screens/settings_screen.dart';
import 'package:kelimo/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

void main() {
  late timezone.Location istanbul;

  setUpAll(() {
    timezone_data.initializeTimeZones();
    timezone.setLocalLocation(timezone.UTC);
    istanbul = timezone.getLocation('Europe/Istanbul');
  });

  test('Scheduling waits for shared timezone and plugin initialization', () async {
    final identifier = Completer<String>();
    final pluginReady = Completer<bool>();
    final plugin = _NotificationPluginDouble()..initializationGate = pluginReady;
    var timezoneLoads = 0;
    final service = LocalNotificationService(
      plugin: plugin,
      timezoneIdentifierLoader: () {
        timezoneLoads++;
        return identifier.future;
      },
    );
    addTearDown(service.dispose);
    final originalLocation = timezone.local;
    addTearDown(() => timezone.setLocalLocation(originalLocation));
    timezone.setLocalLocation(timezone.UTC);

    final firstInitialization = service.initialize();
    final secondInitialization = service.initialize();
    final daily = service.scheduleDailyReminder(
      hour: 9,
      minute: 30,
      title: 'Daily',
      body: 'Review',
      payload: 'daily',
    );
    final preview = service.scheduleTestNotification(
      title: 'Test',
      body: 'Review',
      payload: 'test',
    );
    await Future<void>.delayed(Duration.zero);
    expect(timezoneLoads, 1);
    expect(plugin.initializeCalls, 0);
    expect(plugin.scheduledDates, isEmpty);
    expect(plugin.cancelCalls, 0);

    identifier.complete('Europe/Istanbul');
    await Future<void>.delayed(Duration.zero);
    expect(plugin.initializeCalls, 1);
    expect(plugin.scheduledDates, isEmpty);
    expect(plugin.cancelCalls, 0);

    pluginReady.complete(true);
    await Future.wait([
      firstInitialization,
      secondInitialization,
      daily,
      preview,
    ]);
    expect(
      plugin.scheduledDates.keys,
      unorderedEquals([
        LocalNotificationService.dailyReminderId,
        LocalNotificationService.testReminderId,
      ]),
    );
    for (final date in plugin.scheduledDates.values) {
      expect(date.location.name, 'Europe/Istanbul');
    }
    final dailyDate =
        plugin.scheduledDates[LocalNotificationService.dailyReminderId]!;
    expect(dailyDate.hour, 9);
    expect(dailyDate.minute, 30);
    await service.initialize();
    expect(timezoneLoads, 1);
    expect(plugin.initializeCalls, 1);
  });

  test('Failed plugin initialization can be retried before scheduling', () async {
    final plugin = _NotificationPluginDouble()..initializationFailures = 1;
    final service = LocalNotificationService(
      plugin: plugin,
      timezoneIdentifierLoader: () async => 'Europe/Istanbul',
    );
    addTearDown(service.dispose);
    final originalLocation = timezone.local;
    addTearDown(() => timezone.setLocalLocation(originalLocation));

    Future<void> schedule() => service.scheduleDailyReminder(
      hour: 9,
      minute: 30,
      title: 'Daily',
      body: 'Review',
      payload: 'daily',
    );
    await expectLater(schedule(), throwsStateError);
    expect(plugin.scheduledDates, isEmpty);
    await schedule();
    expect(plugin.initializeCalls, 2);
    expect(plugin.scheduledDates, hasLength(1));
  });

  test('Hatırlatma saati gece yarısında 24 saat biçimini korur', () {
    expect(formatReminderTime24Hour(0, 35), '00:35');
    expect(formatReminderTime24Hour(8, 5), '08:05');
    expect(formatReminderTime24Hour(12, 35), '12:35');
    expect(formatReminderTime24Hour(20, 0), '20:00');
  });

  test('Geçerli IANA saat dilimi kimliğini korur', () {
    final location = resolveTimezoneLocation('Europe/Istanbul');

    expect(location.name, 'Europe/Istanbul');
  });

  test('UTC eşdeğeri kimlikleri UTC konumuna normalize eder', () {
    for (final identifier in ['GMT', 'UTC', 'Etc/UTC']) {
      expect(resolveTimezoneLocation(identifier), same(timezone.UTC));
    }
  });

  test('Geçersiz saat dilimi kimliği UTC konumuna düşer', () {
    expect(resolveTimezoneLocation('Unknown/Timezone'), same(timezone.UTC));
  });

  test('Gelecekteki bugünkü saat aynı güne planlanır', () {
    final now = timezone.TZDateTime(istanbul, 2026, 7, 17, 0, 10);
    final scheduled = nextDailyReminderTime(
      now: now,
      location: istanbul,
      hour: 0,
      minute: 35,
    );

    expect(scheduled, timezone.TZDateTime(istanbul, 2026, 7, 17, 0, 35));
    expect(scheduled.toUtc().toIso8601String(), '2026-07-16T21:35:00.000Z');
  });

  test('Geçmiş bugünkü saat yalnızca ertesi güne planlanır', () {
    final now = timezone.TZDateTime(istanbul, 2026, 7, 17, 0, 40);
    final scheduled = nextDailyReminderTime(
      now: now,
      location: istanbul,
      hour: 0,
      minute: 35,
    );

    expect(scheduled, timezone.TZDateTime(istanbul, 2026, 7, 18, 0, 35));
  });
}

class _NotificationPluginDouble implements FlutterLocalNotificationsPlugin {
  Completer<bool>? initializationGate;
  int initializationFailures = 0;
  int initializeCalls = 0;
  int cancelCalls = 0;
  final scheduledDates = <int, timezone.TZDateTime>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #initialize) {
      initializeCalls++;
      if (initializationFailures > 0) {
        initializationFailures--;
        return Future<bool>.error(StateError('Native initialization failed'));
      }
      return initializationGate?.future ?? Future<bool>.value(true);
    }
    if (invocation.memberName == #resolvePlatformSpecificImplementation) {
      return null;
    }
    if (invocation.memberName == #cancel) {
      cancelCalls++;
      return Future<void>.value();
    }
    if (invocation.memberName == #zonedSchedule) {
      scheduledDates[invocation.namedArguments[#id] as int] =
          invocation.namedArguments[#scheduledDate] as timezone.TZDateTime;
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
