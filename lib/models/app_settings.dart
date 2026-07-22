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

enum ThemePreference {
  system('system', 'Sistem ayarı'),
  light('light', 'Açık'),
  dark('dark', 'Koyu');

  const ThemePreference(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static ThemePreference fromStorage(String? value) {
    return values.firstWhere(
      (theme) => theme.storageValue == value,
      orElse: () => system,
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.dailyGoal,
    required this.speechRate,
    required this.reminderEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.themeMode,
    this.onboardingCompleted = true,
  });

  static const allowedDailyGoals = {5, 10, 15, 20};
  static const defaults = AppSettings(
    dailyGoal: 5,
    speechRate: SpeechRatePreference.normal,
    reminderEnabled: false,
    reminderHour: 20,
    reminderMinute: 0,
    themeMode: ThemePreference.system,
    onboardingCompleted: true,
  );

  final int dailyGoal;
  final SpeechRatePreference speechRate;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final ThemePreference themeMode;
  final bool onboardingCompleted;

  AppSettings copyWith({
    int? dailyGoal,
    SpeechRatePreference? speechRate,
    bool? reminderEnabled,
    int? reminderHour,
    int? reminderMinute,
    ThemePreference? themeMode,
    bool? onboardingCompleted,
  }) {
    return AppSettings(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      speechRate: speechRate ?? this.speechRate,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      themeMode: themeMode ?? this.themeMode,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }

  static int safeDailyGoal(String? value) {
    final parsed = int.tryParse(value ?? '');
    return allowedDailyGoals.contains(parsed) ? parsed! : defaults.dailyGoal;
  }

  static bool safeReminderEnabled(String? value) => value == 'true';

  static int safeReminderHour(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed != null && parsed >= 0 && parsed <= 23
        ? parsed
        : defaults.reminderHour;
  }

  static int safeReminderMinute(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed != null && parsed >= 0 && parsed <= 59
        ? parsed
        : defaults.reminderMinute;
  }
}
