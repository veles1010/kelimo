import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/main.dart';
import 'package:kelimo/theme/app_theme.dart';

void main() {
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
}
