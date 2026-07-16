enum SpeechRatePreference {
  slow('slow', 'Yavaş', 0.35),
  normal('normal', 'Normal', 0.42),
  fast('fast', 'Hızlı', 0.65);

  const SpeechRatePreference(this.storageValue, this.label, this.ttsRate);

  final String storageValue;
  final String label;
  final double ttsRate;

  static SpeechRatePreference fromStorage(String? value) {
    return values.firstWhere(
      (rate) => rate.storageValue == value,
      orElse: () => normal,
    );
  }
}

class AppSettings {
  const AppSettings({required this.dailyGoal, required this.speechRate});

  static const allowedDailyGoals = {5, 10, 15, 20};
  static const defaults = AppSettings(
    dailyGoal: 5,
    speechRate: SpeechRatePreference.normal,
  );

  final int dailyGoal;
  final SpeechRatePreference speechRate;

  AppSettings copyWith({int? dailyGoal, SpeechRatePreference? speechRate}) {
    return AppSettings(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      speechRate: speechRate ?? this.speechRate,
    );
  }

  static int safeDailyGoal(String? value) {
    final parsed = int.tryParse(value ?? '');
    return allowedDailyGoals.contains(parsed) ? parsed! : defaults.dailyGoal;
  }
}
