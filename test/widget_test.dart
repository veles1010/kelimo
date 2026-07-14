import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/main.dart';
import 'package:kelimo/models/daily_progress.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/models/quiz_attempt.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/repositories/daily_progress_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/screens/quiz_result_screen.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/screens/word_card_screen.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/utils/turkish_case.dart';

class FakeTtsEngine implements TtsEngine {
  String? language;
  double? speechRate;
  double? volume;
  double? pitch;
  final spokenTexts = <String>[];
  int stopCallCount = 0;
  Completer<bool>? speakCompleter;
  bool failOnSpeak = false;

  @override
  Future<void> configure({
    required String language,
    required double speechRate,
    required double volume,
    required double pitch,
  }) async {
    this.language = language;
    this.speechRate = speechRate;
    this.volume = volume;
    this.pitch = pitch;
  }

  @override
  Future<bool> speak(String text) {
    spokenTexts.add(text);
    if (failOnSpeak) throw StateError('TTS unavailable');
    return speakCompleter?.future ?? Future.value(true);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }
}

class FakeWordProgressStore implements WordProgressStore {
  FakeWordProgressStore([Map<String, WordProgress>? records])
    : records = records ?? {};

  final Map<String, WordProgress> records;

  @override
  Future<void> initialize() async {}

  @override
  List<WordProgress> getAllProgress() => List.unmodifiable(records.values);

  @override
  WordProgress progressFor(String wordId) {
    return records[wordId] ?? WordProgress.initial(wordId);
  }

  @override
  Future<void> saveProgress(WordProgress progress) async {
    records[progress.wordId] = progress;
  }

  @override
  Future<WordProgress> saveFavorite(String wordId, bool isFavorite) async {
    final progress = progressFor(
      wordId,
    ).copyWith(isFavorite: isFavorite, updatedAt: DateTime.now());
    await saveProgress(progress);
    return progress;
  }

  @override
  Future<WordProgress> saveLearningResult(
    LearningReviewResult result, {
    DateTime? reviewedAt,
  }) async {
    final current = progressFor(result.word.id);
    final progress = wordProgressAfterLearningResult(
      current,
      result,
      reviewedAt: reviewedAt,
    );
    await saveProgress(progress);
    return progress;
  }

  @override
  Future<void> resetProgress(String wordId) async {
    records.remove(wordId);
  }
}

WordProgress testWordProgress({
  required String wordId,
  String mastery = 'new',
  int repetitionCount = 0,
  bool isFavorite = false,
}) {
  final now = DateTime.parse('2026-07-14T12:00:00.000');
  return WordProgress(
    wordId: wordId,
    isFavorite: isFavorite,
    mastery: mastery,
    repetitionCount: repetitionCount,
    correctCount: mastery == 'easy' ? 1 : 0,
    wrongCount: mastery == 'again' || mastery == 'hard' ? 1 : 0,
    lastReviewedAt: repetitionCount > 0 ? now : null,
    nextReviewAt: null,
    updatedAt: now,
  );
}

class FakeDailyStorage {
  final Map<String, DailyProgress> dailyProgress = {};
  StreakState streak = const StreakState(currentStreak: 7);
}

class FakeDailyProgressStore implements DailyProgressStore {
  FakeDailyProgressStore([FakeDailyStorage? storage])
    : storage = storage ?? FakeDailyStorage();

  final FakeDailyStorage storage;

  @override
  Future<DailyProgressSnapshot> loadToday({
    int initialStreak = 7,
    DateTime? now,
  }) async {
    final dateKey = localDateKey(now ?? DateTime.now());
    return DailyProgressSnapshot(
      progress:
          storage.dailyProgress[dateKey] ?? DailyProgress.initial(dateKey),
      streak: storage.streak,
    );
  }

  @override
  Future<DailyProgressSnapshot> incrementReview({
    required int dailyGoal,
    int initialStreak = 7,
    DateTime? now,
  }) async {
    final date = (now ?? DateTime.now()).toLocal();
    final dateKey = localDateKey(date);
    final current =
        storage.dailyProgress[dateKey] ?? DailyProgress.initial(dateKey);
    final reviewCount = current.reviewCount + 1;
    final justCompleted = !current.isGoalCompleted && reviewCount >= dailyGoal;
    final progress = DailyProgress(
      dateKey: dateKey,
      reviewCount: reviewCount,
      isGoalCompleted: current.isGoalCompleted || justCompleted,
      streakAwarded: current.streakAwarded || justCompleted,
    );
    storage.dailyProgress[dateKey] = progress;
    if (justCompleted) {
      storage.streak = StreakState(
        currentStreak: storage.streak.currentStreak + 1,
        lastCompletedDate: DateTime(date.year, date.month, date.day),
      );
    }
    return DailyProgressSnapshot(
      progress: progress,
      streak: storage.streak,
      justCompleted: justCompleted,
    );
  }

  @override
  Future<void> saveStreak(StreakState streak) async {
    storage.streak = streak;
  }
}

class FakeXpStorage {
  FakeXpStorage({int totalXp = 0})
    : state = XpState(totalXp: totalXp, updatedAt: DateTime.now());

  XpState state;
}

class FakeXpStore implements XpStore {
  FakeXpStore([FakeXpStorage? storage]) : storage = storage ?? FakeXpStorage();

  final FakeXpStorage storage;

  @override
  int get currentTotalXp => storage.state.totalXp;

  @override
  void synchronizeState(XpState state) {
    storage.state = state;
  }

  @override
  Future<XpState> loadState() async => storage.state;

  @override
  Future<XpState> addXp(int amount) async {
    if (amount <= 0) throw ArgumentError.value(amount);
    storage.state = XpState(
      totalXp: storage.state.totalXp + amount,
      updatedAt: DateTime.now(),
    );
    return storage.state;
  }

  @override
  Future<void> resetXp() async {
    storage.state = XpState.initial();
  }
}

class FakeQuizStorage {
  final List<QuizAttempt> attempts = [];
  int nextId = 1;
}

class FakeQuizStore implements QuizStore {
  FakeQuizStore(this.storage, this.xpStorage);

  final FakeQuizStorage storage;
  final FakeXpStorage xpStorage;

