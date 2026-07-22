import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/models/category_hub_snapshot.dart';
import 'package:kelimo/models/category_unlock.dart';
import 'package:kelimo/models/quiz_attempt.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/repositories/category_unlock_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/screens/category_selection_screen.dart';
import 'package:kelimo/screens/category_quiz_screen.dart';
import 'package:kelimo/screens/mosaic_screen.dart';
import 'package:kelimo/services/category_access_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/mosaic_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/theme/app_theme.dart';

class _UnlockMemoryStore implements CategoryUnlockStore {
  final Map<String, CategoryUnlock> values = {};

  @override
  Future<List<CategoryUnlock>> loadUnlocks() async => values.values.toList();

  @override
  Future<bool> unlock(CategoryUnlock unlock) async {
    if (values.containsKey(unlock.categoryId)) return false;
    values[unlock.categoryId] = unlock;
    return true;
  }

  @override
  Future<void> replaceWithDefaults(Iterable<CategoryUnlock> unlocks) async {
    values
      ..clear()
      ..addEntries(unlocks.map((item) => MapEntry(item.categoryId, item)));
  }
}

class _WordMemoryStore implements WordProgressStore {
  _WordMemoryStore([Map<String, WordProgress>? values]) : values = values ?? {};

  final Map<String, WordProgress> values;

  @override
  void clearCachedData() => values.clear();

  @override
  List<WordProgress> getAllProgress() => values.values.toList();

  @override
  Future<void> initialize() async {}

  @override
  WordProgress progressFor(String wordId) =>
      values[wordId] ?? WordProgress.initial(wordId);

  @override
  Future<void> resetProgress(String wordId) async => values.remove(wordId);

  @override
  Future<WordProgress> saveFavorite(String wordId, bool isFavorite) async {
    final next = progressFor(wordId).copyWith(isFavorite: isFavorite);
    values[wordId] = next;
    return next;
  }

  @override
  Future<WordProgress> saveLearningResult(
    LearningReviewResult result, {
    DateTime? reviewedAt,
  }) async {
    final next = wordProgressAfterLearningResult(
      progressFor(result.word.id),
      result,
      reviewedAt: reviewedAt,
    );
    values[result.word.id] = next;
    return next;
  }

  @override
  Future<void> saveProgress(WordProgress progress) async {
    values[progress.wordId] = progress;
  }
}

class _QuizMemoryStore implements QuizStore {
  final List<QuizAttempt> attempts = [];

  @override
  void clearCachedData() => attempts.clear();

  @override
  Future<List<QuizAttempt>> getAllAttempts() async => List.of(attempts);

  @override
  Future<List<QuizAttempt>> getAttemptsByCategory(String categoryId) async =>
      attempts.where((item) => item.categoryId == categoryId).toList();

  @override
  Future<int> getHighestScore(String categoryId) async => 0;

  @override
  Future<QuizStatistics> getStatistics() async => const QuizStatistics(
    totalQuizCount: 0,
    totalCorrectCount: 0,
    totalQuestionCount: 0,
    generalSuccessPercentage: 0,
    highestScoreByCategory: {},
  );

  @override
  Future<int> getTotalQuizCount() async => attempts.length;

  @override
  Future<QuizCompletion> saveCompletedQuiz({
    required String categoryId,
    required int correctCount,
    required int totalQuestions,
    required int scorePercent,
    DateTime? completedAt,
  }) {
    throw UnimplementedError();
  }
}

class _XpMemoryStore implements XpStore, XpAwardStore {
  _XpMemoryStore([this.total = 0]);

  int total;
  final Set<String> claims = {};

  @override
  int get currentTotalXp => total;

  @override
  Future<XpState> addXp(int amount) async {
    total += amount;
    return _state();
  }

  @override
  Future<XpState> awardWordReview({
    required String wordId,
    required LearningRating rating,
    required int amount,
    DateTime? awardedAt,
  }) async {
    final date = awardedAt ?? DateTime.now();
    final key = '$wordId:${date.year}-${date.month}-${date.day}';
    if (claims.add(key)) total += amount;
    return _state();
  }

  @override
  Future<XpState> loadState() async => _state();

  @override
  Future<void> resetXp() async => total = 0;

  @override
  void synchronizeState(XpState state) => total = state.totalXp;

  XpState _state() => XpState(totalXp: total, updatedAt: DateTime.now());
}

WordProgress _learned(String wordId) => WordProgress.initial(wordId).copyWith(
  mastery: 'easy',
  repetitionCount: 1,
  correctCount: 1,
  lastReviewedAt: DateTime.utc(2026, 7, 22),
);

Future<({CategoryAccessService access, XpService xp})> _access({
  int xp = 0,
  Map<String, WordProgress>? progress,
  List<QuizAttempt>? attempts,
}) async {
  final xpService = XpService(repository: _XpMemoryStore(xp));
  await xpService.initialize();
  final quiz = _QuizMemoryStore();
  if (attempts != null) quiz.attempts.addAll(attempts);
  final access = CategoryAccessService(
    repository: _UnlockMemoryStore(),
    wordProgressStore: _WordMemoryStore(progress),
    quizStore: quiz,
    xpService: xpService,
    now: () => DateTime.utc(2026, 7, 22),
  );
  await access.initialize();
  return (access: access, xp: xpService);
}

