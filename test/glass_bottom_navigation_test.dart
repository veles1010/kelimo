import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/theme/app_theme.dart';

void main() {
  Finder item(int index) => find.byKey(ValueKey('bottom-nav-item-$index'));
  Finder indicator() =>
      find.byKey(const ValueKey('bottom-nav-selection-indicator'));

  Future<({List<int> commits, ValueNotifier<int> selected})> pumpBar(
    WidgetTester tester, {
    bool dark = false,
    bool reducedMotion = false,
    bool rtl = false,
    double textScale = 1,
  }) async {
    final selected = ValueNotifier(0);
    final commits = <int>[];
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark : AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reducedMotion,
          ),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(
              bottomNavigationBar: ValueListenableBuilder<int>(
                valueListenable: selected,
                builder: (context, index, _) => GlassBottomNavigation(
                  selectedIndex: index,
                  onDestinationSelected: (value) {
                    commits.add(value);
                    selected.value = value;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return (commits: commits, selected: selected);
  }

  testWidgets('drag previews continuously and commits only on release', (
    tester,
  ) async {
    final state = await pumpBar(tester);
    final width = tester.getSize(item(0)).width;
    final start = tester.getTopLeft(indicator()).dx;
    final gesture = await tester.startGesture(tester.getCenter(item(0)));
    await gesture.moveBy(Offset(width * .35, 0));
    await tester.pump();
    final partial = tester.getTopLeft(indicator()).dx;
    expect(partial, greaterThan(start));
    expect(partial, lessThan(start + width));
    expect(state.commits, isEmpty);
    await gesture.moveBy(Offset(width * .35, 0));
    await tester.pump();
    expect(tester.getTopLeft(indicator()).dx, greaterThan(partial));
    expect(state.selected.value, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.commits, [1]);
    expect(
      tester.getTopLeft(indicator()).dx,
      closeTo(tester.getTopLeft(item(1)).dx, .01),
    );
  });

  testWidgets('cancel restores selection and subsequent taps still work', (
    tester,
  ) async {
    final state = await pumpBar(tester);
    final width = tester.getSize(item(0)).width;
    final gesture = await tester.startGesture(tester.getCenter(item(0)));
    await gesture.moveBy(Offset(width * 1.4, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(state.commits, isEmpty);
    expect(
      tester.getTopLeft(indicator()).dx,
      closeTo(tester.getTopLeft(item(0)).dx, .01),
    );
    await tester.tap(item(3));
    await tester.pumpAndSettle();
    expect(state.commits, [3]);
    await tester.tap(item(3));
    await tester.pumpAndSettle();
    expect(state.commits, [3]);
  });

  testWidgets('edge drags clamp and vertical gestures do not change tabs', (
    tester,
  ) async {
    final state = await pumpBar(tester);
    await tester.drag(item(0), const Offset(4, -100));
    await tester.pumpAndSettle();
    expect(state.commits, isEmpty);
    await tester.drag(item(0), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(state.selected.value, 0);
    await tester.drag(item(0), const Offset(2000, 0));
    await tester.pumpAndSettle();
    expect(state.commits, [3]);
    expect(
      tester.getTopLeft(indicator()).dx,
      closeTo(tester.getTopLeft(item(3)).dx, .01),
    );
  });

  testWidgets('parent navigation overrides an in-progress drag', (tester) async {
    final state = await pumpBar(tester);
    final gesture = await tester.startGesture(tester.getCenter(item(0)));
    await gesture.moveBy(Offset(tester.getSize(item(0)).width, 0));
    await tester.pump();
    state.selected.value = 3;
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(state.commits, isEmpty);
    expect(
      tester.getTopLeft(indicator()).dx,
      closeTo(tester.getTopLeft(item(3)).dx, .01),
    );
  });

  testWidgets('RTL drag follows the destination order', (tester) async {
    final state = await pumpBar(tester, rtl: true);
    final width = tester.getSize(item(0)).width;
    await tester.drag(item(0), Offset(-width * 1.2, 0));
    await tester.pumpAndSettle();
    expect(state.commits, [1]);
    expect(
      tester.getTopLeft(indicator()).dx,
      closeTo(tester.getTopLeft(item(1)).dx, .01),
    );
  });

  for (final dark in [false, true]) {
    testWidgets('compact bar preserves semantics and reduced motion: $dark', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();
      try {
        final state = await pumpBar(
          tester, dark: dark, reducedMotion: true, textScale: 1.5,
        );
        await tester.tap(item(2));
        await tester.pump();
        expect(state.commits, [2]);
        expect(
          tester.getTopLeft(indicator()).dx,
          closeTo(tester.getTopLeft(item(2)).dx, .01),
        );
        expect(
          tester.getSemantics(find.bySemanticsLabel('İlerleme'))
              .flagsCollection.isSelected.toBoolOrNull(),
          isTrue,
        );
        expect(tester.getSize(item(0)).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