  @override
  Future<QuizCompletion> saveCompletedQuiz({
    required String categoryId,
    required int correctCount,
    required int totalQuestions,
    required int scorePercent,
    DateTime? completedAt,
  }) async {
    final xpAwarded = quizXpForScore(scorePercent);
    final attempt = QuizAttempt(
      id: storage.nextId++,
      categoryId: categoryId,
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      scorePercent: scorePercent,
      completedAt: completedAt ?? DateTime.now(),
      xpAwarded: xpAwarded,
    );
    final xpState = XpState(
      totalXp: xpStorage.state.totalXp + xpAwarded,
      updatedAt: DateTime.now(),
    );
    storage.attempts.add(attempt);
    xpStorage.state = xpState;
    return QuizCompletion(attempt: attempt, xpState: xpState);
  }

  @override
  Future<List<QuizAttempt>> getAllAttempts() async {
    return List.unmodifiable(storage.attempts.reversed);
  }

  @override
  Future<List<QuizAttempt>> getAttemptsByCategory(String categoryId) async {
    return storage.attempts
        .where((attempt) => attempt.categoryId == categoryId)
        .toList()
        .reversed
        .toList(growable: false);
  }

  @override
  Future<int> getHighestScore(String categoryId) async {
    final scores = storage.attempts
        .where((attempt) => attempt.categoryId == categoryId)
        .map((attempt) => attempt.scorePercent);
    return scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
  }

  @override
  Future<int> getTotalQuizCount() async => storage.attempts.length;

  @override
  Future<QuizStatistics> getStatistics() async {
    final totalCorrect = storage.attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.correctCount,
    );
    final totalQuestions = storage.attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.totalQuestions,
    );
    final categories = storage.attempts
        .map((attempt) => attempt.categoryId)
        .toSet();
    return QuizStatistics(
      totalQuizCount: storage.attempts.length,
      totalCorrectCount: totalCorrect,
      totalQuestionCount: totalQuestions,
      generalSuccessPercentage: totalQuestions == 0
          ? 0
          : ((totalCorrect / totalQuestions) * 100).round(),
      highestScoreByCategory: {
        for (final category in categories)
          category: await getHighestScore(category),
      },
    );
  }
}

Future<XpService> createXpService({
  int totalXp = 0,
  XpStore? repository,
}) async {
  final service = XpService(
    repository: repository ?? FakeXpStore(FakeXpStorage(totalXp: totalXp)),
  );
  await service.initialize();
  return service;
}

StatisticsService createStatisticsService({
  required StreakService streakService,
  required XpService xpService,
  WordProgressStore? wordProgressStore,
  QuizStore? quizStore,
}) {
  return StatisticsService(
    wordProgressStore: wordProgressStore ?? FakeWordProgressStore(),
    quizStore: quizStore ?? FakeQuizStore(FakeQuizStorage(), FakeXpStorage()),
    streakService: streakService,
    xpService: xpService,
  );
}

