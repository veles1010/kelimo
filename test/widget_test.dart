import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/main.dart';
import 'package:kelimo/theme/app_theme.dart';

void main() {
  testWidgets('ana ekran temel içerikleri gösterir', (tester) async {
    await tester.pumpWidget(const KelimoApp());

    expect(find.text('Kelimo'), findsOneWidget);
    expect(
      find.text('Kelimeleri keşfet, öğrenmenin keyfini çıkar.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Öğrenmeye başla'),
      findsOneWidget,
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
}
