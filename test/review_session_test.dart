import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/models/review_session.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/repositories/settings_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/screens/learning_word_list_screen.dart';
import 'package:kelimo/screens/review_session_screen.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/review_session_builder.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class _ReviewWordStore implements WordProgressStore {
  _ReviewWordStore({
    Map<String, WordProgress>? values,
    this.now,
    this.onInitialize,
    this.failLearningSave = false,
  }) : values = values ?? {};

  final Map<String, WordProgress> values;
  final DateTime? now;
  final VoidCallback? onInitialize;
  final bool failLearningSave;
  int initializeCount = 0;
  int learningSaveCount = 0;
  int favoriteSaveCount = 0;

  @override
  void clearCachedData() => values.clear();

  @override
  List<WordProgress> getAllProgress() => List.unmodifiable(values.values);

  @override
  Future<void> initialize() async {
    initializeCount++;
    onInitialize?.call();
  }

  @override
  WordProgress progressFor(String wordId) =>
      values[wordId] ?? WordProgress.initial(wordId, now: now);

  @override
  Future<void> resetProgress(String wordId) async => values.remove(wordId);

  @override
  Future<WordProgress> saveFavorite(String wordId, bool isFavorite) async {
    favoriteSaveCount++;
    final progress = progressFor(
      wordId,
    ).copyWith(isFavorite: isFavorite, updatedAt: now);
    values[wordId] = progress;
    return progress;
  }

  @override
  Future<WordProgress> saveLearningResult(
    LearningReviewResult result, {
    DateTime? reviewedAt,
  }) async {
    learningSaveCount++;
    if (failLearningSave) throw StateError('save failed');
    final progress = wordProgressAfterLearningResult(
      progressFor(result.word.id),
      result,
      reviewedAt: reviewedAt ?? now,
    );
    values[result.word.id] = progress;
    return progress;
  }

  @override
  Future<void> saveProgress(WordProgress progress) async {
    values[progress.wordId] = progress;
  }
}

class _ReviewXpStore implements XpStore {
  XpState state = XpState.initial();

  @override
  int get currentTotalXp => state.totalXp;

  @override
  Future<XpState> addXp(int amount) async {
    state = XpState(totalXp: state.totalXp + amount, updatedAt: DateTime.now());
    return state;
  }

  @override
  Future<XpState> loadState() async => state;

  @override
  Future<void> resetXp() async => state = XpState.initial();

  @override
  void synchronizeState(XpState state) => this.state = state;
}

class _ReviewSettingsStore implements SettingsStore {
  AppSettings settings = AppSettings.defaults;

  @override
  Future<AppSettings> load() async => settings;

  @override
  Future<void> resetToDefaults() async => settings = AppSettings.defaults;

  @override
  Future<int> resolveDailyGoalForDate({
    required String dateKey,
    required int selectedDailyGoal,
  }) async => selectedDailyGoal;

  @override
  Future<void> setDailyGoal(int dailyGoal) async {
    settings = settings.copyWith(dailyGoal: dailyGoal);
  }

  @override
  Future<void> setSpeechRate(SpeechRatePreference speechRate) async {
    settings = settings.copyWith(speechRate: speechRate);
  }
}

class _ReviewTtsEngine implements TtsEngine {
  double? rate;
  final spoken = <String>[];

  @override
  Future<void> configure({
    required String language,
    required double speechRate,
    required double volume,
    required double pitch,
  }) async => rate = speechRate;

  @override
  Future<bool> speak(String text) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}
}

WordProgress _dueProgress(
  String wordId,
  DateTime nextReviewAt, {
  bool favorite = false,
}) {
  return WordProgress(
    wordId: wordId,
    isFavorite: favorite,
    mastery: 'again',
    repetitionCount: 1,
    correctCount: 0,
    wrongCount: 1,
    lastReviewedAt: nextReviewAt,
    nextReviewAt: nextReviewAt,
    updatedAt: nextReviewAt,
  );
}

