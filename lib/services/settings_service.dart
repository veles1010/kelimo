import 'package:flutter/foundation.dart';
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
