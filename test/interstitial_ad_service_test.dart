import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/models/ad_display_state.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';

void main() {
  const policy = InterstitialAdPolicy();
  final now = DateTime.utc(2026, 7, 17, 12);

  bool eligible({
    required int quizCount,
    DateTime? lastShownAt,
    bool foreground = true,
    bool consent = true,
    bool ready = true,
  }) {
    return policy.isEligible(
      state: AdDisplayState(
        completedQuizCountSinceLastAd: quizCount,
        lastInterstitialShownAt: lastShownAt,
      ),
      isForeground: foreground,
      canRequestAds: consent,
      isAdReady: ready,
    );
  }

  test('Consent olmadan reklam uygun sayılmaz', () {
    expect(eligible(quizCount: 3, consent: false), isFalse);
  });

  test('İlk quiz sonrası reklam gösterilmez, ikinci quizde uygun olur', () {
    expect(eligible(quizCount: 0), isFalse);
    expect(eligible(quizCount: 1), isFalse);
    expect(eligible(quizCount: 2), isTrue);
  });

  test('son reklam zamanı iki yeni quiz sonrası uygunluğu engellemez', () {
    expect(
      eligible(
        quizCount: 2,
        lastShownAt: now.subtract(const Duration(seconds: 1)),
      ),
      isTrue,
    );
  });

  test('Foreground ve hazır reklam koşulları zorunludur', () {
    expect(eligible(quizCount: 2, foreground: false), isFalse);
    expect(eligible(quizCount: 2, ready: false), isFalse);
  });
}
