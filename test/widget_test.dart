import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/main.dart';
import 'package:kelimo/models/daily_progress.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/repositories/daily_progress_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/quiz_result_screen.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/screens/word_card_screen.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/streak_service.dart';
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

Future<void> pumpKelimoApp(WidgetTester tester) async {
  await tester.pumpWidget(
    KelimoApp(
      wordProgressStore: FakeWordProgressStore(),
      dailyProgressStore: FakeDailyProgressStore(),
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
  await tester.pumpWidget(
    MaterialApp(
      home: WordCardScreen(
        wordProgressStore: FakeWordProgressStore(),
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

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          wordProgressStore: FakeWordProgressStore(),
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

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          wordProgressStore: FakeWordProgressStore(),
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

    Widget wordCard() => MaterialApp(
      home: WordCardScreen(
        wordProgressStore: repository,
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

  testWidgets('Günlük hedef ilk kez tamamlanınca geri bildirim gösterilir', (
    tester,
  ) async {
    final streakService = StreakService(dailyGoal: 1);
    addTearDown(streakService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          wordProgressStore: FakeWordProgressStore(),
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

  testWidgets('ana ekran gerekli bölümleri gösterir', (tester) async {
    await pumpKelimoApp(tester);

    expect(find.text('Merhaba!'), findsOneWidget);
    expect(find.text('Bugün öğrenmeye hazır mısın?'), findsOneWidget);
    expect(find.text('Günlük ilerleme'), findsOneWidget);
    expect(find.text('18 / 30 kelime'), findsOneWidget);
    expect(find.text('🔥 7 günlük seri'), findsOneWidget);
    expect(find.text('Seviye 4'), findsOneWidget);
    expect(find.text('720 / 1000 XP'), findsOneWidget);
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

  testWidgets('Ana ekran tamamlanan günlük hedefi servisten gösterir', (
    tester,
  ) async {
    final streakService = StreakService(repository: FakeDailyProgressStore());
    addTearDown(streakService.dispose);
    await streakService.initialize();
    for (var count = 0; count < streakService.dailyGoal; count++) {
      await streakService.recordEvaluation();
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          streakService: streakService,
          wordProgressStore: FakeWordProgressStore(),
        ),
      ),
    );

    expect(find.text('🔥 8 günlük seri'), findsOneWidget);
    expect(find.text('8 gün'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('Günlük hedef tamamlandı'), findsOneWidget);
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

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(
            streakService: streakService,
            wordProgressStore: FakeWordProgressStore(),
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
    expect(find.text('12 / 24 kelime'), findsOneWidget);
    expect(find.text('%50 tamamlandı'), findsOneWidget);
    expect(find.text('Öğrenmeye Başla'), findsOneWidget);
    expect(find.text('Quiz Çöz'), findsOneWidget);
    expect(find.text('İstatistik'), findsOneWidget);
    expect(find.text('Son çalışmalar'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('Köpek'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
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

    for (var index = 0; index < 10; index++) {
      final correctOption = find.byKey(
        ValueKey('quiz-option-${animalWords[index].turkish}'),
      );
      await tester.ensureVisible(correctOption);
      await tester.pumpAndSettle();
      await tester.tap(correctOption);
      await tester.pump();

      final buttonLabel = index == 9 ? 'Sonucu Gör' : 'Sonraki Soru';
      await tester.ensureVisible(find.text(buttonLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(buttonLabel));
      await tester.pumpAndSettle();
    }

    expect(find.text('Tebrikler!'), findsOneWidget);
    expect(find.text('Hayvanlar Quizi Tamamlandı'), findsOneWidget);
    expect(find.text('10 / 10'), findsOneWidget);
    expect(find.text('%100 başarı'), findsOneWidget);
    expect(find.text('Mükemmel!'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    expect(find.text('7 doğru'), findsOneWidget);
    expect(find.text('1 dk 42 sn'), findsOneWidget);
    expect(find.text('+120 XP'), findsOneWidget);

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
        onRetry: () => selectedAction = 'retry',
        onReturnToCategory: () => selectedAction = 'category',
        onReturnHome: () => selectedAction = 'home',
      ),
    );

    await tester.pumpWidget(resultScreen());
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
