class AdDisplayState {
  const AdDisplayState({
    required this.completedQuizCountSinceLastAd,
    required this.lastInterstitialShownAt,
  });

  static const initial = AdDisplayState(
    completedQuizCountSinceLastAd: 0,
    lastInterstitialShownAt: null,
  );

  final int completedQuizCountSinceLastAd;
  final DateTime? lastInterstitialShownAt;
}
