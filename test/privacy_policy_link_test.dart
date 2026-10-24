import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/screens/privacy_center_screen.dart';

void main() {
  final policyLink = find.byKey(const ValueKey('privacy-policy-link'));

  testWidgets('privacy policy opens the public HTTPS URL once while pending', (
    tester,
  ) async {
    final opened = <Uri>[];
    final result = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyCenterScreen(
          policyLauncher: (uri) {
            opened.add(uri);
            return result.future;
          },
        ),
      ),
    );
    await tester.ensureVisible(policyLink);
    await tester.pumpAndSettle();
    await tester.tap(policyLink);
    await tester.pump();
    expect(tester.widget<OutlinedButton>(policyLink).onPressed, isNull);
    expect(opened, [
      Uri.parse('https://veles1010.github.io/kelimo/privacy-policy.html'),
    ]);
    result.complete(true);
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(policyLink).onPressed, isNotNull);
    expect(find.textContaining('Bağlantı açılamadı.'), findsNothing);
  });

  testWidgets('launcher failure shows the URL and allows another attempt', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyCenterScreen(
          policyLauncher: (_) async {
            attempts++;
            if (attempts == 1) throw Exception('No browser');
            return false;
          },
        ),
      ),
    );
    await tester.ensureVisible(policyLink);
    await tester.pumpAndSettle();
    await tester.tap(policyLink);
    await tester.pumpAndSettle();
    expect(find.textContaining('Bağlantı açılamadı.'), findsOneWidget);
    expect(
      find.textContaining('https://veles1010.github.io/kelimo/privacy-policy.html'),
      findsOneWidget,
    );
    expect(tester.widget<OutlinedButton>(policyLink).onPressed, isNotNull);
    await tester.tap(policyLink);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });
}