Future<void> pumpKelimoApp(
  WidgetTester tester, {
  FakeXpStorage? xpStorage,
  FakeQuizStorage? quizStorage,
  WordProgressStore? wordProgressStore,
}) async {
  final sharedXpStorage = xpStorage ?? FakeXpStorage();
  await tester.pumpWidget(
    KelimoApp(
      wordProgressStore: wordProgressStore ?? FakeWordProgressStore(),
      dailyProgressStore: FakeDailyProgressStore(),
      xpStore: FakeXpStore(sharedXpStorage),
      quizStore: FakeQuizStore(
        quizStorage ?? FakeQuizStorage(),
        sharedXpStorage,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openAnimalsCategory(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Hayvanlar'), 300);
  await tester.tap(find.text('Hayvanlar'));
  await tester.pumpAndSettle();
}

Future<void> pumpLearningSession(WidgetTester tester) async {
  final service = EnglishTtsService(engine: FakeTtsEngine());
  final xpService = await createXpService();
  await tester.pumpWidget(
    MaterialApp(
      home: WordCardScreen(
        wordProgressStore: FakeWordProgressStore(),
        xpService: xpService,
        ttsService: service,
      ),
    ),
  );
  await tester.ensureVisible(find.text('Kolay'));
  await tester.pumpAndSettle();
}

Future<void> selectLearningRating(WidgetTester tester, String rating) async {
  await tester.ensureVisible(find.text(rating));
  await tester.tap(find.text(rating));
  await tester.pumpAndSettle();
}

Future<void> completeQuiz(WidgetTester tester, {bool perfect = true}) async {
  for (var index = 0; index < 10; index++) {
    final answer = !perfect && index == 0
        ? animalWords[1].turkish
        : animalWords[index].turkish;
    final option = find.byKey(ValueKey('quiz-option-$answer'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pump();

    final buttonLabel = index == 9 ? 'Sonucu Gör' : 'Sonraki Soru';
    await tester.ensureVisible(find.text(buttonLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(buttonLabel));
    await tester.pumpAndSettle();
  }
}

void main() {
  test('LearningEngine sonraki ve önceki kelimeyi yönetir', () {
    final engine = LearningEngine(animalWords);

    expect(engine.currentWord.english, 'Dog');
    expect(engine.canPrevious, isFalse);
    expect(engine.nextWord().english, 'Cat');
    expect(engine.canPrevious, isTrue);
    expect(engine.previousWord().english, 'Dog');
  });

  test('LearningEngine Kolay kelimeyi dokuz kart sonra getirir', () {
    final engine = LearningEngine(animalWords);

    expect(engine.rateEasy().english, 'Cat');
    for (final english in [
      'Bird',
      'Fish',
      'Horse',
      'Cow',
      'Sheep',
      'Goat',
      'Duck',
      'Chicken',
      'Dog',
    ]) {
      expect(engine.rateEasy().english, english);
    }
  });

  test('LearningEngine Tekrar Et kelimesini iki kart sonra getirir', () {
    final engine = LearningEngine(animalWords);

    expect(engine.rateAgain().english, 'Cat');
    expect(engine.rateEasy().english, 'Bird');
    expect(engine.rateEasy().english, 'Dog');
  });

  test('LearningEngine Zor kelimeyi bir kart sonra getirir', () {
    final engine = LearningEngine(animalWords);

    expect(engine.rateHard().english, 'Cat');
    expect(engine.rateEasy().english, 'Dog');
  });

  test('LearningEngine yalnızca tüm kelimeler Kolay olunca tamamlanır', () {
    final engine = LearningEngine(animalWords);
    Word? previousWord;
    var evaluationCount = 0;

    while (!engine.isComplete && evaluationCount < 100) {
      expect(engine.currentWord, isNot(same(previousWord)));
      previousWord = engine.currentWord;
      engine.rateEasy();
      evaluationCount++;
    }

    expect(engine.isComplete, isTrue);
    expect(evaluationCount, 48);
    expect(engine.canNext, isFalse);
    expect(engine.canPrevious, isFalse);
  });

  test('Word progress toMap ve fromMap değerleri korur', () {
    final reviewedAt = DateTime.parse('2026-07-14T10:30:00.000');
    final nextReviewAt = DateTime.parse('2026-07-15T10:30:00.000');
    final progress = WordProgress(
      wordId: 'dog',
      isFavorite: true,
      mastery: 'hard',
      repetitionCount: 3,
      correctCount: 1,
      wrongCount: 2,
      lastReviewedAt: reviewedAt,
      nextReviewAt: nextReviewAt,
      updatedAt: reviewedAt,
    );

    final restored = WordProgress.fromMap(progress.toMap());

    expect(restored.wordId, 'dog');
    expect(restored.isFavorite, isTrue);
    expect(restored.mastery, 'hard');
    expect(restored.repetitionCount, 3);
    expect(restored.correctCount, 1);
    expect(restored.wrongCount, 2);
    expect(restored.lastReviewedAt, reviewedAt);
    expect(restored.nextReviewAt, nextReviewAt);
    expect(restored.updatedAt, reviewedAt);
    expect(progress.toMap()['is_favorite'], 1);
  });

  test('Günlük progress mapping bool değerlerini 0 ve 1 olarak saklar', () {
    const progress = DailyProgress(
      dateKey: '2026-07-14',
      reviewCount: 5,
      isGoalCompleted: true,
      streakAwarded: true,
    );

    final map = progress.toMap();
    final restored = DailyProgress.fromMap(map);

    expect(map['is_goal_completed'], 1);
    expect(map['streak_awarded'], 1);
    expect(restored.dateKey, '2026-07-14');
    expect(restored.reviewCount, 5);
    expect(restored.isGoalCompleted, isTrue);
    expect(restored.streakAwarded, isTrue);
  });

  test('XP modeli değerlerini SQLite map dönüşümünde korur', () {
    final updatedAt = DateTime.parse('2026-07-14T12:00:00.000');
    final state = XpState(totalXp: 1005, updatedAt: updatedAt);

    final restored = XpState.fromMap(state.toMap());

    expect(state.toMap()['id'], 1);
    expect(restored.totalXp, 1005);
    expect(restored.updatedAt, updatedAt);
  });

  test('Veritabanı şema sürümü quiz migration ile 3 olur', () {
    expect(DatabaseService.databaseVersion, 3);
  });

  test('QuizAttempt SQLite map dönüşümünde sonuç ve tarihi korur', () {
    final completedAt = DateTime.parse('2026-07-14T15:30:00.000');
    final attempt = QuizAttempt(
      id: 4,
      categoryId: 'animals',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
      completedAt: completedAt,
      xpAwarded: 25,
    );

    final restored = QuizAttempt.fromMap(attempt.toMap());

    expect(restored.id, 4);
    expect(restored.categoryId, 'animals');
    expect(restored.correctCount, 10);
    expect(restored.totalQuestions, 10);
    expect(restored.scorePercent, 100);
    expect(restored.completedAt, completedAt);
    expect(restored.xpAwarded, 25);
  });

  test('Kusursuz quiz +25 XP verir ve düşük sonuç XP vermez', () async {
    final xpStorage = FakeXpStorage(totalXp: 250);
    final quizStorage = FakeQuizStorage();
    final repository = FakeQuizStore(quizStorage, xpStorage);

    final perfect = await repository.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );
    final lowerScore = await repository.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 9,
      totalQuestions: 10,
      scorePercent: 90,
    );

    expect(perfect.attempt.xpAwarded, 25);
    expect(perfect.xpState.totalXp, 275);
    expect(lowerScore.attempt.xpAwarded, 0);
    expect(lowerScore.xpState.totalXp, 275);
    expect(quizStorage.attempts, hasLength(2));
    expect(quizStorage.attempts.last.scorePercent, 90);
  });

  test(
    'Quiz istatistik altyapısı toplamları ve en yüksek skoru hesaplar',
    () async {
      final repository = FakeQuizStore(FakeQuizStorage(), FakeXpStorage());
      await repository.saveCompletedQuiz(
        categoryId: 'animals',
        correctCount: 10,
        totalQuestions: 10,
        scorePercent: 100,
      );
      await repository.saveCompletedQuiz(
        categoryId: 'animals',
        correctCount: 7,
        totalQuestions: 10,
        scorePercent: 70,
      );
      await repository.saveCompletedQuiz(
        categoryId: 'foods',
        correctCount: 5,
        totalQuestions: 10,
        scorePercent: 50,
      );

      final statistics = await repository.getStatistics();

      expect(await repository.getTotalQuizCount(), 3);
      expect(await repository.getAllAttempts(), hasLength(3));
      expect(await repository.getHighestScore('animals'), 100);
      expect(await repository.getAttemptsByCategory('animals'), hasLength(2));
      expect(statistics.totalQuizCount, 3);
      expect(statistics.totalCorrectCount, 22);
      expect(statistics.totalQuestionCount, 30);
      expect(statistics.generalSuccessPercentage, 73);
      expect(statistics.highestScoreByCategory, {'animals': 100, 'foods': 50});
    },
  );

  test('Aynı kusursuz quiz tekrar tamamlanınca yeniden 25 XP verir', () async {
    final xpStorage = FakeXpStorage();
    final repository = FakeQuizStore(FakeQuizStorage(), xpStorage);

    await repository.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );
    await repository.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );

    expect(xpStorage.state.totalXp, 50);
    expect(await repository.getTotalQuizCount(), 2);
  });

  test('Flashcard değerlendirmeleri doğru XP ödülünü üretir', () {
    expect(xpRewardForRating(LearningRating.easy), 5);
    expect(xpRewardForRating(LearningRating.again), 2);
    expect(xpRewardForRating(LearningRating.hard), 3);
  });

  test('XP servisi seviye sınırlarını ve progress değerini hesaplar', () async {
    final service = await createXpService();
    addTearDown(service.dispose);

    expect(service.totalXp, 0);
    expect(service.currentLevel, 1);
    expect(service.xpInCurrentLevel, 0);
    expect(service.xpRequiredForNextLevel, 1000);
    expect(service.progress, 0.0);
    expect(service.isLoading, isFalse);

    expect(await service.addXp(999), isTrue);
    expect(service.currentLevel, 1);
    expect(service.xpInCurrentLevel, 999);
    expect(service.progress, 0.999);

    expect(await service.addXp(1), isTrue);
    expect(service.totalXp, 1000);
    expect(service.currentLevel, 2);
    expect(service.xpInCurrentLevel, 0);
    expect(service.progress, 0.0);

    expect(await service.addXp(5), isTrue);
    expect(service.totalXp, 1005);
    expect(service.currentLevel, 2);
    expect(service.xpInCurrentLevel, 5);
    expect(service.progress, 0.005);
  });

  test('XP repository kaydı servis yeniden oluşturulunca yüklenir', () async {
    final storage = FakeXpStorage();
    final repository = FakeXpStore(storage);
    final firstService = await createXpService(repository: repository);

    expect(await firstService.addXp(5), isTrue);
    expect(repository.currentTotalXp, 5);
    firstService.dispose();

    final recreatedService = await createXpService(
      repository: FakeXpStore(storage),
    );
    addTearDown(recreatedService.dispose);

    expect(recreatedService.totalXp, 5);
    expect(recreatedService.currentLevel, 1);
    expect(recreatedService.xpInCurrentLevel, 5);
  });

  test('Favori durumu repository yeniden oluşturulduğunda korunur', () async {
    final records = <String, WordProgress>{};
    final firstRepository = FakeWordProgressStore(records);
    await firstRepository.saveFavorite('dog', true);

    final recreatedRepository = FakeWordProgressStore(records);
    await recreatedRepository.initialize();

    expect(recreatedRepository.progressFor('dog').isFavorite, isTrue);
  });

  test(
    'LearningEngine sonucu kelime repository ilerlemesine aktarılır',
    () async {
      final engine = LearningEngine(animalWords);
      final repository = FakeWordProgressStore();

      engine.rateHard();
      await repository.saveLearningResult(
        engine.lastReview!,
        reviewedAt: DateTime.parse('2026-07-14T10:30:00.000'),
      );

      final progress = repository.progressFor('dog');
      expect(progress.mastery, 'hard');
      expect(progress.repetitionCount, 1);
      expect(progress.correctCount, 0);
      expect(progress.wrongCount, 1);
      expect(progress.lastReviewedAt, isNotNull);
    },
  );

  test(
    'Günlük hedef beş değerlendirmede tamamlanır ve seri bir kez artar',
    () async {
      final service = StreakService(repository: FakeDailyProgressStore());
      addTearDown(service.dispose);
      await service.initialize();

      expect(service.todayCount, 0);
      expect(service.dailyGoal, 5);
      expect(service.currentStreak, 7);
      expect(service.isTodayCompleted, isFalse);
      expect(service.remainingForToday, 5);

      for (var count = 1; count < service.dailyGoal; count++) {
        expect(await service.recordEvaluation(), isFalse);
        expect(service.todayCount, count);
        expect(service.remainingForToday, service.dailyGoal - count);
        expect(service.currentStreak, 7);
      }

      expect(await service.recordEvaluation(), isTrue);
      expect(service.todayCount, 5);
      expect(service.remainingForToday, 0);
      expect(service.isTodayCompleted, isTrue);
      expect(service.currentStreak, 8);

      expect(await service.recordEvaluation(), isFalse);
      expect(await service.recordEvaluation(), isFalse);
      expect(service.todayCount, 7);
      expect(service.remainingForToday, 0);
      expect(service.currentStreak, 8);
    },
  );

  test(
    'Seri servisi yeniden oluşturulduğunda kayıtlı değerleri yükler',
    () async {
      final storage = FakeDailyStorage();
      final firstService = StreakService(
        repository: FakeDailyProgressStore(storage),
      );
      await firstService.initialize();
      for (var count = 0; count < 3; count++) {
        await firstService.recordEvaluation();
      }
      firstService.dispose();

      final recreatedService = StreakService(
        repository: FakeDailyProgressStore(storage),
      );
      addTearDown(recreatedService.dispose);
      await recreatedService.initialize();

      expect(recreatedService.todayCount, 3);
      expect(recreatedService.remainingForToday, 2);
      expect(recreatedService.currentStreak, 7);
      expect(recreatedService.isTodayCompleted, isFalse);

      await recreatedService.recordEvaluation();
      expect(await recreatedService.recordEvaluation(), isTrue);
      expect(recreatedService.currentStreak, 8);
    },
  );

  test('İngilizce TTS ayarlanır ve eşzamanlı konuşmayı engeller', () async {
    final engine = FakeTtsEngine()..speakCompleter = Completer<bool>();
    final service = EnglishTtsService(engine: engine);

    final firstSpeech = service.speak('Dog');
    final ignoredSpeech = await service.speak('Cat');
    await Future<void>.delayed(Duration.zero);

    expect(ignoredSpeech, isTrue);
    expect(service.isSpeaking.value, isTrue);
    expect(engine.language, 'en-US');
    expect(engine.speechRate, 0.42);
    expect(engine.volume, 1.0);
    expect(engine.pitch, 1.0);
    expect(engine.spokenTexts, ['Dog']);

    engine.speakCompleter!.complete(true);
    expect(await firstSpeech, isTrue);
    expect(service.isSpeaking.value, isFalse);

    await service.dispose();
  });

  testWidgets('Dinle butonu mevcut kelimeyi kullanır ve aktif durum gösterir', (
    tester,
  ) async {
    final engine = FakeTtsEngine()..speakCompleter = Completer<bool>();
    final service = EnglishTtsService(engine: engine);
    final xpService = await createXpService();

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: service,
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pump();

    expect(engine.spokenTexts, ['Dog']);
    expect(find.text('Dinleniyor'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    engine.speakCompleter!.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('Dinle'), findsOneWidget);
    expect(find.text('Dinleniyor'), findsNothing);
  });

  testWidgets('TTS hatası kullanıcıya bildirilir', (tester) async {
    final service = EnglishTtsService(
      engine: FakeTtsEngine()..failOnSpeak = true,
    );
    final xpService = await createXpService();

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: service,
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pumpAndSettle();

    expect(find.text('Ses oynatılamadı'), findsOneWidget);
  });

  testWidgets('Favori seçimi anında görünür ve repository kaydından yüklenir', (
    tester,
  ) async {
    final repository = FakeWordProgressStore();
    final xpService = await createXpService();

    Widget wordCard() => MaterialApp(
      home: WordCardScreen(
        wordProgressStore: repository,
        xpService: xpService,
        ttsService: EnglishTtsService(engine: FakeTtsEngine()),
      ),
    );

    await tester.pumpWidget(wordCard());
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.text('Favori'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(repository.progressFor('dog').isFavorite, isTrue);

    await tester.pumpWidget(wordCard());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets('Zor seçilen kelime bir kart sonra yeniden gösterilir', (
    tester,
  ) async {
    await pumpLearningSession(tester);

    expect(find.text('DOG'), findsOneWidget);
    await selectLearningRating(tester, 'Zor');
    expect(find.text('CAT'), findsOneWidget);

    await selectLearningRating(tester, 'Kolay');
    expect(find.text('DOG'), findsOneWidget);
  });

  testWidgets('Tekrar Et seçilen kelime iki kart sonra yeniden gösterilir', (
    tester,
  ) async {
    await pumpLearningSession(tester);

    await selectLearningRating(tester, 'Tekrar Et');
    expect(find.text('CAT'), findsOneWidget);
    await selectLearningRating(tester, 'Kolay');
    expect(find.text('BIRD'), findsOneWidget);
    await selectLearningRating(tester, 'Kolay');

    expect(find.text('DOG'), findsOneWidget);
  });

  testWidgets('Flashcard seçimleri XP değerini 5, 8 ve 10 yapar', (
    tester,
  ) async {
    final storage = FakeXpStorage();
    final xpService = await createXpService(repository: FakeXpStore(storage));
    addTearDown(xpService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: FakeTtsEngine()),
        ),
      ),
    );

    await selectLearningRating(tester, 'Kolay');
    expect(xpService.totalXp, 5);
    expect(storage.state.totalXp, 5);

    await selectLearningRating(tester, 'Zor');
    expect(xpService.totalXp, 8);

    await selectLearningRating(tester, 'Tekrar Et');
    expect(xpService.totalXp, 10);
    expect(storage.state.totalXp, 10);
  });

  testWidgets('Günlük hedef ilk kez tamamlanınca geri bildirim gösterilir', (
    tester,
  ) async {
    final streakService = StreakService(dailyGoal: 1);
    final xpService = await createXpService();
    addTearDown(streakService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: FakeTtsEngine()),
          streakService: streakService,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Kolay'));
    await tester.tap(find.text('Kolay'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('🔥 Günlük hedef tamamlandı! Serin 8 güne çıktı.'),
      findsOneWidget,
    );
    expect(streakService.todayCount, 1);
    expect(streakService.currentStreak, 8);
  });

  testWidgets('Tüm kelimeler Kolay seçilince kategori tamamlanır', (
    tester,
  ) async {
    await pumpLearningSession(tester);

    for (
      var index = 0;
      index < 100 && find.text('Kategori Tamamlandı').evaluate().isEmpty;
      index++
    ) {
      await selectLearningRating(tester, 'Kolay');
    }

    expect(find.text('Kategori Tamamlandı'), findsOneWidget);
    expect(
      find.text('Hayvanlar kategorisindeki tüm kelimeleri tamamladın!'),
      findsOneWidget,
    );
  });

  test('Quiz sonucu yüzde, yıldız ve motivasyon değerlerini hesaplar', () {
    expect(calculateQuizPercentage(correct: 9, total: 10), 90);
    expect(quizStarCount(correct: 10, total: 10), 5);
    expect(quizStarCount(correct: 9, total: 10), 4);
    expect(quizStarCount(correct: 7, total: 10), 3);
    expect(quizStarCount(correct: 5, total: 10), 2);
    expect(quizStarCount(correct: 1, total: 10), 1);
    expect(quizStarCount(correct: 0, total: 10), 0);
    expect(quizMotivation(100), 'Mükemmel!');
    expect(quizMotivation(80), 'Harika gidiyorsun!');
    expect(quizMotivation(60), 'Güzel iş!');
    expect(quizMotivation(40), 'Biraz daha çalışırsan çok daha iyi olacak.');
    expect(quizMotivation(30), 'Pes etme, tekrar deneyelim!');
  });

  test('Türkçe metni dil kurallarına uygun büyük harfe dönüştürür', () {
    expect(toTurkishUpperCase('kedi'), 'KEDİ');
    expect(toTurkishUpperCase('tilki'), 'TİLKİ');
    expect(toTurkishUpperCase('inek'), 'İNEK');
    expect(toTurkishUpperCase('ışık şğüöç'), 'IŞIK ŞĞÜÖÇ');
  });

  test('Hayvanlar listesi 24 benzersiz ve eksiksiz kelime içerir', () {
    expect(animalWords, hasLength(24));
    expect(animalWords.map((word) => word.english).toSet(), hasLength(24));

    for (final word in animalWords) {
      expect(word.english, isNotEmpty);
      expect(word.turkish, isNotEmpty);
      expect(word.emoji, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
      expect(word.exampleTranslation, isNotEmpty);
    }
  });

  test('İstatistikler boş veride güvenli başlangıç değerleri üretir', () async {
    final streakService = StreakService(initialStreak: 0);
    final xpService = await createXpService();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
    );
    addTearDown(streakService.dispose);
    addTearDown(xpService.dispose);
    addTearDown(statisticsService.dispose);

    await statisticsService.refresh();
    final statistics = statisticsService.statistics!;

    expect(statistics.currentLevel, 1);
    expect(statistics.totalXp, 0);
    expect(statistics.currentStreak, 0);
    expect(statistics.todayReviewCount, 0);
    expect(statistics.startedWordCount, 0);
    expect(statistics.favoriteWordCount, 0);
    expect(statistics.distribution.newCount, 24);
    expect(statistics.distribution.learningCount, 0);
    expect(statistics.distribution.learnedCount, 0);
    expect(statistics.quizStatistics.totalQuizCount, 0);
    expect(statistics.quizStatistics.generalSuccessPercentage, 0);
    expect(statistics.recentAttempts, isEmpty);
  });

  test('Genel ilerleme veri olmadığında güvenli boş açıklama üretir', () {
    const distribution = WordLearningDistribution(
      totalCount: 0,
      newCount: 0,
      learningCount: 0,
      learnedCount: 0,
    );

    expect(generalProgressDescription(distribution), 'Henüz kelime bulunmuyor');
  });

  test(
    'İstatistikler kelime dağılımı, quiz sırası ve kategori değerlerini hesaplar',
    () async {
      final wordStore = FakeWordProgressStore({
        'dog': testWordProgress(
          wordId: 'dog',
          mastery: 'easy',
          repetitionCount: 1,
          isFavorite: true,
        ),
        'cat': testWordProgress(wordId: 'cat', isFavorite: true),
        'bird': testWordProgress(
          wordId: 'bird',
          mastery: 'hard',
          repetitionCount: 2,
        ),
        'fish': testWordProgress(
          wordId: 'fish',
          mastery: 'again',
          repetitionCount: 1,
        ),
        'horse': testWordProgress(
          wordId: 'horse',
          mastery: 'easy',
          repetitionCount: 1,
        ),
      });
      final xpStorage = FakeXpStorage(totalXp: 250);
      final quizStorage = FakeQuizStorage();
      final quizStore = FakeQuizStore(quizStorage, xpStorage);
      final attempts = [
        ('animals', 10, 100),
        ('animals', 7, 70),
        ('animals', 5, 50),
        ('animals', 9, 90),
        ('animals', 8, 80),
        ('animals', 6, 60),
        ('foods', 4, 40),
      ];
      for (var index = 0; index < attempts.length; index++) {
        final attempt = attempts[index];
        await quizStore.saveCompletedQuiz(
          categoryId: attempt.$1,
          correctCount: attempt.$2,
          totalQuestions: 10,
          scorePercent: attempt.$3,
          completedAt: DateTime(2026, 7, index + 1),
        );
      }
      final streakService = StreakService(initialStreak: 3);
      for (var count = 0; count < 4; count++) {
        await streakService.recordEvaluation();
      }
      final xpService = await createXpService(
        repository: FakeXpStore(xpStorage),
      );
      final statisticsService = createStatisticsService(
        streakService: streakService,
        xpService: xpService,
        wordProgressStore: wordStore,
        quizStore: quizStore,
      );
      addTearDown(streakService.dispose);
      addTearDown(xpService.dispose);
      addTearDown(statisticsService.dispose);

      await statisticsService.refresh();
      final statistics = statisticsService.statistics!;
      final category = await statisticsService.loadCategory('animals');

      expect(statistics.startedWordCount, 4);
      expect(statistics.favoriteWordCount, 2);
      expect(statistics.distribution.newCount, 20);
      expect(statistics.distribution.learningCount, 2);
      expect(statistics.distribution.learnedCount, 2);
      expect(statistics.quizStatistics.totalQuizCount, 7);
      expect(statistics.quizStatistics.generalSuccessPercentage, 70);
      expect(statistics.bestCategoryName, 'Hayvanlar');
      expect(statistics.highestQuizScore, 100);
      expect(statistics.recentAttempts, hasLength(5));
      expect(statistics.recentAttempts.first.categoryId, 'foods');
      expect(statistics.recentAttempts.first.completedAt, DateTime(2026, 7, 7));
      expect(statistics.recentAttempts.last.completedAt, DateTime(2026, 7, 3));

      expect(category.totalWordCount, 24);
      expect(category.reviewedWordCount, 4);
      expect(category.learnedWordCount, 2);
      expect(category.favoriteWordCount, 2);
      expect(category.averageMasteryPercentage, 13);
      expect(category.completedQuizCount, 6);
      expect(category.highestQuizScore, 100);
      expect(category.averageQuizPercentage, 75);
    },
  );

  testWidgets('ana ekran gerekli bölümleri gösterir', (tester) async {
    await pumpKelimoApp(tester);

    expect(find.text('Merhaba!'), findsOneWidget);
    expect(find.text('Bugün öğrenmeye hazır mısın?'), findsOneWidget);
    expect(find.text('Genel ilerleme'), findsOneWidget);
    expect(find.text('0 / 24 kelime'), findsOneWidget);
    expect(find.text('Henüz öğrenmeye başlamadın'), findsOneWidget);
    expect(find.text('Günlük ilerleme'), findsNothing);
    expect(find.text('18 / 30 kelime'), findsNothing);
    expect(find.text('🔥 7 günlük seri'), findsNothing);
    expect(find.text('Seviye 1'), findsOneWidget);
    expect(find.text('0 / 1000 XP'), findsOneWidget);
    expect(find.text('Günlük Seri'), findsOneWidget);
    expect(find.text('7 gün'), findsOneWidget);
    expect(find.text('Günlük Görev'), findsOneWidget);
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.text('Bugün 5 kelime değerlendir'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    await tester.scrollUntilVisible(find.text('Kategoriler'), 300);
    expect(find.text('Kategoriler'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'İlerleme ekranı boş veride güvenli değerleri ve boş quiz durumunu gösterir',
    (tester) async {
      await pumpKelimoApp(tester);

      await tester.tap(find.text('İlerleme'));
      await tester.pumpAndSettle();

      expect(find.text('Tüm çalışmalarının güncel özeti'), findsOneWidget);
      expect(find.text('Toplam XP'), findsOneWidget);
      expect(find.text('Başlanan kelime'), findsOneWidget);
      expect(find.text('Favori kelime'), findsOneWidget);
      expect(find.text('Tamamlanan quiz'), findsOneWidget);
      expect(find.text('Quiz başarısı'), findsOneWidget);
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.text('24 • %100'), findsOneWidget);
      expect(find.text('Henüz tamamlanmış bir quiz yok.'), findsOneWidget);
    },
  );

  testWidgets('İlerleme ekranı küçük boyutta taşma yapmaz', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await pumpKelimoApp(tester);

    await tester.tap(find.text('İlerleme'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kelime öğrenme dağılımı'), findsOneWidget);
  });

  testWidgets('Ana ekran tamamlanan günlük hedefi servisten gösterir', (
    tester,
  ) async {
    final streakService = StreakService(repository: FakeDailyProgressStore());
    addTearDown(streakService.dispose);
    await streakService.initialize();
    for (var count = 0; count < streakService.dailyGoal; count++) {
      await streakService.recordEvaluation();
    }
    final xpService = await createXpService();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
    );
    addTearDown(statisticsService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          streakService: streakService,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          quizStore: FakeQuizStore(FakeQuizStorage(), FakeXpStorage()),
          statisticsService: statisticsService,
        ),
      ),
    );

    expect(find.text('🔥 8 günlük seri'), findsNothing);
    expect(find.text('8 gün'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('Günlük hedef tamamlandı'), findsOneWidget);
  });

  testWidgets('Ana ekran seviye kartını gerçek XP servisinden gösterir', (
    tester,
  ) async {
    final streakService = StreakService(repository: FakeDailyProgressStore());
    final xpService = await createXpService(totalXp: 1005);
    addTearDown(streakService.dispose);
    addTearDown(xpService.dispose);
    await streakService.initialize();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
    );
    addTearDown(statisticsService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          streakService: streakService,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          quizStore: FakeQuizStore(FakeQuizStorage(), FakeXpStorage()),
          statisticsService: statisticsService,
        ),
      ),
    );

    expect(find.text('Seviye 2'), findsOneWidget);
    expect(find.text('5 / 1000 XP'), findsOneWidget);
    final levelProgress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator).at(1),
    );
    expect(levelProgress.value, 0.005);
  });

  testWidgets(
    'Günlük görev kartı hedef üstü sayacı yalnızca görünümde sınırlar',
    (tester) async {
      final streakService = StreakService(repository: FakeDailyProgressStore());
      addTearDown(streakService.dispose);
      await streakService.initialize();
      for (var count = 0; count < 52; count++) {
        await streakService.recordEvaluation();
      }
      final xpService = await createXpService();
      final statisticsService = createStatisticsService(
        streakService: streakService,
        xpService: xpService,
      );
      addTearDown(statisticsService.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(
            streakService: streakService,
            wordProgressStore: FakeWordProgressStore(),
            xpService: xpService,
            quizStore: FakeQuizStore(FakeQuizStorage(), FakeXpStorage()),
            statisticsService: statisticsService,
          ),
        ),
      );

      expect(streakService.todayCount, 52);
      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('52 / 5'), findsNothing);
      expect(find.text('Günlük hedef tamamlandı'), findsOneWidget);

      final taskProgress = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .last;
      expect(taskProgress.value, 1.0);
    },
  );

  testWidgets('altı kategori kartı ve içerikleri bulunur', (tester) async {
    await pumpKelimoApp(tester);

    for (final category in [
      'Hayvanlar',
      'Yiyecekler',
      'Renkler',
      'Ev',
      'Aile',
      'Ulaşım',
    ]) {
      await tester.scrollUntilVisible(find.text(category), 200);
      expect(find.text(category), findsOneWidget);
    }
  });

  testWidgets('uygulama Türkçe ve Material 3 kullanır', (tester) async {
    await pumpKelimoApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.locale, const Locale('tr', 'TR'));
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.darkTheme?.useMaterial3, isTrue);
    expect(app.theme?.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(app.darkTheme?.scaffoldBackgroundColor, AppColors.darkBackground);
    expect(app.theme?.colorScheme.primary, AppColors.turquoise);
    expect(app.theme?.colorScheme.secondary, AppColors.warmOrange);
  });

  testWidgets('Hayvanlar kartı kategori detay ekranını açar', (tester) async {
    await pumpKelimoApp(tester);

    await openAnimalsCategory(tester);

    expect(find.text('Kategori ilerlemesi'), findsOneWidget);
    expect(find.text('0 / 24 kelime'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);
    expect(find.text('Öğrenmeye Başla'), findsOneWidget);
    expect(find.text('Quiz Çöz'), findsOneWidget);
    expect(find.text('İstatistik'), findsOneWidget);
    expect(find.text('Son çalışmalar'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('Köpek'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets(
    'Ana ekran, kategori ekranı ve istatistik ekranı aynı öğrenilen sayısını kullanır',
    (tester) async {
      final records = <String, WordProgress>{};
      for (var index = 0; index < animalWords.length; index++) {
        final word = animalWords[index];
        records[word.id] = testWordProgress(
          wordId: word.id,
          mastery: index < 22 ? 'easy' : 'hard',
          repetitionCount: 1,
        );
      }

      await pumpKelimoApp(
        tester,
        wordProgressStore: FakeWordProgressStore(records),
      );

      expect(find.text('22 / 24 kelime'), findsOneWidget);
      expect(find.text('2 kelime öğreniliyor'), findsOneWidget);
      final generalProgress = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('general-progress')),
      );
      expect(generalProgress.value, 22 / 24);

      await tester.scrollUntilVisible(find.text('Hayvanlar'), 300);
      expect(find.text('%92'), findsOneWidget);

      await tester.tap(find.text('Hayvanlar'));
      await tester.pumpAndSettle();
      expect(find.text('22 / 24 kelime'), findsOneWidget);
      expect(find.text('%92 tamamlandı'), findsOneWidget);

      await tester.tap(find.text('İstatistik'));
      await tester.pumpAndSettle();
      expect(find.text('Öğrenilen'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
    },
  );

  testWidgets('Bütün kelimeler öğrenildiğinde genel ilerleme tamamlanır', (
    tester,
  ) async {
    final records = {
      for (final word in animalWords)
        word.id: testWordProgress(
          wordId: word.id,
          mastery: 'easy',
          repetitionCount: 1,
        ),
    };

    await pumpKelimoApp(
      tester,
      wordProgressStore: FakeWordProgressStore(records),
    );

    expect(find.text('24 / 24 kelime'), findsOneWidget);
    expect(find.text('Tüm kelimeleri öğrendin!'), findsOneWidget);
    final generalProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('general-progress')),
    );
    expect(generalProgress.value, 1.0);
  });

  testWidgets(
    'Kelime değerlendirmesinden sonra kategori ilerlemesi yenilenir',
    (tester) async {
      final wordStore = FakeWordProgressStore();
      await pumpKelimoApp(tester, wordProgressStore: wordStore);

      await openAnimalsCategory(tester);
      expect(find.text('0 / 24 kelime'), findsOneWidget);

      await tester.tap(find.text('Öğrenmeye Başla'));
      await tester.pumpAndSettle();
      await selectLearningRating(tester, 'Kolay');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('1 / 24 kelime'), findsOneWidget);
      expect(find.text('%4 tamamlandı'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Hayvanlar'), 300);
      expect(find.text('%4'), findsOneWidget);
    },
  );

  testWidgets('Kategori İstatistik kartı gerçek kategori özetini açar', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openAnimalsCategory(tester);

    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();

    expect(find.text('Hayvanlar İstatistikleri'), findsOneWidget);
    expect(find.text('Hayvanlar performansı'), findsOneWidget);
    expect(find.text('Toplam kelime'), findsOneWidget);
    expect(find.text('Değerlendirilen'), findsOneWidget);
    expect(find.text('Öğrenilen'), findsOneWidget);
    expect(find.text('Ortalama mastery'), findsOneWidget);
    expect(find.text('Tamamlanan quiz'), findsOneWidget);
    expect(find.text('En yüksek skor'), findsOneWidget);
    expect(find.text('Ortalama quiz'), findsOneWidget);
  });

  testWidgets('Öğrenmeye Başla ilk kelime kartını açar ve kart çevrilir', (
    tester,
  ) async {
    await pumpKelimoApp(tester);

    await openAnimalsCategory(tester);
    await tester.tap(find.text('Öğrenmeye Başla'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 24'), findsOneWidget);
    expect(find.text('DOG'), findsOneWidget);
    expect(find.text('Kartı çevirmek için dokun'), findsOneWidget);
    expect(find.text('Dinle'), findsOneWidget);
    expect(find.text('Favori'), findsOneWidget);
    expect(find.text('Bu kelime nasıldı?'), findsOneWidget);
    expect(find.text('Önceki'), findsOneWidget);
    expect(find.text('Sonraki'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('word-card')));
    await tester.pumpAndSettle();

    expect(find.text('KÖPEK'), findsOneWidget);
    expect(find.text('The dog is sleeping.'), findsOneWidget);
    expect(find.text('Köpek uyuyor.'), findsOneWidget);

    await tester.ensureVisible(find.text('Sonraki'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 24'), findsOneWidget);
    expect(find.text('CAT'), findsOneWidget);
    expect(find.text('Kartı çevirmek için dokun'), findsOneWidget);

    await tester.tap(find.text('Önceki'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 24'), findsOneWidget);
    expect(find.text('DOG'), findsOneWidget);
  });

  testWidgets('Quiz seçimi kilitlenir ve doğru cevap gösterilir', (
    tester,
  ) async {
    await pumpKelimoApp(tester);

    await openAnimalsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Hayvanlar Quiz'), findsOneWidget);
    expect(find.text('Soru 1 / 10'), findsOneWidget);
    expect(find.text('DOG'), findsOneWidget);
    expect(find.text('Doğru Türkçe karşılığı seç'), findsOneWidget);

    var nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sonraki Soru'),
    );
    expect(nextButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('quiz-option-Kedi')));
    await tester.pump();

    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final lockedOption = tester.widget<InkWell>(
      find.byKey(const ValueKey('quiz-option-Kedi')),
    );
    expect(lockedOption.onTap, isNull);

    nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sonraki Soru'),
    );
    expect(nextButton.onPressed, isNotNull);

    await tester.ensureVisible(find.text('Sonraki Soru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonraki Soru'));
    await tester.pumpAndSettle();

    expect(find.text('Soru 2 / 10'), findsOneWidget);
    expect(find.text('CAT'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('Quiz tamamlanınca sonuç gösterilir ve tekrar başlatılır', (
    tester,
  ) async {
    await pumpKelimoApp(tester);

    await openAnimalsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();
    await completeQuiz(tester);

    expect(find.text('Tebrikler!'), findsOneWidget);
    expect(find.text('Hayvanlar Quizi Tamamlandı'), findsOneWidget);
    expect(find.text('10 / 10'), findsOneWidget);
    expect(find.text('%100 başarı'), findsOneWidget);
    expect(find.text('Mükemmel!'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    expect(find.text('7 doğru'), findsOneWidget);
    expect(find.text('1 dk 42 sn'), findsOneWidget);
    expect(find.text('+25 XP'), findsOneWidget);
    expect(find.text('🏆 Kusursuz sonuç! +25 XP kazandın.'), findsOneWidget);

    await tester.ensureVisible(find.text('Tekrar Çöz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrar Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Hayvanlar Quiz'), findsOneWidget);
    expect(find.text('Soru 1 / 10'), findsOneWidget);
    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sonraki Soru'),
    );
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('Sonuç ekranı rebuild olduğunda quiz ve XP ikinci kez eklenmez', (
    tester,
  ) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openAnimalsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();
    await completeQuiz(tester);

    expect(quizStorage.attempts, hasLength(1));
    expect(xpStorage.state.totalXp, 25);

    await tester.binding.setSurfaceSize(const Size(700, 1000));
    await tester.pumpAndSettle();

    expect(find.text('🏆 Kusursuz sonuç! +25 XP kazandın.'), findsOneWidget);
    expect(quizStorage.attempts, hasLength(1));
    expect(xpStorage.state.totalXp, 25);
  });

  testWidgets('Düşük quiz sonucu kaydedilir fakat XP kazandırmaz', (
    tester,
  ) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openAnimalsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();
    await completeQuiz(tester, perfect: false);

    expect(find.text('%90 başarı'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
    expect(find.text('🏆 Kusursuz sonuç! +25 XP kazandın.'), findsNothing);
    expect(quizStorage.attempts.single.xpAwarded, 0);
    expect(xpStorage.state.totalXp, 0);
  });

  testWidgets(
    '250 XP ile kusursuz quiz sonrası ana ekran ve yeniden açılış 275 gösterir',
    (tester) async {
      final xpStorage = FakeXpStorage(totalXp: 250);
      final quizStorage = FakeQuizStorage();
      await pumpKelimoApp(
        tester,
        xpStorage: xpStorage,
        quizStorage: quizStorage,
      );
      await openAnimalsCategory(tester);
      await tester.tap(find.text('Quiz Çöz'));
      await tester.pumpAndSettle();
      await completeQuiz(tester);

      await tester.ensureVisible(find.text('Ana Sayfa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Sayfa'));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 1000),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('275 / 1000 XP'), findsOneWidget);

      await pumpKelimoApp(
        tester,
        xpStorage: xpStorage,
        quizStorage: quizStorage,
      );
      expect(find.text('275 / 1000 XP'), findsOneWidget);
      expect(quizStorage.attempts, hasLength(1));
    },
  );

  testWidgets('Sonuç ekranı dönüş butonlarını doğru callbacklere bağlar', (
    tester,
  ) async {
    var selectedAction = '';

    Widget resultScreen() => MaterialApp(
      home: QuizResultScreen(
        categoryName: 'Hayvanlar',
        correctAnswerCount: 8,
        totalQuestionCount: 10,
        successPercentage: 80,
        xpAwarded: 0,
        onRetry: () => selectedAction = 'retry',
        onReturnToCategory: () => selectedAction = 'category',
        onReturnHome: () => selectedAction = 'home',
      ),
    );

    await tester.pumpWidget(resultScreen());
    expect(find.text('0 XP'), findsOneWidget);
    expect(find.text('🏆 Kusursuz sonuç! +25 XP kazandın.'), findsNothing);
    await tester.ensureVisible(find.text('Kategoriye Dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kategoriye Dön'));
    expect(selectedAction, 'category');

    selectedAction = '';
    await tester.pumpWidget(resultScreen());
    await tester.ensureVisible(find.text('Ana Sayfa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Sayfa'));
    expect(selectedAction, 'home');
  });
}
