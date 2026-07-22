import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/achievement_catalog.dart';
import 'package:kelimo/models/achievement.dart';
import 'package:kelimo/repositories/achievement_repository.dart';
import 'package:kelimo/screens/achievements_screen.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/widgets/achievement_notification.dart';
import 'package:kelimo/widgets/glass_surface.dart';

class _FakeAchievementStore implements AchievementStore {
  _FakeAchievementStore([Iterable<AchievementUnlock> initial = const []]) {
    for (final unlock in initial) {
      records[unlock.achievementId] = unlock;
    }
  }

  final Map<String, AchievementUnlock> records = {};
  int unlockCalls = 0;

  @override
  Future<void> clearAll() async => records.clear();

  @override
  void clearCachedData() {}

  @override
  bool isUnlocked(String id) => records.containsKey(id);

  @override
  Future<List<AchievementUnlock>> loadUnlocked() async =>
      List.unmodifiable(records.values);

  @override
  Future<bool> unlock(String id, DateTime unlockedAt) async {
    unlockCalls++;
    if (records.containsKey(id)) return false;
    records[id] = AchievementUnlock(
      achievementId: id,
      unlockedAt: unlockedAt.toUtc(),
    );
    return true;
  }
}

class _MutableMetricsSource implements AchievementMetricsSource {
  _MutableMetricsSource(this.metrics);

  AchievementMetrics metrics;

  @override
  Future<AchievementMetrics> load() async => metrics;
}

AchievementMetrics _metrics({
  int reviews = 0,
  int learned = 0,
  int favorites = 0,
  int quizzes = 0,
  bool perfect = false,
  int streak = 0,
}) {
  return AchievementMetrics(
    totalReviewCount: reviews,
    learnedWordCount: learned,
    favoriteWordCount: favorites,
    completedQuizCount: quizzes,
    hasPerfectQuiz: perfect,
    currentStreak: streak,
  );
}

AchievementService _service({
  required _FakeAchievementStore store,
  required _MutableMetricsSource source,
}) {
  return AchievementService(
    repository: store,
    metricsLoader: source,
    now: () => DateTime.utc(2026, 7, 16, 12),
  );
}