ReviewSessionItem _item(String categoryId, int wordIndex, DateTime dueAt) {
  final category = CategoryCatalog.findById(categoryId)!;
  return ReviewSessionItem(
    category: category,
    word: category.words[wordIndex],
    nextReviewAt: dueAt,
  );
}

Future<({SettingsService settings, XpService xp})> _services({
  SpeechRatePreference speechRate = SpeechRatePreference.normal,
}) async {
  final settings = SettingsService(repository: _ReviewSettingsStore());
  await settings.initialize();
  await settings.setSpeechRate(speechRate);
  final xp = XpService(repository: _ReviewXpStore());
  await xp.initialize();
  return (settings: settings, xp: xp);
}

Future<void> _pumpSession(
  WidgetTester tester, {
  required List<ReviewSessionItem> items,
  required _ReviewWordStore wordStore,
  required ReviewSessionBuilder builder,
  required SettingsService settings,
  required XpService xp,
  required StreakService streak,
  EnglishTtsService? tts,
  Size size = const Size(430, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ReviewSessionScreen(
        initialItems: items,
        sessionBuilder: builder,
        wordProgressStore: wordStore,
        streakService: streak,
        xpService: xp,
        settingsService: settings,
        ttsService: tts,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.utc(2026, 7, 16, 10);

  group('ReviewSessionBuilder', () {
    test('yalnızca vadesi gelen benzersiz kelimeleri sıralar', () async {
      final oldest = now.subtract(const Duration(days: 2));
      final tied = now.subtract(const Duration(days: 1));
      final store = _ReviewWordStore(
        values: {
          'foods_apple': _dueProgress('foods_apple', tied, favorite: true),
          'cat': _dueProgress('cat', tied),
          'dog': _dueProgress('dog', oldest),
          'colors_red': _dueProgress(
            'colors_red',
            now.add(const Duration(minutes: 1)),
          ),
          'home_house': WordProgress.initial('home_house', now: now),
        },
      );
      final items = await ReviewSessionBuilder(
        wordProgressStore: store,
        now: () => now,
      ).build();

      expect(items.map((item) => '${item.category.id}:${item.word.id}'), [
        'animals:dog',
        'animals:cat',
        'foods:foods_apple',
      ]);
      expect(
        items.map((item) => item.word.id).toSet(),
        hasLength(items.length),
      );
      expect(store.initializeCount, 1);
    });

    test('eşit tarihte kategori ve özgün kelime sırasını korur', () async {
      final store = _ReviewWordStore(
        values: {
          'bird': _dueProgress('bird', now),
          'dog': _dueProgress('dog', now),
          'foods_banana': _dueProgress('foods_banana', now),
          'foods_apple': _dueProgress('foods_apple', now),
        },
      );
      final items = await ReviewSessionBuilder(
        wordProgressStore: store,
        now: () => now,
      ).build();

      expect(items.map((item) => item.word.id), [
        'dog',
        'bird',
        'foods_apple',
        'foods_banana',
      ]);
    });

    test('başlangıçta repository verisini yeniden yükler', () async {
      late _ReviewWordStore store;
      store = _ReviewWordStore(
        values: {},
        onInitialize: () {
          store.values['dog'] = _dueProgress('dog', now);
        },
      );
      final items = await ReviewSessionBuilder(
        wordProgressStore: store,
        now: () => now,
      ).build();

      expect(items.single.word.id, 'dog');
      expect(store.initializeCount, 1);
    });

    test(
      'başlangıç snapshotı sonradan vadesi gelen kelimelerle değişmez',
      () async {
        final store = _ReviewWordStore(
          values: {'dog': _dueProgress('dog', now)},
        );
        final items = await ReviewSessionBuilder(
          wordProgressStore: store,
          now: () => now,
        ).build();
        store.values['foods_apple'] = _dueProgress('foods_apple', now);

        expect(items.map((item) => item.word.id), ['dog']);
      },
    );
  });

  testWidgets('Tekrar Bekleyenler listesi oturum başlatma durumunu gösterir', (
    tester,
  ) async {
    final store = _ReviewWordStore(
      now: now,
      values: {'dog': _dueProgress('dog', now)},
    );
    final services = await _services();
    addTearDown(services.settings.dispose);
    addTearDown(services.xp.dispose);
    final streak = StreakService();
    addTearDown(streak.dispose);
    final sessionBuilder = ReviewSessionBuilder(
      wordProgressStore: store,
      now: () => now,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LearningWordListScreen(
          filter: LearningCenterFilter.repeatPending,
          service: LearningCenterService(
            wordProgressStore: store,
            now: () => now,
          ),
          wordProgressStore: store,
          streakService: streak,
          xpService: services.xp,
          settingsService: services.settings,
          sessionBuilder: sessionBuilder,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 kelimeyi çalış'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-review-session')));
    await tester.pumpAndSettle();
    expect(find.byType(ReviewSessionScreen), findsOneWidget);
    expect(find.text('DOG'), findsOneWidget);
    expect(store.initializeCount, 1);
  });

  testWidgets('bekleyen yoksa başlatma butonu yerine boş durum görünür', (
    tester,
  ) async {
    final store = _ReviewWordStore(now: now);
    final services = await _services();
    addTearDown(services.settings.dispose);
    addTearDown(services.xp.dispose);
    final streak = StreakService();
    addTearDown(streak.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: LearningWordListScreen(
          filter: LearningCenterFilter.repeatPending,
          service: LearningCenterService(
            wordProgressStore: store,
            now: () => now,
          ),
          wordProgressStore: store,
          streakService: streak,
          xpService: services.xp,
          settingsService: services.settings,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tekrar bekleyen kelimen yok.'), findsOneWidget);
    expect(find.byKey(const ValueKey('start-review-session')), findsNothing);
  });

  testWidgets(
    'farklı kategorileri gösterir ve değerlendirmeleri bir kez kaydeder',
    (tester) async {
      final items = [_item('animals', 0, now), _item('foods', 0, now)];
      final store = _ReviewWordStore(
        now: now,
        values: {
          'dog': _dueProgress('dog', now),
          'foods_apple': _dueProgress('foods_apple', now),
        },
      );
      final builder = ReviewSessionBuilder(
        wordProgressStore: store,
        now: () => now,
      );
      final services = await _services(speechRate: SpeechRatePreference.fast);
      addTearDown(services.settings.dispose);
      addTearDown(services.xp.dispose);
      final streak = StreakService();
      addTearDown(streak.dispose);
      final ttsEngine = _ReviewTtsEngine();
      final tts = EnglishTtsService(
        engine: ttsEngine,
        settingsService: services.settings,
      );
      addTearDown(tts.dispose);

      await _pumpSession(
        tester,
        items: items,
        wordStore: store,
        builder: builder,
        settings: services.settings,
        xp: services.xp,
        streak: streak,
        tts: tts,
      );

      expect(find.text('Tekrar Oturumu'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Hayvanlar'), findsOneWidget);
      expect(find.text('DOG'), findsOneWidget);
      await tester.tap(find.text('Dinle'));
      await tester.pumpAndSettle();
      expect(ttsEngine.spoken, ['Dog']);
      expect(ttsEngine.rate, SpeechRatePreference.fast.ttsRate);

      await tester.tap(find.text('Favori'));
      await tester.pumpAndSettle();
      expect(store.favoriteSaveCount, 1);
      expect(store.learningSaveCount, 0);
      expect(find.text('1 / 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('word-card')));
      await tester.pumpAndSettle();
      expect(find.text('KÖPEK'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('learning-rating-easy')));
      await tester.tap(find.byKey(const ValueKey('learning-rating-easy')));
      await tester.pumpAndSettle();
      expect(store.learningSaveCount, 1);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Yiyecekler'), findsOneWidget);
      expect(find.text('APPLE'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('learning-rating-again')));
      await tester.pumpAndSettle();
      expect(store.learningSaveCount, 2);
      expect(find.text('Tekrar tamamlandı!'), findsOneWidget);
      expect(find.text('Çalışılan kelime'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('review-result-total')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('review-result-easy')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('review-result-again')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('review-result-hard')),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('review-result-daily')),
          matching: find.text('2 / 5'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('review-restart-pending')),
        findsOneWidget,
      );
      expect(store.progressFor('foods_apple').nextReviewAt, now);
      expect(store.progressFor('dog').nextReviewAt!.isAfter(now), isTrue);

      await tester.tap(find.byKey(const ValueKey('review-restart-pending')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('APPLE'), findsOneWidget);
      expect(store.learningSaveCount, 2);
    },
  );

  testWidgets('kayıt hatası ve hızlı çift dokunma ilerlemeyi çoğaltmaz', (
    tester,
  ) async {
    final item = _item('animals', 0, now);
    final store = _ReviewWordStore(
      now: now,
      values: {'dog': _dueProgress('dog', now)},
      failLearningSave: true,
    );
    final services = await _services();
    addTearDown(services.settings.dispose);
    addTearDown(services.xp.dispose);
    final streak = StreakService();
    addTearDown(streak.dispose);
    await _pumpSession(
      tester,
      items: [item],
      wordStore: store,
      builder: ReviewSessionBuilder(wordProgressStore: store, now: () => now),
      settings: services.settings,
      xp: services.xp,
      streak: streak,
    );

    await tester.tap(find.byKey(const ValueKey('learning-rating-hard')));
    await tester.tap(find.byKey(const ValueKey('learning-rating-hard')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(store.learningSaveCount, 1);
    expect(streak.todayCount, 0);
    expect(find.text('DOG'), findsOneWidget);
    expect(find.text('İlerleme kaydedilemedi'), findsOneWidget);
  });

  testWidgets('erken çıkış diyaloğu kalan kelimeleri korur', (tester) async {
    final items = [_item('animals', 0, now), _item('foods', 0, now)];
    final store = _ReviewWordStore(
      now: now,
      values: {
        'dog': _dueProgress('dog', now),
        'foods_apple': _dueProgress('foods_apple', now),
      },
    );
    final services = await _services();
    addTearDown(services.settings.dispose);
    addTearDown(services.xp.dispose);
    final streak = StreakService();
    addTearDown(streak.dispose);
    await _pumpSession(
      tester,
      items: items,
      wordStore: store,
      builder: ReviewSessionBuilder(wordProgressStore: store, now: () => now),
      settings: services.settings,
      xp: services.xp,
      streak: streak,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('learning-rating-hard')),
    );
    await tester.tap(find.byKey(const ValueKey('learning-rating-hard')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(store.learningSaveCount, 1);
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('Oturumdan çıkılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Devam Et'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(ReviewSessionScreen), findsOneWidget);

    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.text('Çık'), findsOneWidget);
    await tester.tap(find.text('Çık'));
    await tester.pumpAndSettle();
    expect(store.learningSaveCount, 1);
    expect(
      store.progressFor('dog').nextReviewAt,
      now.add(const Duration(days: 1)),
    );
    expect(store.progressFor('foods_apple').nextReviewAt, now);
  });

  testWidgets('bekleyen kalmadığında tekrar başlatma göstermez ve taşmaz', (
    tester,
  ) async {
    final item = _item('transportation', 12, now);
    final wordId = item.word.id;
    final store = _ReviewWordStore(
      now: now,
      values: {wordId: _dueProgress(wordId, now)},
    );
    final services = await _services();
    addTearDown(services.settings.dispose);
    addTearDown(services.xp.dispose);
    final streak = StreakService(dailyGoal: 1);
    addTearDown(streak.dispose);
    await _pumpSession(
      tester,
      items: [item],
      wordStore: store,
      builder: ReviewSessionBuilder(wordProgressStore: store, now: () => now),
      settings: services.settings,
      xp: services.xp,
      streak: streak,
      size: const Size(320, 640),
    );

    expect(find.text('HELICOPTER'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey('learning-rating-easy')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learning-rating-easy')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(store.learningSaveCount, 1);
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar tamamlandı!'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('🔥 Günlük hedef tamamlandı!'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-restart-pending')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
