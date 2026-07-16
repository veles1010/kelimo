import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/screens/settings_screen.dart';
import 'package:kelimo/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

void main() {
  late timezone.Location istanbul;

  setUpAll(() {
    timezone_data.initializeTimeZones();
    istanbul = timezone.getLocation('Europe/Istanbul');
  });

  test('Hatırlatma saati gece yarısında 24 saat biçimini korur', () {
    expect(formatReminderTime24Hour(0, 35), '00:35');
    expect(formatReminderTime24Hour(8, 5), '08:05');
    expect(formatReminderTime24Hour(12, 35), '12:35');
    expect(formatReminderTime24Hour(20, 0), '20:00');
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
