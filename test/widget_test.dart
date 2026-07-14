import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/main.dart';
import 'package:kelimo/models/word.dart';
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

Future<void> openAnimalsCategory(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Hayvanlar'), 300);
  await tester.tap(find.text('Hayvanlar'));
  await tester.pumpAndSettle();
}

Future<void> pumpLearningSession(WidgetTester tester) async {
  final service = EnglishTtsService(engine: FakeTtsEngine());
  await tester.pumpWidget(
    MaterialApp(home: WordCardScreen(ttsService: service)),
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

  test('Günlük hedef beş değerlendirmede tamamlanır ve seri bir kez artar', () {
    final service = StreakService();
    addTearDown(service.dispose);

    expect(service.todayCount, 0);
    expect(service.dailyGoal, 5);
    expect(service.currentStreak, 7);
    expect(service.isTodayCompleted, isFalse);
    expect(service.remainingForToday, 5);

    for (var count = 1; count < service.dailyGoal; count++) {
      expect(service.recordEvaluation(), isFalse);
      expect(service.todayCount, count);
      expect(service.remainingForToday, service.dailyGoal - count);
      expect(service.currentStreak, 7);
    }

    expect(service.recordEvaluation(), isTrue);
    expect(service.todayCount, 5);
    expect(service.remainingForToday, 0);
    expect(service.isTodayCompleted, isTrue);
    expect(service.currentStreak, 8);

    expect(service.recordEvaluation(), isFalse);
    expect(service.recordEvaluation(), isFalse);
    expect(service.todayCount, 7);
    expect(service.remainingForToday, 0);
    expect(service.currentStreak, 8);
  });

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
      MaterialApp(home: WordCardScreen(ttsService: service)),
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
      MaterialApp(home: WordCardScreen(ttsService: service)),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pumpAndSettle();

    expect(find.text('Ses oynatılamadı'), findsOneWidget);
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
    await tester.pumpWidget(const KelimoApp());

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
    final streakService = StreakService();
    addTearDown(streakService.dispose);
    for (var count = 0; count < streakService.dailyGoal; count++) {
      streakService.recordEvaluation();
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(streakService: streakService),
      ),
    );

    expect(find.text('🔥 8 günlük seri'), findsOneWidget);
    expect(find.text('8 gün'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('Günlük hedef tamamlandı'), findsOneWidget);
  });

  testWidgets('altı kategori kartı ve içerikleri bulunur', (tester) async {
    await tester.pumpWidget(const KelimoApp());

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
    await tester.pumpWidget(const KelimoApp());

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
    await tester.pumpWidget(const KelimoApp());

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
    await tester.pumpWidget(const KelimoApp());

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
    await tester.pumpWidget(const KelimoApp());

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
    await tester.pumpWidget(const KelimoApp());

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
