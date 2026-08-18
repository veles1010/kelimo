import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:kelimo/repositories/settings_repository.dart';
import 'package:kelimo/screens/onboarding_screen.dart';
import 'package:kelimo/services/settings_service.dart';

class _SettingsMemoryStore implements SettingsStore, OnboardingSettingsStore {
  _SettingsMemoryStore({this.completed = true});

  bool completed;

  @override
  Future<AppSettings> load() async =>
      AppSettings.defaults.copyWith(onboardingCompleted: completed);

  @override
  Future<void> setOnboardingCompleted(bool value) async => completed = value;

  @override
  Future<void> resetToDefaults() async {}

  @override
  Future<int> resolveDailyGoalForDate({
    required String dateKey,
    required int selectedDailyGoal,
  }) async => selectedDailyGoal;

  @override
  Future<void> setDailyGoal(int dailyGoal) async {}

  @override
  Future<void> setReminderEnabled(bool enabled) async {}

  @override
  Future<void> setReminderTime({
    required int hour,
    required int minute,
  }) async {}

  @override
  Future<void> setSpeechRate(SpeechRatePreference speechRate) async {}

  @override
  Future<void> setThemeMode(ThemePreference themeMode) async {}
}

void main() {
  test(
    'eksik onboarding kaydı mevcut kullanıcı için güvenli tamamlanmış sayılır',
    () {
      expect(AppSettings.defaults.onboardingCompleted, isTrue);
    },
  );

  test('onboarding tamamlanması kalıcı store ve servise yazılır', () async {
    final store = _SettingsMemoryStore(completed: false);
    final service = SettingsService(repository: store);
    await service.initialize();
    expect(service.onboardingCompleted, isFalse);
    await service.completeOnboarding();
    expect(store.completed, isTrue);
    final reopened = SettingsService(repository: store);
    await reopened.initialize();
    expect(reopened.onboardingCompleted, isTrue);
  });

  testWidgets('üç sayfalı rehber Atla ve Başlayalım kontrollerini sunar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: OnboardingScreen(onComplete: () async => completed++),
        ),
      ),
    );
    expect(find.text('Her gün birkaç kelime'), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('XP kazan, kategorileri aç'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('1080 parçayı keşfet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-start')));
    await tester.pump();
    expect(completed, 1);
  });

  testWidgets('Atla tamamlanma callbackini bir kez çağırır', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () async => completed++)),
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pump();
    expect(completed, 1);
  });

  testWidgets('rehber koyu temada dar ekranda taşmadan açılır', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: OnboardingScreen(onComplete: () async {}),
        ),
      ),
    );
    expect(find.text('Her gün birkaç kelime'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
