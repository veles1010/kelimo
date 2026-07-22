import 'package:flutter/foundation.dart';
import 'package:kelimo/repositories/data_reset_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/services/category_access_service.dart';
import 'package:kelimo/services/rewarded_bonus_service.dart';

class DataManagementService extends ChangeNotifier {
  DataManagementService({
    required this.repository,
    required this.wordProgressStore,
    required this.quizStore,
    required this.streakService,
    required this.xpService,
    required this.settingsService,
    required this.statisticsService,
    this.achievementService,
    this.dailyReminderService,
    this.categoryAccessService,
    this.rewardedBonusService,
  });

  final DataResetStore repository;
  final WordProgressStore wordProgressStore;
  final QuizStore quizStore;
  final StreakService streakService;
  final XpService xpService;
  final SettingsService settingsService;
  final StatisticsService statisticsService;
  final AchievementService? achievementService;
  final DailyReminderService? dailyReminderService;
  final CategoryAccessService? categoryAccessService;
  final RewardedBonusService? rewardedBonusService;

  Future<void> resetLearningData() => _reset(resetSettings: false);

  Future<void> resetAllData() => _reset(resetSettings: true);

  Future<void> _reset({required bool resetSettings}) async {
    await repository.resetLearningData(resetSettings: resetSettings);
    wordProgressStore.clearCachedData();
    quizStore.clearCachedData();
    streakService.resetAfterDataClear();
    xpService.resetAfterDataClear();
    achievementService?.resetAfterDataClear();
    await categoryAccessService?.resetAfterDataClear();
    rewardedBonusService?.resetAfterDataClear();
    if (resetSettings) await settingsService.reload();
    await statisticsService.refresh();
    if (resetSettings) {
      await dailyReminderService?.resetAllNotifications();
    } else {
      await dailyReminderService?.refreshSchedule();
    }
    notifyListeners();
  }
}
