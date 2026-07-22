import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:kelimo/models/rewarded_bonus.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/repositories/settings_repository.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/screens/onboarding_screen.dart';
import 'package:kelimo/services/rewarded_ad_service.dart';
import 'package:kelimo/services/rewarded_bonus_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/xp_service.dart';

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

class _XpRewardMemoryStore implements XpStore, RewardedXpStore {
  _XpRewardMemoryStore({int initialXp = 0})
    : state = XpState(totalXp: initialXp, updatedAt: DateTime(2026));

  XpState state;
  final Map<String, String> claims = {};

  @override
  int get currentTotalXp => state.totalXp;
  @override
  Future<XpState> loadState() async => state;
  @override
  void synchronizeState(XpState value) => state = value;
  @override
  Future<XpState> addXp(int amount) async => state = XpState(
    totalXp: state.totalXp + amount,
    updatedAt: DateTime.now(),
  );
  @override
  Future<void> resetXp() async => state = XpState.initial();

  @override
  Future<RewardedBonusState> loadRewardedBonusState(DateTime localNow) async {
    final key = _dateKey(localNow);
    return RewardedBonusState(
      dateKey: key,
      usedCount: claims.values.where((value) => value == key).length,
    );
  }

  @override
  Future<RewardedBonusClaim> claimRewardedBonus({
    required String claimId,
    required DateTime awardedAt,
  }) async {
    final bonus = await loadRewardedBonusState(awardedAt);
    if (claims.containsKey(claimId) || bonus.isExhausted) {
      return RewardedBonusClaim(
        wasAwarded: false,
        xpState: state,
        bonusState: bonus,
      );
    }
    claims[claimId] = bonus.dateKey;
    state = XpState(
      totalXp: state.totalXp + RewardedBonusState.xpPerReward,
      updatedAt: awardedAt,
    );
    return RewardedBonusClaim(
      wasAwarded: true,
      xpState: state,
      bonusState: RewardedBonusState(
        dateKey: bonus.dateKey,
        usedCount: bonus.usedCount + 1,
      ),
    );
  }
}

class _FakeRewardedAdService extends RewardedAdService {
  _FakeRewardedAdService();

  bool enabled = true;
  bool ready = true;
  bool loading = false;
  int preloadCalls = 0;
  final List<RewardedAdResult> results = [];

  @override
  bool get isEnabled => enabled;
  @override
  bool get isLoading => loading;
  @override
  bool get isReady => ready;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> preload() async => preloadCalls++;
  @override
  Future<RewardedAdResult> show() async => results.isEmpty
      ? const RewardedAdResult(outcome: RewardedAdOutcome.unavailable)
      : results.removeAt(0);
}

class _DelayedReadyAdService extends RewardedAdService {
  bool _loading = false;
  bool _ready = false;
  int preloadCalls = 0;

  @override
  bool get isEnabled => true;
  @override
  bool get isLoading => _loading;
  @override
  bool get isReady => _ready;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> preload() async {
    if (_loading || _ready) return;
    _loading = true;
    preloadCalls++;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 10), () {
        _loading = false;
        _ready = true;
        notifyListeners();
      }),
    );
  }

  @override
  Future<RewardedAdResult> show() async => const RewardedAdResult(
    outcome: RewardedAdOutcome.rewarded,
    claimId: 'delayed-ready',
  );
}

class _ConsentSource extends ChangeNotifier {
  bool ready = false;

  void allowAds() {
    ready = true;
    notifyListeners();
  }
}

class _ConsentAwareDelayedAdService extends RewardedAdService {
  _ConsentAwareDelayedAdService(this.consent);

  final _ConsentSource consent;
  bool _ready = false;
  bool _loading = false;
  int preloadCalls = 0;
  int consentRequests = 0;

  @override
  bool get isEnabled => true;
  @override
  bool get isLoading => _loading;
  @override
  bool get isReady => _ready;

  @override
  Future<void> initialize() async {
    consent.addListener(_onConsentChanged);
    await _requestConsentThenPreload();
  }

  void _onConsentChanged() {
    if (consent.ready) unawaited(preload());
  }

  Future<void> _requestConsentThenPreload() async {
    if (!consent.ready) {
      consentRequests++;
      return;
    }
    await preload();
  }

  @override
  Future<void> preload() async {
    if (!consent.ready || _ready || _loading) return;
    _loading = true;
    preloadCalls++;
    await Future<void>.delayed(Duration.zero);
    _loading = false;
    _ready = true;
    notifyListeners();
  }

  @override
  Future<RewardedAdResult> show() async => const RewardedAdResult(
    outcome: RewardedAdOutcome.rewarded,
    claimId: 'consent-aware',
  );
}

String _dateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