void main() {
  test('Başarım kataloğu sabit 12 tanımı ve kimlikleri korur', () {
    expect(AchievementCatalog.achievements, hasLength(12));
    expect(AchievementCatalog.achievements.map((item) => item.id), [
      'first_step',
      'review_master',
      'learned_10',
      'learned_50',
      'learned_100',
      'favorites_5',
      'first_quiz',
      'perfect_quiz',
      'quiz_10',
      'streak_3',
      'streak_7',
      'streak_30',
    ]);
  });

  test('Başarım eşikleri bir alt değerde kapalı, hedefte açıktır', () {
    for (final achievement in AchievementCatalog.achievements) {
      AchievementMetrics at(int value) {
        return switch (achievement.type) {
          AchievementType.totalReviews => _metrics(reviews: value),
          AchievementType.learnedWords => _metrics(learned: value),
          AchievementType.favorites => _metrics(favorites: value),
          AchievementType.completedQuizzes => _metrics(quizzes: value),
          AchievementType.perfectQuiz => _metrics(perfect: value == 1),
          AchievementType.streak => _metrics(streak: value),
        };
      }

      expect(
        achievement.isMet(at(achievement.target - 1)),
        isFalse,
        reason: achievement.id,
      );
      expect(
        achievement.isMet(at(achievement.target)),
        isTrue,
        reason: achievement.id,
      );
    }
  });

  test('Yüzde 90 quiz kusursuz başarımını açmaz', () {
    final achievement = AchievementCatalog.findById('perfect_quiz')!;
    expect(achievement.isMet(_metrics(quizzes: 1, perfect: false)), isFalse);
    expect(achievement.isMet(_metrics(quizzes: 1, perfect: true)), isTrue);
  });

  test(
    'Tüm gerçek eşikler karşılandığında 12 başarım bir kez açılır',
    () async {
      final store = _FakeAchievementStore();
      final source = _MutableMetricsSource(
        _metrics(
          reviews: 10,
          learned: 100,
          favorites: 5,
          quizzes: 10,
          perfect: true,
          streak: 30,
        ),
      );
      final service = _service(store: store, source: source);

      final first = await service.evaluate();
      final second = await service.evaluate();

      expect(first, hasLength(12));
      expect(second, isEmpty);
      expect(store.records, hasLength(12));
      expect(store.unlockCalls, 12);
    },
  );

  test(
    'Sessiz başlangıç backfill yapar ve sonraki kontrolde bildirim üretmez',
    () async {
      final store = _FakeAchievementStore();
      final source = _MutableMetricsSource(
        _metrics(reviews: 1, learned: 10, favorites: 5, quizzes: 1),
      );
      final service = _service(store: store, source: source);

      await service.initialize();

      expect(service.unlockedCount, 4);
      expect(await service.evaluate(), isEmpty);
    },
  );

  test(
    'Açılan başarım yeniden oluşturulan serviste ve metrik düşünce korunur',
    () async {
      final store = _FakeAchievementStore();
      final source = _MutableMetricsSource(_metrics(streak: 7));
      final firstService = _service(store: store, source: source);
      await firstService.initialize();
      expect(firstService.isUnlocked('streak_3'), isTrue);
      expect(firstService.isUnlocked('streak_7'), isTrue);

      source.metrics = AchievementMetrics.empty;
      final restoredService = _service(store: store, source: source);
      await restoredService.initialize();

      expect(restoredService.isUnlocked('streak_3'), isTrue);
      expect(restoredService.isUnlocked('streak_7'), isTrue);
      expect(restoredService.unlockedCount, 2);
    },
  );

  test(
    'Yeni eylem yalnızca o anda ilk kez açılan başarımları döndürür',
    () async {
      final store = _FakeAchievementStore();
      final source = _MutableMetricsSource(AchievementMetrics.empty);
      final service = _service(store: store, source: source);
      await service.initialize();

      source.metrics = _metrics(reviews: 1);
      expect((await service.evaluate()).map((item) => item.id), ['first_step']);
      expect(await service.evaluate(), isEmpty);

      source.metrics = _metrics(reviews: 10);
      expect((await service.evaluate()).map((item) => item.id), [
        'review_master',
      ]);
    },
  );

  test('AchievementUnlock UTC ISO map dönüşümünü korur', () {
    final unlock = AchievementUnlock(
      achievementId: 'first_step',
      unlockedAt: DateTime.parse('2026-07-16T15:00:00+03:00'),
    );
    final map = unlock.toMap();
    final restored = AchievementUnlock.fromMap(map);

    expect(map['unlocked_at'], '2026-07-16T12:00:00.000Z');
    expect(restored.achievementId, 'first_step');
    expect(restored.unlockedAt.isUtc, isTrue);
  });

  testWidgets('Başarımlar ekranı 12 kart, gerçek ilerleme ve tarih gösterir', (
    tester,
  ) async {
    final unlockDate = DateTime.utc(2026, 7, 16);
    final store = _FakeAchievementStore([
      AchievementUnlock(achievementId: 'first_step', unlockedAt: unlockDate),
    ]);
    final source = _MutableMetricsSource(_metrics(reviews: 3));
    final service = _service(store: store, source: source);
    await service.initialize();

    await tester.pumpWidget(
      MaterialApp(home: AchievementsScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 / 12'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('achievement-first_step')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('achievement-review_master')),
      findsOneWidget,
    );
    expect(find.text('Kazanıldı • 16 Temmuz 2026'), findsOneWidget);
    expect(find.text('3 / 10'), findsOneWidget);
    expect(find.byType(GlassBackground), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is GlassSurface &&
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith('achievement-'),
      ),
      findsNWidgets(12),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Birden fazla yeni başarım bildirimi sırayla gösterilir', (
    tester,
  ) async {
    final achievements = AchievementCatalog.achievements.take(2).toList();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => unawaited(
                showAchievementNotifications(context, achievements),
              ),
              child: const Text('Başlat'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Başlat'));
    await tester.pumpAndSettle();
    expect(find.text('İlk Adım'), findsOneWidget);
    expect(find.text('Tekrar Ustası'), findsNothing);

    await tester.tap(find.text('Harika!'));
    await tester.pumpAndSettle();
    expect(find.text('İlk Adım'), findsNothing);
    expect(find.text('Tekrar Ustası'), findsOneWidget);

    await tester.tap(find.text('Harika!'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni başarım!'), findsNothing);
  });

  testWidgets('Başarımlar ekranı küçük genişlikte taşmaz', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    final service = _service(
      store: _FakeAchievementStore(),
      source: _MutableMetricsSource(_metrics(learned: 9)),
    );
    await service.initialize();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: AchievementsScreen(service: service),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