void main() {
  test('yeni kullanıcıda yalnızca altı başlangıç kategorisi açıktır', () async {
    final services = await _access();
    addTearDown(services.access.dispose);
    addTearDown(services.xp.dispose);

    expect(services.access.unlockedCategoryIds, initialUnlockedCategoryIds);
    expect(services.access.availableUnlockCredits, 0);
    expect(services.access.xpUntilNextCredit, 100);
  });

  test('XP eşikleri ve 700 sonrası döngü doğru hak üretir', () {
    expect(earnedCategoryUnlockCredits(99), 0);
    expect(earnedCategoryUnlockCredits(100), 1);
    expect(earnedCategoryUnlockCredits(250), 2);
    expect(earnedCategoryUnlockCredits(450), 3);
    expect(earnedCategoryUnlockCredits(700), 5);
    expect(earnedCategoryUnlockCredits(999), 5);
    expect(earnedCategoryUnlockCredits(1000), 7);
    expect(earnedCategoryUnlockCredits(1300), 9);
  });

  test('açma hakkı tüketilir ve aynı kategori iki kez açılamaz', () async {
    final services = await _access(xp: 100);
    addTearDown(services.access.dispose);
    addTearDown(services.xp.dispose);

    expect(await services.access.unlockCategory('technology'), isTrue);
    expect(services.access.availableUnlockCredits, 0);
    expect(await services.access.unlockCategory('technology'), isFalse);
    expect(services.access.isUnlocked('technology'), isTrue);
  });

  test('eski ilerleme ve quiz kategorileri hak tüketmeden açılır', () async {
    final services = await _access(
      progress: {
        CategoryCatalog.technology.words.first.id: _learned(
          CategoryCatalog.technology.words.first.id,
        ),
      },
      attempts: [
        QuizAttempt(
          categoryId: 'sports',
          correctCount: 8,
          totalQuestions: 10,
          scorePercent: 80,
          completedAt: DateTime.utc(2026, 7, 21),
          xpAwarded: 0,
        ),
      ],
    );
    addTearDown(services.access.dispose);
    addTearDown(services.xp.dispose);

    expect(services.access.isUnlocked('technology'), isTrue);
    expect(services.access.isUnlocked('sports'), isTrue);
    expect(services.access.manuallySpentCredits, 0);
  });

  test('reset yalnızca başlangıç kategorilerini açık bırakır', () async {
    final services = await _access(xp: 100);
    addTearDown(services.access.dispose);
    addTearDown(services.xp.dispose);
    await services.access.unlockCategory('technology');

    await services.access.resetAfterDataClear();

    expect(services.access.unlockedCategoryIds, initialUnlockedCategoryIds);
  });

  test('aynı kelimenin aynı gündeki tekrarları sınırsız XP üretmez', () async {
    final store = _XpMemoryStore();
    final service = XpService(repository: store);
    await service.initialize();
    addTearDown(service.dispose);
    final day = DateTime(2026, 7, 22, 10);

    await service.awardWordReview(
      wordId: 'animals_dog',
      rating: LearningRating.easy,
      awardedAt: day,
    );
    await service.awardWordReview(
      wordId: 'animals_dog',
      rating: LearningRating.easy,
      awardedAt: day.add(const Duration(hours: 2)),
    );

    expect(service.totalXp, 5);
  });

  test('mozaik deterministik eşleşir ve yalnızca öğrenilenleri açar', () {
    final firstWord = CategoryCatalog.categories.first.words.first;
    final store = _WordMemoryStore({
      firstWord.id: _learned(firstWord.id),
      CategoryCatalog.foods.words.first.id: WordProgress.initial(
        CategoryCatalog.foods.words.first.id,
      ).copyWith(isFavorite: true),
    });
    final first = MosaicService(wordProgressStore: store);
    final second = MosaicService(wordProgressStore: store);

    expect(first.wordMap.cellByWordId, second.wordMap.cellByWordId);
    expect(first.wordMap.cellByWordId.values.toSet(), hasLength(1080));
    expect(first.load().discoveredCount, 1);
  });

  test('1080 öğrenilen kelime mozaiği tamamlar', () {
    final records = <String, WordProgress>{
      for (final word in CategoryCatalog.categories.expand((c) => c.words))
        word.id: _learned(word.id),
    };
    final progress = MosaicService(
      wordProgressStore: _WordMemoryStore(records),
    ).load();

    expect(progress.discoveredCount, 1080);
    expect(progress.isComplete, isTrue);
  });

  testWidgets('kilitli kategori doğrudan açılmaz ve XP gereksinimi görünür', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final services = await _access();
    addTearDown(services.access.dispose);
    addTearDown(services.xp.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: CategorySelectionScreen(
            snapshot: const CategoryHubSnapshot(
              progressByCategoryId: {},
              recentCategories: [],
            ),
            categoryAccessService: services.access,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('category-grid-technology')),
      find.byType(CustomScrollView),
      const Offset(0, -500),
    );
    await tester.tap(find.byKey(const ValueKey('category-grid-technology')));
    await tester.pump();

    expect(find.text('Yeni kategori için 100 XP kaldı'), findsWidgets);
    expect(find.byType(CategorySelectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kilitli kategori quizine doğrudan navigasyon engellenir', (
    tester,
  ) async {
    final services = await _access();
    addTearDown(services.access.dispose);
    addTearDown(services.xp.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryQuizScreen(
          category: CategoryCatalog.technology,
          quizStore: _QuizMemoryStore(),
          xpService: services.xp,
          categoryAccessService: services.access,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Bu kategori henüz kilitli.'), findsOneWidget);
    expect(find.text('Teknoloji Quiz'), findsNothing);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Gizli Mozaik küçük ekranda taşmaz: $mode', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
            child: MosaicScreen(
              service: MosaicService(wordProgressStore: _WordMemoryStore()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 / 1080 parça keşfedildi'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('knowledge-garden-mosaic')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
