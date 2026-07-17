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
      now: now,
      isForeground: foreground,
      canRequestAds: consent,
      isAdReady: ready,
    );
  }

  test('Consent olmadan reklam uygun sayılmaz', () {
    expect(eligible(quizCount: 3, consent: false), isFalse);
  });

  test('İlk iki quiz sonrası reklam gösterilmez, üçüncüde uygun olur', () {
    expect(eligible(quizCount: 1), isFalse);
    expect(eligible(quizCount: 2), isFalse);
    expect(eligible(quizCount: 3), isTrue);
  });

  test('15 dakika cooldown dolmadan yeniden gösterilmez', () {
    expect(
      eligible(
        quizCount: 3,
        lastShownAt: now.subtract(const Duration(minutes: 14, seconds: 59)),
      ),
      isFalse,
    );
    expect(
      eligible(
        quizCount: 3,
        lastShownAt: now.subtract(const Duration(minutes: 15)),
      ),
      isTrue,
    );
  });

  test('Foreground ve hazır reklam koşulları zorunludur', () {
    expect(eligible(quizCount: 3, foreground: false), isFalse);
    expect(eligible(quizCount: 3, ready: false), isFalse);
  });
}
