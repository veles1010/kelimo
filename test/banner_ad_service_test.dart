import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/services/banner_ad_service.dart';

class _FakeBannerAdService extends BannerAdService {
  bool loaded = false;
  bool failed = false;
  double bannerHeight = 50;
  int loadCalls = 0;
  int disposeCalls = 0;

  @override
  bool get isLoaded => loaded;

  @override
  bool get isLoading => false;

  @override
  double get height => bannerHeight;

  @override
  Future<void> load({required double width}) async {
    loadCalls++;
    if (failed) notifyListeners();
  }

  @override
  Widget buildAdWidget() => const SizedBox(key: ValueKey('banner'));

  void markLoaded() {
    loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    disposeCalls++;
    super.dispose();
  }
}

void main() {
  group('BannerAdUnitConfiguration', () {
    const configuration = BannerAdUnitConfiguration(
      androidLearningAdUnitId: 'android-learning-production',
      iosLearningAdUnitId: 'ios-learning-production',
      androidQuizAdUnitId: 'android-quiz-production',
      iosQuizAdUnitId: 'ios-quiz-production',
    );

    test('uses the official platform test IDs outside release mode', () {
      expect(
        configuration.resolve(
          placement: BannerPlacement.learning,
          useTestAds: true,
          isAndroid: true,
          isIos: false,
        ),
        BannerAdUnitConfiguration.androidTestBannerAdUnitId,
      );
      expect(
        configuration.resolve(
          placement: BannerPlacement.quiz,
          useTestAds: true,
          isAndroid: false,
          isIos: true,
        ),
        BannerAdUnitConfiguration.iosTestBannerAdUnitId,
      );
    });

    test('resolves separate production units for every placement', () {
      expect(
        configuration.resolve(
          placement: BannerPlacement.learning,
          useTestAds: false,
          isAndroid: true,
          isIos: false,
        ),
        'android-learning-production',
      );
      expect(
        configuration.resolve(
          placement: BannerPlacement.quiz,
          useTestAds: false,
          isAndroid: true,
          isIos: false,
        ),
        'android-quiz-production',
      );
    });

    test('rejects missing and Google test units in release mode', () {
      const invalid = BannerAdUnitConfiguration(
        androidLearningAdUnitId:
            BannerAdUnitConfiguration.androidTestBannerAdUnitId,
      );
      expect(
        invalid.resolve(
          placement: BannerPlacement.learning,
          useTestAds: false,
          isAndroid: true,
          isIos: false,
        ),
        isNull,
      );
      expect(
        invalid.resolve(
          placement: BannerPlacement.quiz,
          useTestAds: false,
          isAndroid: true,
          isIos: false,
        ),
        isNull,
      );
    });
  });

  testWidgets('banner slot reserves space only after successful load', (
    tester,
  ) async {
    final service = _FakeBannerAdService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LearningBannerSlot(service: service)),
      ),
    );
    await tester.pump();
    expect(service.loadCalls, 1);
    expect(find.byKey(const ValueKey('banner')), findsNothing);

    service.markLoaded();
    await tester.pump();
    expect(find.byKey(const ValueKey('banner')), findsOneWidget);
    expect(tester.getSize(find.byType(LearningBannerSlot)).height, 50);

    service.dispose();
  });

  testWidgets('failed banner keeps the layout collapsed', (tester) async {
    final service = _FakeBannerAdService()..failed = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LearningBannerSlot(service: service)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('banner')), findsNothing);
    expect(tester.getSize(find.byType(LearningBannerSlot)).height, 0);
    service.dispose();
  });

  testWidgets('a 100 pixel adaptive banner gets its own space below controls', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    final service = _FakeBannerAdService()..bannerHeight = 100;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    key: const ValueKey('word-navigation'),
                    height: 52,
                  ),
                ),
              ),
              LearningBannerSlot(service: service),
            ],
          ),
        ),
      ),
    );
    service.markLoaded();
    await tester.pump();

    final navigationBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('word-navigation')))
        .dy;
    final bannerTop = tester.getTopLeft(find.byType(LearningBannerSlot)).dy;
    expect(navigationBottom, lessThanOrEqualTo(bannerTop));
    expect(tester.getSize(find.byType(LearningBannerSlot)).height, 100);
    expect(tester.takeException(), isNull);
    service.dispose();
  });
}