Future<RewardedBonusService> _createBonus({
  required _XpRewardMemoryStore store,
  required _FakeRewardedAdService ad,
  required DateTime Function() now,
}) async {
  final xp = XpService(repository: store);
  await xp.initialize();
  final service = RewardedBonusService(
    repository: store,
    adService: ad,
    xpService: xp,
    now: now,
  );
  await service.initialize();
  return service;
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

  test('ödül callbacki tam 15 XP verir ve aynı claim tekrarlanamaz', () async {
    final now = DateTime(2026, 7, 22, 12);
    final store = _XpRewardMemoryStore(initialXp: 90);
    final ad = _FakeRewardedAdService()
      ..results.addAll(const [
        RewardedAdResult(
          outcome: RewardedAdOutcome.rewarded,
          claimId: 'same-claim',
        ),
        RewardedAdResult(
          outcome: RewardedAdOutcome.rewarded,
          claimId: 'same-claim',
        ),
      ]);
    final service = await _createBonus(store: store, ad: ad, now: () => now);
    expect(await service.watchAd(), RewardedBonusResult.awarded);
    expect(store.state.totalXp, 105);
    expect(await service.watchAd(), RewardedBonusResult.failed);
    expect(store.state.totalXp, 105);
    expect(service.remainingCount, 1);
  });

  test(
    'günde iki ödülden sonra üçüncü engellenir, yeni günde yenilenir',
    () async {
      var now = DateTime(2026, 7, 22, 23, 30);
      final store = _XpRewardMemoryStore();
      final ad = _FakeRewardedAdService()
        ..results.addAll(const [
          RewardedAdResult(outcome: RewardedAdOutcome.rewarded, claimId: 'a'),
          RewardedAdResult(outcome: RewardedAdOutcome.rewarded, claimId: 'b'),
          RewardedAdResult(outcome: RewardedAdOutcome.rewarded, claimId: 'c'),
        ]);
      final service = await _createBonus(store: store, ad: ad, now: () => now);
      expect(await service.watchAd(), RewardedBonusResult.awarded);
      expect(await service.watchAd(), RewardedBonusResult.awarded);
      expect(await service.watchAd(), RewardedBonusResult.exhausted);
      expect(store.state.totalXp, 30);
      now = DateTime(2026, 7, 23, 0, 1);
      await service.refresh();
      expect(service.remainingCount, 2);
      expect(await service.watchAd(), RewardedBonusResult.awarded);
      expect(store.state.totalXp, 45);
    },
  );

  test('gelecek tarihli kayıt bugünün hakkını tüketmez', () async {
    final store = _XpRewardMemoryStore();
    await store.claimRewardedBonus(
      claimId: 'future',
      awardedAt: DateTime(2026, 7, 25),
    );
    final state = await store.loadRewardedBonusState(DateTime(2026, 7, 22));
    expect(state.remainingCount, 2);
  });

  test('ödülsüz kapanma ve hata XP vermez', () async {
    final now = DateTime(2026, 7, 22);
    final store = _XpRewardMemoryStore();
    final ad = _FakeRewardedAdService()
      ..results.addAll(const [
        RewardedAdResult(outcome: RewardedAdOutcome.dismissed),
        RewardedAdResult(outcome: RewardedAdOutcome.failed),
      ]);
    final service = await _createBonus(store: store, ad: ad, now: () => now);
    expect(await service.watchAd(), RewardedBonusResult.dismissed);
    expect(await service.watchAd(), RewardedBonusResult.failed);
    expect(store.state.totalXp, 0);
    expect(service.remainingCount, 2);
  });

  test('debug test ID seçilir, release kimliği yoksa özellik kapanır', () {
    expect(
      resolveRewardedAdUnitId(
        isRelease: false,
        platform: 'android',
        releaseId: '',
      ),
      GoogleRewardedAdService.androidTestRewardedAdUnitId,
    );
    expect(
      resolveRewardedAdUnitId(isRelease: false, platform: 'ios', releaseId: ''),
      GoogleRewardedAdService.iosTestRewardedAdUnitId,
    );
    expect(
      resolveRewardedAdUnitId(
        isRelease: true,
        platform: 'android',
        releaseId: '',
      ),
      isNull,
    );
    expect(
      GoogleRewardedAdService.androidTestRewardedAdUnitId,
      isNot(GoogleRewardedAdService.iosTestRewardedAdUnitId),
    );
  });

  test('load gate eşzamanlı ikinci yüklemeyi engeller', () {
    final gate = RewardedLoadGate();
    expect(gate.tryStart(), isTrue);
    expect(gate.tryStart(), isFalse);
    expect(gate.isLoading, isTrue);
    gate.finish();
    expect(gate.tryStart(), isTrue);
  });

  test('retry artan ve sınırlı gecikme kullanır', () {
    expect(rewardedRetryDelay(0), const Duration(seconds: 1));
    expect(rewardedRetryDelay(1), const Duration(seconds: 2));
    expect(rewardedRetryDelay(2), const Duration(seconds: 4));
    expect(rewardedRetryDelay(8), const Duration(seconds: 4));
  });

  test(
    'reklam hazırlanırken ensureReady bekler ve tek preload başlatır',
    () async {
      final ad = _DelayedReadyAdService();
      expect(await ad.ensureReady(timeout: const Duration(seconds: 1)), isTrue);
      expect(ad.preloadCalls, 1);
      expect(ad.isReady, isTrue);
    },
  );

  test(
    'consent başlangıçta kapalıyken izin sonrası tek rewarded preload başlar',
    () async {
      final consent = _ConsentSource();
      final ad = _ConsentAwareDelayedAdService(consent);
      await ad.initialize();
      expect(ad.preloadCalls, 0);
      expect(ad.consentRequests, 1);

      consent.allowAds();
      await Future<void>.delayed(Duration.zero);
      expect(ad.preloadCalls, 1);
      expect(ad.isReady, isTrue);

      consent.notifyListeners();
      await Future<void>.delayed(Duration.zero);
      expect(ad.preloadCalls, 1);
    },
  );
}
