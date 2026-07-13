import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/main.dart';
import 'package:kelimo/screens/quiz_result_screen.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/utils/turkish_case.dart';

void main() {
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
    expect(find.text('Kategoriler'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
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
      expect(find.text(category, skipOffstage: false), findsOneWidget);
    }

    expect(
      find.byType(LinearProgressIndicator, skipOffstage: false),
      findsNWidgets(7),
    );
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

    await tester.tap(find.text('Hayvanlar'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.text('Hayvanlar'));
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Hayvanlar'));
    await tester.pumpAndSettle();
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

    await tester.tap(find.text('Hayvanlar'));
    await tester.pumpAndSettle();
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
