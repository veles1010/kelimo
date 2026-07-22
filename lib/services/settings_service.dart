import 'package:flutter/material.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:kelimo/models/daily_progress.dart';
import 'package:kelimo/repositories/settings_repository.dart';

class SettingsService extends ChangeNotifier {
  SettingsService({required this.repository, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final SettingsStore repository;
  final DateTime Function() _now;

  AppSettings _settings = AppSettings.defaults;
  int _activeDailyGoal = AppSettings.defaults.dailyGoal;
  bool _isLoading = true;

  AppSettings get settings => _settings;
  int get dailyGoal => _settings.dailyGoal;
  int get activeDailyGoal => _activeDailyGoal;
  SpeechRatePreference get speechRate => _settings.speechRate;
  double get ttsSpeechRate => speechRate.ttsRate;
  bool get reminderEnabled => _settings.reminderEnabled;
  int get reminderHour => _settings.reminderHour;
  int get reminderMinute => _settings.reminderMinute;
  ThemePreference get themeMode => _settings.themeMode;
  bool get onboardingCompleted => _settings.onboardingCompleted;
  ThemeMode get materialThemeMode => switch (themeMode) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    try {
      _settings = await repository.load();
      await refreshActiveDailyGoal();
    } catch (error, stackTrace) {
      debugPrint('Ayar servisi başlatılamadı: $error\n$stackTrace');
      _settings = AppSettings.defaults;
      _activeDailyGoal = AppSettings.defaults.dailyGoal;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDailyGoal(int dailyGoal) async {
    if (!AppSettings.allowedDailyGoals.contains(dailyGoal)) {
      throw ArgumentError.value(dailyGoal, 'dailyGoal');
    }
    await repository.setDailyGoal(dailyGoal);
    _settings = _settings.copyWith(dailyGoal: dailyGoal);
    notifyListeners();
  }

  Future<void> setSpeechRate(SpeechRatePreference speechRate) async {
    await repository.setSpeechRate(speechRate);
    _settings = _settings.copyWith(speechRate: speechRate);
    notifyListeners();
  }

  Future<void> setReminderEnabled(bool enabled) async {
    await repository.setReminderEnabled(enabled);
    _settings = _settings.copyWith(reminderEnabled: enabled);
    notifyListeners();
  }

  Future<void> setReminderTime({required int hour, required int minute}) async {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Geçersiz hatırlatma saati');
    }
    await repository.setReminderTime(hour: hour, minute: minute);
    _settings = _settings.copyWith(reminderHour: hour, reminderMinute: minute);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemePreference themeMode) async {
    await repository.setThemeMode(themeMode);
    _settings = _settings.copyWith(themeMode: themeMode);
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (_settings.onboardingCompleted) return;
    if (repository case final OnboardingSettingsStore store) {
      await store.setOnboardingCompleted(true);
    }
    _settings = _settings.copyWith(onboardingCompleted: true);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    await repository.resetToDefaults();
    _settings = AppSettings.defaults;
    notifyListeners();
  }

  Future<void> reload() => initialize();

  Future<int> refreshActiveDailyGoal() async {
    final goal = await repository.resolveDailyGoalForDate(
      dateKey: localDateKey(_now()),
      selectedDailyGoal: _settings.dailyGoal,
    );
    if (_activeDailyGoal != goal) {
      _activeDailyGoal = goal;
      notifyListeners();
    }
    return goal;
  }
}
