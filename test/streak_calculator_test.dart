import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/services/streak_calculator.dart';

void main() {
  const calculator = StreakCalculator();
  final today = DateTime(2026, 7, 22, 12);

  test('boş etkinliklerde seri sıfırdır', () {
    expect(calculator.calculate(const [], now: today), 0);
  });

  test('aynı gündeki yedi etkinlik tek seri günü sayılır', () {
    final activities = List.generate(
      7,
      (index) => DateTime(2026, 7, 22, 8 + index),
    );
    expect(calculator.calculate(activities, now: today), 1);
  });

  test('bugün ve dün art arda iki gündür', () {
    expect(
      calculator.calculate([
        DateTime(2026, 7, 22),
        DateTime(2026, 7, 21),
      ], now: today),
      2,
    );
  });

  test('bugün çalışılmadıysa dün ve önceki gün serisi korunur', () {
    expect(
      calculator.calculate([
        DateTime(2026, 7, 20),
        DateTime(2026, 7, 21),
      ], now: today),
      2,
    );
  });

  test('gün boşluğu seriyi keser', () {
    expect(
      calculator.calculate([
        DateTime(2026, 7, 20),
        DateTime(2026, 7, 22),
      ], now: today),
      1,
    );
  });

  test('sırasız ve tekrarlanan timestamp kayıtlarını tekilleştirir', () {
    expect(
      calculator.calculate([
        DateTime(2026, 7, 20, 18),
        DateTime(2026, 7, 22, 9),
        DateTime(2026, 7, 21, 11),
        DateTime(2026, 7, 22, 9),
        DateTime(2026, 7, 21, 20),
      ], now: today),
      3,
    );
  });

  test('UTC gece sınırını enjekte edilen yerel saate göre hesaplar', () {
    final istanbulCalculator = StreakCalculator(
      toLocal: (value) => value.toUtc().add(const Duration(hours: 3)),
    );
    final nowUtc = DateTime.utc(2026, 7, 21, 22);
    final activities = [
      DateTime.utc(2026, 7, 20, 22, 30),
      DateTime.utc(2026, 7, 21, 21, 30),
    ];

    expect(istanbulCalculator.calculate(activities, now: nowUtc), 2);
  });

  test('gelecek tarihli ve geçersiz seri günleri yok sayılır', () {
    expect(
      calculator.calculate([
        DateTime(2026, 7, 23),
        DateTime(2026, 7, 21),
      ], now: today),
      1,
    );
  });
}
