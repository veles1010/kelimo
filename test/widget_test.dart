import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimo/data/animal_words.dart';
import 'package:kelimo/data/achievement_catalog.dart';
import 'package:kelimo/data/category_catalog.dart';
import 'package:kelimo/data/color_words.dart';
import 'package:kelimo/data/family_words.dart';
import 'package:kelimo/data/food_words.dart';
import 'package:kelimo/data/home_words.dart';
import 'package:kelimo/data/transportation_words.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/main.dart';
import 'package:kelimo/models/daily_progress.dart';
import 'package:kelimo/models/achievement.dart';
import 'package:kelimo/models/app_settings.dart';
import 'package:kelimo/models/learning_category.dart';
import 'package:kelimo/models/learning_center.dart';
import 'package:kelimo/models/progress_statistics.dart';
import 'package:kelimo/models/quiz_attempt.dart';
import 'package:kelimo/models/word.dart';
import 'package:kelimo/models/word_progress.dart';
import 'package:kelimo/models/xp_state.dart';
import 'package:kelimo/models/ad_display_state.dart';
import 'package:kelimo/repositories/daily_progress_repository.dart';
import 'package:kelimo/repositories/achievement_repository.dart';
import 'package:kelimo/repositories/data_reset_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/settings_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/screens/quiz_result_screen.dart';
import 'package:kelimo/screens/about_screen.dart';
import 'package:kelimo/screens/category_quiz_screen.dart';
import 'package:kelimo/screens/category_screen.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/screens/learning_center_screen.dart';
import 'package:kelimo/screens/learning_word_list_screen.dart';
import 'package:kelimo/screens/settings_screen.dart';
import 'package:kelimo/screens/privacy_center_screen.dart';
import 'package:kelimo/screens/word_card_screen.dart';
import 'package:kelimo/services/english_tts_service.dart';
import 'package:kelimo/services/app_info_provider.dart';
import 'package:kelimo/services/data_management_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/app_navigation_controller.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/learning_engine.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/notification_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';
import 'package:kelimo/theme/app_theme.dart';
import 'package:kelimo/utils/turkish_case.dart';
import 'package:kelimo/widgets/scale_down_single_line_text.dart';

class NoShuffleRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => max - 1;
}

class FakeAppInfoProvider implements AppInfoProvider {
  FakeAppInfoProvider({this.version = '2.3.4', this.buildNumber = '56'});

  final String version;
  final String buildNumber;

  @override
  Future<AppVersionInfo> load() async {
    return AppVersionInfo(version: version, buildNumber: buildNumber);
  }
}

class FakeTtsEngine implements TtsEngine {
  String? language;
  double? speechRate;
  double? volume;
  double? pitch;
  final spokenTexts = <String>[];
  int stopCallCount = 0;
  Completer<bool>? speakCompleter;
  bool failOnSpeak = false;

  @override
  Future<void> configure({
    required String language,
    required double speechRate,
    required double volume,
    required double pitch,
  }) async {
    this.language = language;
    this.speechRate = speechRate;
    this.volume = volume;
    this.pitch = pitch;
  }

  @override
  Future<bool> speak(String text) {
    spokenTexts.add(text);
    if (failOnSpeak) throw StateError('TTS unavailable');
    return speakCompleter?.future ?? Future.value(true);
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }
}

class FakeNotificationService implements NotificationService {
  NotificationPermissionStatus status = NotificationPermissionStatus.granted;
  NotificationPermissionStatus requestResult =
      NotificationPermissionStatus.granted;
  String? launchPayload;
  int initializeCalls = 0;
  int requestCalls = 0;
  int cancelCalls = 0;
  int cancelTestCalls = 0;
  int scheduleCalls = 0;
  int testScheduleCalls = 0;
  bool failTestScheduling = false;
  final schedules =
      <({int hour, int minute, String title, String body, String payload})>[];
  final testSchedules =
      <({String title, String body, String payload, Duration delay})>[];
  final StreamController<String> controller = StreamController.broadcast();

  @override
  Stream<String> get payloads => controller.stream;

  @override
  Future<void> cancelDailyReminder() async {
    cancelCalls++;
    schedules.clear();
  }

  @override
  Future<void> cancelTestNotification() async {
    cancelTestCalls++;
    testSchedules.clear();
  }

  @override
  Future<void> cancelAllReminders() async {
    await cancelDailyReminder();
    await cancelTestNotification();
  }

  @override
  void dispose() => controller.close();

  @override
  Future<String?> getLaunchPayload() async => launchPayload;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<NotificationPermissionStatus> notificationPermissionStatus() async =>
      status;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestCalls++;
    status = requestResult;
    return requestResult;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduleCalls++;
    await cancelDailyReminder();
    schedules
      ..clear()
      ..add((
        hour: hour,
        minute: minute,
        title: title,
        body: body,
        payload: payload,
      ));
  }

  @override
  Future<void> scheduleTestNotification({
    required String title,
    required String body,
    required String payload,
    Duration delay = const Duration(seconds: 10),
  }) async {
    testScheduleCalls++;
    if (failTestScheduling) throw StateError('notification unavailable');
    await cancelTestNotification();
    testSchedules.add((
      title: title,
      body: body,
      payload: payload,
      delay: delay,
    ));
  }

  void sendPayload(String payload) => controller.add(payload);
}

class FakeInterstitialStorage {
  AdDisplayState state = AdDisplayState.initial;
}

class FakeInterstitialAdService extends InterstitialAdService {
  FakeInterstitialAdService({
    FakeInterstitialStorage? storage,
    DateTime Function()? now,
    this.consentAllowed = true,
    this.adReady = true,
    this.privacyRequired = true,
  }) : storage = storage ?? FakeInterstitialStorage(),
       now = now ?? DateTime.now;

  final FakeInterstitialStorage storage;
  final DateTime Function() now;
  bool consentAllowed;
  bool adReady;
  bool privacyRequired;
  bool foreground = true;
  bool showSucceeds = true;
  int initializeCalls = 0;
  int consentCalls = 0;
  int preloadCalls = 0;
  int showCalls = 0;
  int testShowCalls = 0;
  int privacyCalls = 0;
  final policy = const InterstitialAdPolicy();

  @override
  bool get privacyOptionsRequired => privacyRequired;

  @override
  bool get canShow => policy.isEligible(
    state: storage.state,
    now: now(),
    isForeground: foreground,
    canRequestAds: consentAllowed,
    isAdReady: adReady,
  );

  @override
  Future<void> initialize() async {
    initializeCalls++;
    await requestConsentIfNeeded();
  }

  @override
  Future<void> requestConsentIfNeeded() async {
    consentCalls++;
    if (consentAllowed) await preload();
  }

  @override
  Future<void> preload() async {
    preloadCalls++;
  }

  @override
  Future<void> recordQuizCompleted() async {
    storage.state = AdDisplayState(
      completedQuizCountSinceLastAd:
          storage.state.completedQuizCountSinceLastAd + 1,
      lastInterstitialShownAt: storage.state.lastInterstitialShownAt,
    );
    notifyListeners();
  }

  @override
  Future<bool> showIfEligible() async {
    showCalls++;
    if (!canShow || !showSucceeds) return false;
    storage.state = AdDisplayState(
      completedQuizCountSinceLastAd: 0,
      lastInterstitialShownAt: now().toUtc(),
    );
    notifyListeners();
    return true;
  }

  @override
  Future<bool> showTestAd() async {
    testShowCalls++;
    return consentAllowed && foreground && adReady && showSucceeds;
  }

  @override
  Future<bool> showPrivacyOptions() async {
    privacyCalls++;
    return true;
  }

  @override
  void setForeground(bool isForeground) {
    foreground = isForeground;
    notifyListeners();
  }
}

class FakeWordProgressStore implements WordProgressStore {
  FakeWordProgressStore([Map<String, WordProgress>? records])
    : records = records ?? {};

  final Map<String, WordProgress> records;

  @override
  Future<void> initialize() async {}

  @override
  List<WordProgress> getAllProgress() => List.unmodifiable(records.values);

  @override
  WordProgress progressFor(String wordId) {
    return records[wordId] ?? WordProgress.initial(wordId);
  }

  @override
  Future<void> saveProgress(WordProgress progress) async {
    records[progress.wordId] = progress;
  }

  @override
  Future<WordProgress> saveFavorite(String wordId, bool isFavorite) async {
    final progress = progressFor(
      wordId,
    ).copyWith(isFavorite: isFavorite, updatedAt: DateTime.now());
    await saveProgress(progress);
    return progress;
  }

  @override
  Future<WordProgress> saveLearningResult(
    LearningReviewResult result, {
    DateTime? reviewedAt,
  }) async {
    final current = progressFor(result.word.id);
    final progress = wordProgressAfterLearningResult(
      current,
      result,
      reviewedAt: reviewedAt,
    );
    await saveProgress(progress);
    return progress;
  }

  @override
  Future<void> resetProgress(String wordId) async {
    records.remove(wordId);
  }

  @override
  void clearCachedData() => records.clear();
}

WordProgress testWordProgress({
  required String wordId,
  String mastery = 'new',
  int repetitionCount = 0,
  bool isFavorite = false,
  int reviewStage = 0,
  DateTime? nextReviewAt,
}) {
  final now = DateTime.parse('2026-07-14T12:00:00.000');
  return WordProgress(
    wordId: wordId,
    isFavorite: isFavorite,
    mastery: mastery,
    repetitionCount: repetitionCount,
    correctCount: mastery == 'easy' ? 1 : 0,
    wrongCount: mastery == 'again' || mastery == 'hard' ? 1 : 0,
    lastReviewedAt: repetitionCount > 0 ? now : null,
    nextReviewAt:
        nextReviewAt ??
        ((mastery == 'again' || mastery == 'hard') ? now : null),
    updatedAt: now,
    reviewStage: reviewStage,
  );
}

class FakeDailyStorage {
  final Map<String, DailyProgress> dailyProgress = {};
  StreakState streak = const StreakState(currentStreak: 7);
}

class FakeDailyProgressStore implements DailyProgressStore {
  FakeDailyProgressStore([FakeDailyStorage? storage])
    : storage = storage ?? FakeDailyStorage();

  final FakeDailyStorage storage;

  @override
  Future<DailyProgressSnapshot> loadToday({
    int initialStreak = 7,
    DateTime? now,
  }) async {
    final dateKey = localDateKey(now ?? DateTime.now());
    return DailyProgressSnapshot(
      progress:
          storage.dailyProgress[dateKey] ?? DailyProgress.initial(dateKey),
      streak: storage.streak,
    );
  }

  @override
  Future<DailyProgressSnapshot> incrementReview({
    required int dailyGoal,
    int initialStreak = 7,
    DateTime? now,
  }) async {
    final date = (now ?? DateTime.now()).toLocal();
    final dateKey = localDateKey(date);
    final current =
        storage.dailyProgress[dateKey] ?? DailyProgress.initial(dateKey);
    final reviewCount = current.reviewCount + 1;
    final justCompleted = !current.isGoalCompleted && reviewCount >= dailyGoal;
    final progress = DailyProgress(
      dateKey: dateKey,
      reviewCount: reviewCount,
      isGoalCompleted: current.isGoalCompleted || justCompleted,
      streakAwarded: current.streakAwarded || justCompleted,
    );
    storage.dailyProgress[dateKey] = progress;
    if (justCompleted) {
      storage.streak = StreakState(
        currentStreak: storage.streak.currentStreak + 1,
        lastCompletedDate: DateTime(date.year, date.month, date.day),
      );
    }
    return DailyProgressSnapshot(
      progress: progress,
      streak: storage.streak,
      justCompleted: justCompleted,
    );
  }

  @override
  Future<void> saveStreak(StreakState streak) async {
    storage.streak = streak;
  }
}

class FakeXpStorage {
  FakeXpStorage({int totalXp = 0})
    : state = XpState(totalXp: totalXp, updatedAt: DateTime.now());

  XpState state;
}

class FakeXpStore implements XpStore {
  FakeXpStore([FakeXpStorage? storage]) : storage = storage ?? FakeXpStorage();

  final FakeXpStorage storage;

  @override
  int get currentTotalXp => storage.state.totalXp;

  @override
  void synchronizeState(XpState state) {
    storage.state = state;
  }

  @override
  Future<XpState> loadState() async => storage.state;

  @override
  Future<XpState> addXp(int amount) async {
    if (amount <= 0) throw ArgumentError.value(amount);
    storage.state = XpState(
      totalXp: storage.state.totalXp + amount,
      updatedAt: DateTime.now(),
    );
    return storage.state;
  }

  @override
  Future<void> resetXp() async {
    storage.state = XpState.initial();
  }
}

class FakeQuizStorage {
  final List<QuizAttempt> attempts = [];
  int nextId = 1;
}

class FakeQuizStore implements QuizStore {
  FakeQuizStore(this.storage, this.xpStorage);

  final FakeQuizStorage storage;
  final FakeXpStorage xpStorage;

  @override
  Future<QuizCompletion> saveCompletedQuiz({
    required String categoryId,
    required int correctCount,
    required int totalQuestions,
    required int scorePercent,
    DateTime? completedAt,
  }) async {
    final xpAwarded = quizXpForScore(scorePercent);
    final attempt = QuizAttempt(
      id: storage.nextId++,
      categoryId: categoryId,
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      scorePercent: scorePercent,
      completedAt: completedAt ?? DateTime.now(),
      xpAwarded: xpAwarded,
    );
    final xpState = XpState(
      totalXp: xpStorage.state.totalXp + xpAwarded,
      updatedAt: DateTime.now(),
    );
    storage.attempts.add(attempt);
    xpStorage.state = xpState;
    return QuizCompletion(attempt: attempt, xpState: xpState);
  }

  @override
  Future<List<QuizAttempt>> getAllAttempts() async {
    return List.unmodifiable(storage.attempts.reversed);
  }

  @override
  Future<List<QuizAttempt>> getAttemptsByCategory(String categoryId) async {
    return storage.attempts
        .where((attempt) => attempt.categoryId == categoryId)
        .toList()
        .reversed
        .toList(growable: false);
  }

  @override
  Future<int> getHighestScore(String categoryId) async {
    final scores = storage.attempts
        .where((attempt) => attempt.categoryId == categoryId)
        .map((attempt) => attempt.scorePercent);
    return scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
  }

  @override
  Future<int> getTotalQuizCount() async => storage.attempts.length;

  @override
  Future<QuizStatistics> getStatistics() async {
    final totalCorrect = storage.attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.correctCount,
    );
    final totalQuestions = storage.attempts.fold<int>(
      0,
      (total, attempt) => total + attempt.totalQuestions,
    );
    final categories = storage.attempts
        .map((attempt) => attempt.categoryId)
        .toSet();
    return QuizStatistics(
      totalQuizCount: storage.attempts.length,
      totalCorrectCount: totalCorrect,
      totalQuestionCount: totalQuestions,
      generalSuccessPercentage: totalQuestions == 0
          ? 0
          : ((totalCorrect / totalQuestions) * 100).round(),
      highestScoreByCategory: {
        for (final category in categories)
          category: await getHighestScore(category),
      },
    );
  }

  @override
  void clearCachedData() => storage.attempts.clear();
}

class FakeSettingsStorage {
  final Map<String, String> values = {};
}

class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore([FakeSettingsStorage? storage])
    : storage = storage ?? FakeSettingsStorage();

  final FakeSettingsStorage storage;

  @override
  Future<AppSettings> load() async {
    return AppSettings(
      dailyGoal: AppSettings.safeDailyGoal(
        storage.values[SettingsRepository.dailyGoalKey],
      ),
      speechRate: SpeechRatePreference.fromStorage(
        storage.values[SettingsRepository.speechRateKey],
      ),
      reminderEnabled: AppSettings.safeReminderEnabled(
        storage.values[SettingsRepository.reminderEnabledKey],
      ),
      reminderHour: AppSettings.safeReminderHour(
        storage.values[SettingsRepository.reminderHourKey],
      ),
      reminderMinute: AppSettings.safeReminderMinute(
        storage.values[SettingsRepository.reminderMinuteKey],
      ),
      themeMode: ThemePreference.fromStorage(
        storage.values[SettingsRepository.themeModeKey],
      ),
    );
  }

  @override
  Future<int> resolveDailyGoalForDate({
    required String dateKey,
    required int selectedDailyGoal,
  }) async {
    if (storage.values[SettingsRepository.activeDailyGoalDateKey] == dateKey) {
      return AppSettings.safeDailyGoal(
        storage.values[SettingsRepository.activeDailyGoalKey],
      );
    }
    storage.values[SettingsRepository.activeDailyGoalDateKey] = dateKey;
    storage.values[SettingsRepository.activeDailyGoalKey] =
        '$selectedDailyGoal';
    return selectedDailyGoal;
  }

  @override
  Future<void> resetToDefaults() async {
    storage.values[SettingsRepository.dailyGoalKey] =
        '${AppSettings.defaults.dailyGoal}';
    storage.values[SettingsRepository.speechRateKey] =
        AppSettings.defaults.speechRate.storageValue;
    storage.values[SettingsRepository.reminderEnabledKey] =
        '${AppSettings.defaults.reminderEnabled}';
    storage.values[SettingsRepository.reminderHourKey] =
        '${AppSettings.defaults.reminderHour}';
    storage.values[SettingsRepository.reminderMinuteKey] =
        '${AppSettings.defaults.reminderMinute}';
    storage.values[SettingsRepository.themeModeKey] =
        AppSettings.defaults.themeMode.storageValue;
  }

  @override
  Future<void> setDailyGoal(int dailyGoal) async {
    if (!AppSettings.allowedDailyGoals.contains(dailyGoal)) {
      throw ArgumentError.value(dailyGoal, 'dailyGoal');
    }
    storage.values[SettingsRepository.dailyGoalKey] = '$dailyGoal';
  }

  @override
  Future<void> setSpeechRate(SpeechRatePreference speechRate) async {
    storage.values[SettingsRepository.speechRateKey] = speechRate.storageValue;
  }

  @override
  Future<void> setReminderEnabled(bool enabled) async {
    storage.values[SettingsRepository.reminderEnabledKey] = '$enabled';
  }

  @override
  Future<void> setReminderTime({required int hour, required int minute}) async {
    storage.values[SettingsRepository.reminderHourKey] = '$hour';
    storage.values[SettingsRepository.reminderMinuteKey] = '$minute';
  }

  @override
  Future<void> setThemeMode(ThemePreference themeMode) async {
    storage.values[SettingsRepository.themeModeKey] = themeMode.storageValue;
  }
}

class FakeDataResetStore implements DataResetStore {
  FakeDataResetStore({this.onReset});

  final void Function(bool resetSettings)? onReset;
  final calls = <bool>[];

  @override
  Future<void> resetLearningData({required bool resetSettings}) async {
    calls.add(resetSettings);
    onReset?.call(resetSettings);
  }
}

class FakeAchievementStore implements AchievementStore {
  FakeAchievementStore([Iterable<AchievementUnlock> initial = const []]) {
    for (final unlock in initial) {
      records[unlock.achievementId] = unlock;
    }
  }

  final Map<String, AchievementUnlock> records = {};

  @override
  Future<void> clearAll() async => records.clear();

  @override
  void clearCachedData() => records.clear();

  @override
  bool isUnlocked(String id) => records.containsKey(id);

  @override
  Future<List<AchievementUnlock>> loadUnlocked() async =>
      List.unmodifiable(records.values);

  @override
  Future<bool> unlock(String id, DateTime unlockedAt) async {
    if (records.containsKey(id)) return false;
    records[id] = AchievementUnlock(
      achievementId: id,
      unlockedAt: unlockedAt.toUtc(),
    );
    return true;
  }
}

Future<XpService> createXpService({
  int totalXp = 0,
  XpStore? repository,
}) async {
  final service = XpService(
    repository: repository ?? FakeXpStore(FakeXpStorage(totalXp: totalXp)),
  );
  await service.initialize();
  return service;
}

Future<SettingsService> createSettingsService({
  SettingsStore? repository,
  DateTime Function()? now,
}) async {
  final service = SettingsService(
    repository: repository ?? FakeSettingsStore(),
    now: now,
  );
  await service.initialize();
  return service;
}

DataManagementService createDataManagementService({
  required WordProgressStore wordProgressStore,
  required QuizStore quizStore,
  required StreakService streakService,
  required XpService xpService,
  required SettingsService settingsService,
  required StatisticsService statisticsService,
  AchievementService? achievementService,
  DailyReminderService? dailyReminderService,
  DataResetStore? repository,
}) {
  return DataManagementService(
    repository: repository ?? FakeDataResetStore(),
    wordProgressStore: wordProgressStore,
    quizStore: quizStore,
    streakService: streakService,
    xpService: xpService,
    settingsService: settingsService,
    statisticsService: statisticsService,
    achievementService: achievementService,
    dailyReminderService: dailyReminderService,
  );
}

Future<({HomeScreen screen, SettingsService settingsService})>
createTestHomeScreen({
  required StreakService streakService,
  required XpService xpService,
  required StatisticsService statisticsService,
  WordProgressStore? wordProgressStore,
  QuizStore? quizStore,
}) async {
  final settingsService = await createSettingsService();
  final words = wordProgressStore ?? FakeWordProgressStore();
  final quizzes =
      quizStore ?? FakeQuizStore(FakeQuizStorage(), FakeXpStorage());
  final dataManagementService = createDataManagementService(
    wordProgressStore: words,
    quizStore: quizzes,
    streakService: streakService,
    xpService: xpService,
    settingsService: settingsService,
    statisticsService: statisticsService,
  );
  return (
    screen: HomeScreen(
      streakService: streakService,
      wordProgressStore: words,
      xpService: xpService,
      quizStore: quizzes,
      statisticsService: statisticsService,
      settingsService: settingsService,
      dataManagementService: dataManagementService,
    ),
    settingsService: settingsService,
  );
}

StatisticsService createStatisticsService({
  required StreakService streakService,
  required XpService xpService,
  WordProgressStore? wordProgressStore,
  QuizStore? quizStore,
}) {
  return StatisticsService(
    wordProgressStore: wordProgressStore ?? FakeWordProgressStore(),
    quizStore: quizStore ?? FakeQuizStore(FakeQuizStorage(), FakeXpStorage()),
    streakService: streakService,
    xpService: xpService,
  );
}

Future<void> pumpKelimoApp(
  WidgetTester tester, {
  FakeXpStorage? xpStorage,
  FakeQuizStorage? quizStorage,
  WordProgressStore? wordProgressStore,
  FakeSettingsStorage? settingsStorage,
  DataResetStore? dataResetStore,
  AchievementStore? achievementStore,
  NotificationService? notificationService,
  AppNavigationController? navigationController,
  InterstitialAdService? interstitialAdService,
}) async {
  final sharedXpStorage = xpStorage ?? FakeXpStorage();
  final notifications = notificationService ?? FakeNotificationService();
  if (notificationService == null) addTearDown(notifications.dispose);
  final ads = interstitialAdService ?? FakeInterstitialAdService();
  if (interstitialAdService == null) addTearDown(ads.dispose);
  await tester.pumpWidget(
    KelimoApp(
      wordProgressStore: wordProgressStore ?? FakeWordProgressStore(),
      dailyProgressStore: FakeDailyProgressStore(),
      xpStore: FakeXpStore(sharedXpStorage),
      quizStore: FakeQuizStore(
        quizStorage ?? FakeQuizStorage(),
        sharedXpStorage,
      ),
      settingsStore: FakeSettingsStore(settingsStorage),
      dataResetStore: dataResetStore ?? FakeDataResetStore(),
      achievementStore:
          achievementStore ??
          FakeAchievementStore(
            AchievementCatalog.achievements.map(
              (achievement) => AchievementUnlock(
                achievementId: achievement.id,
                unlockedAt: DateTime.utc(2026, 7, 16),
              ),
            ),
          ),
      notificationService: notifications,
      navigationController: navigationController,
      interstitialAdService: ads,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openAnimalsCategory(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Hayvanlar'), 300);
  await tester.tap(find.text('Hayvanlar'));
  await tester.pumpAndSettle();
}

Future<void> openFoodsCategory(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Yiyecekler'), 300);
  await tester.tap(find.text('Yiyecekler'));
  await tester.pumpAndSettle();
}

Future<void> openColorsCategory(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Renkler'), 300);
  await tester.tap(find.text('Renkler'));
  await tester.pumpAndSettle();
}

Future<void> openHomeCategory(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Ev'), 300);
  await tester.tap(find.text('Ev'));
  await tester.pumpAndSettle();
}

Future<void> openFamilyCategory(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Aile'), 300);
  await tester.tap(find.text('Aile'));
  await tester.pumpAndSettle();
}

Future<void> openTransportationCategory(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Ulaşım'), 300);
  await tester.tap(find.text('Ulaşım'));
  await tester.pumpAndSettle();
}

Future<void> openLearningCenter(WidgetTester tester) async {
  await tester.tap(find.text('Öğren'));
  await tester.pumpAndSettle();
}

Future<void> pumpLearningSession(WidgetTester tester) async {
  final service = EnglishTtsService(engine: FakeTtsEngine());
  final xpService = await createXpService();
  await tester.pumpWidget(
    MaterialApp(
      home: WordCardScreen(
        category: CategoryCatalog.animals,
        wordProgressStore: FakeWordProgressStore(),
        xpService: xpService,
        ttsService: service,
      ),
    ),
  );
  await tester.ensureVisible(find.text('Kolay'));
  await tester.pumpAndSettle();
}

Future<void> selectLearningRating(WidgetTester tester, String rating) async {
  await tester.ensureVisible(find.text(rating));
  await tester.tap(find.text(rating));
  await tester.pumpAndSettle();
}

Word currentQuizWord(WidgetTester tester, List<Word> words) {
  return words.firstWhere(
    (word) =>
        find.byKey(ValueKey('quiz-question-${word.id}')).evaluate().isNotEmpty,
  );
}

String visibleWrongQuizAnswer(
  WidgetTester tester,
  List<Word> words,
  String correctAnswer,
) {
  return words
      .map((word) => word.turkish)
      .where((answer) => answer != correctAnswer)
      .firstWhere(
        (answer) =>
            find.byKey(ValueKey('quiz-option-$answer')).evaluate().isNotEmpty,
      );
}

Future<void> completeQuiz(
  WidgetTester tester, {
  bool perfect = true,
  List<Word> words = animalWords,
  List<bool>? answerPattern,
  void Function(int questionIndex)? beforeAnswer,
}) async {
  for (var index = 0; index < 10; index++) {
    beforeAnswer?.call(index);
    final isCorrect = answerPattern?[index] ?? (perfect || index != 0);
    final currentWord = currentQuizWord(tester, words);
    final answer = isCorrect
        ? currentWord.turkish
        : visibleWrongQuizAnswer(tester, words, currentWord.turkish);
    final option = find.byKey(ValueKey('quiz-option-$answer'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pump();

    final buttonLabel = index == 9 ? 'Sonucu Gör' : 'Sonraki Soru';
    await tester.ensureVisible(find.text(buttonLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(buttonLabel));
    await tester.pumpAndSettle();
  }
}

void main() {
  test('LearningEngine sonraki ve önceki kelimeyi yönetir', () {
    final engine = LearningEngine(animalWords);

    expect(engine.currentWord.english, 'Dog');
    expect(engine.canPrevious, isFalse);
    expect(engine.nextWord().english, 'Cat');
    expect(engine.canPrevious, isTrue);
    expect(engine.previousWord().english, 'Dog');
  });

  test('LearningEngine seçilen kategori indeksinden başlar', () {
    final engine = LearningEngine(animalWords, initialWordIndex: 4);

    expect(engine.currentWord.english, 'Horse');
    expect(engine.currentWordNumber, 5);
    expect(engine.nextWord().english, 'Cow');
  });

  test('LearningEngine Kolay kelimeyi dokuz kart sonra getirir', () {
    final engine = LearningEngine(animalWords);

    expect(engine.rateEasy().english, 'Cat');
    for (final english in [
      'Bird',
      'Fish',
      'Horse',
      'Cow',
      'Sheep',
      'Goat',
      'Duck',
      'Chicken',
      'Dog',
    ]) {
      expect(engine.rateEasy().english, english);
    }
  });

  test('LearningEngine Tekrar Et kelimesini iki kart sonra getirir', () {
    final engine = LearningEngine(animalWords);

    expect(engine.rateAgain().english, 'Cat');
    expect(engine.rateEasy().english, 'Bird');
    expect(engine.rateEasy().english, 'Dog');
  });

  test('LearningEngine Zor kelimeyi bir kart sonra getirir', () {
    final engine = LearningEngine(animalWords);

    expect(engine.rateHard().english, 'Cat');
    expect(engine.rateEasy().english, 'Dog');
  });

  test('LearningEngine yalnızca tüm kelimeler Kolay olunca tamamlanır', () {
    final engine = LearningEngine(animalWords);
    Word? previousWord;
    var evaluationCount = 0;

    while (!engine.isComplete && evaluationCount < 100) {
      expect(engine.currentWord, isNot(same(previousWord)));
      previousWord = engine.currentWord;
      engine.rateEasy();
      evaluationCount++;
    }

    expect(engine.isComplete, isTrue);
    expect(evaluationCount, 60);
    expect(engine.canNext, isFalse);
    expect(engine.canPrevious, isFalse);
  });

  test('Word progress toMap ve fromMap değerleri korur', () {
    final reviewedAt = DateTime.parse('2026-07-14T10:30:00.000');
    final nextReviewAt = DateTime.parse('2026-07-15T10:30:00.000');
    final progress = WordProgress(
      wordId: 'dog',
      isFavorite: true,
      mastery: 'hard',
      repetitionCount: 3,
      correctCount: 1,
      wrongCount: 2,
      lastReviewedAt: reviewedAt,
      nextReviewAt: nextReviewAt,
      updatedAt: reviewedAt,
      reviewStage: 2,
    );

    final restored = WordProgress.fromMap(progress.toMap());

    expect(restored.wordId, 'dog');
    expect(restored.isFavorite, isTrue);
    expect(restored.mastery, 'hard');
    expect(restored.repetitionCount, 3);
    expect(restored.correctCount, 1);
    expect(restored.wrongCount, 2);
    expect(restored.lastReviewedAt, reviewedAt.toUtc());
    expect(restored.nextReviewAt, nextReviewAt.toUtc());
    expect(restored.updatedAt, reviewedAt.toUtc());
    expect(restored.reviewStage, 2);
    expect(progress.toMap()['is_favorite'], 1);
    expect(progress.toMap()['review_stage'], 2);
    expect(progress.toMap()['next_review_at'], endsWith('Z'));
  });

  test('Günlük progress mapping bool değerlerini 0 ve 1 olarak saklar', () {
    const progress = DailyProgress(
      dateKey: '2026-07-14',
      reviewCount: 5,
      isGoalCompleted: true,
      streakAwarded: true,
    );

    final map = progress.toMap();
    final restored = DailyProgress.fromMap(map);

    expect(map['is_goal_completed'], 1);
    expect(map['streak_awarded'], 1);
    expect(restored.dateKey, '2026-07-14');
    expect(restored.reviewCount, 5);
    expect(restored.isGoalCompleted, isTrue);
    expect(restored.streakAwarded, isTrue);
  });

  test('XP modeli değerlerini SQLite map dönüşümünde korur', () {
    final updatedAt = DateTime.parse('2026-07-14T12:00:00.000');
    final state = XpState(totalXp: 1005, updatedAt: updatedAt);

    final restored = XpState.fromMap(state.toMap());

    expect(state.toMap()['id'], 1);
    expect(restored.totalXp, 1005);
    expect(restored.updatedAt, updatedAt);
  });

  test('Veritabanı şema sürümü başarımlar migration ile 6 olur', () {
    expect(DatabaseService.databaseVersion, 6);
    expect(
      DatabaseService.createAppSettingsTableSql,
      contains('CREATE TABLE IF NOT EXISTS app_settings'),
    );
    expect(
      DatabaseService.createAppSettingsTableSql,
      contains('key TEXT PRIMARY KEY'),
    );
    expect(
      DatabaseService.createAppSettingsTableSql,
      contains('value TEXT NOT NULL'),
    );
    expect(
      DatabaseService.createAppSettingsTableSql,
      contains('updated_at TEXT NOT NULL'),
    );
    expect(DatabaseService.createAppSettingsTableSql, isNot(contains('DROP')));
    expect(
      DatabaseService.createAppSettingsTableSql,
      isNot(contains('DELETE')),
    );
    expect(
      DatabaseService.addReviewStageColumnSql,
      contains('ALTER TABLE word_progress ADD COLUMN review_stage'),
    );
    expect(
      DatabaseService.addReviewStageColumnSql,
      contains('INTEGER NOT NULL DEFAULT 0'),
    );
    expect(
      DatabaseService.createAchievementUnlocksTableSql,
      contains('CREATE TABLE IF NOT EXISTS achievement_unlocks'),
    );
    expect(
      DatabaseService.createAchievementUnlocksTableSql,
      contains('achievement_id TEXT PRIMARY KEY'),
    );
    expect(
      DatabaseService.createAchievementUnlocksTableSql,
      contains('unlocked_at TEXT NOT NULL'),
    );
    expect(DataResetRepository.learningDataTables, [
      'word_progress',
      'daily_progress',
      'quiz_attempts',
      'streak_state',
      'xp_state',
      'achievement_unlocks',
    ]);
  });

  test(
    'Başarım metrikleri mevcut ilerleme, quiz ve seri verisini kullanır',
    () async {
      final wordStore = FakeWordProgressStore({
        animalWords[0].id: testWordProgress(
          wordId: animalWords[0].id,
          mastery: 'easy',
          repetitionCount: 3,
          isFavorite: true,
        ),
        foodWords[0].id: testWordProgress(
          wordId: foodWords[0].id,
          mastery: 'hard',
          repetitionCount: 2,
          isFavorite: true,
        ),
        'bilinmeyen_kelime': testWordProgress(
          wordId: 'bilinmeyen_kelime',
          mastery: 'easy',
          repetitionCount: 50,
          isFavorite: true,
        ),
      });
      final xpStorage = FakeXpStorage();
      final quizStorage = FakeQuizStorage();
      final quizStore = FakeQuizStore(quizStorage, xpStorage);
      await quizStore.saveCompletedQuiz(
        categoryId: 'animals',
        correctCount: 10,
        totalQuestions: 10,
        scorePercent: 100,
      );
      await quizStore.saveCompletedQuiz(
        categoryId: 'foods',
        correctCount: 9,
        totalQuestions: 10,
        scorePercent: 90,
      );
      final streak = StreakService(initialStreak: 7);
      addTearDown(streak.dispose);

      final metrics = await AchievementMetricsLoader(
        wordProgressStore: wordStore,
        quizStore: quizStore,
        streakService: streak,
      ).load();

      expect(metrics.totalReviewCount, 5);
      expect(metrics.learnedWordCount, 1);
      expect(metrics.favoriteWordCount, 2);
      expect(metrics.completedQuizCount, 2);
      expect(metrics.hasPerfectQuiz, isTrue);
      expect(metrics.currentStreak, 7);
    },
  );

  test(
    'Ayarlar güvenli varsayılanları ve izin verilen hedefleri kullanır',
    () async {
      final service = await createSettingsService();
      addTearDown(service.dispose);

      expect(service.dailyGoal, 5);
      expect(service.activeDailyGoal, 5);
      expect(service.speechRate, SpeechRatePreference.normal);
      expect(service.reminderEnabled, isFalse);
      expect(service.reminderHour, 20);
      expect(service.reminderMinute, 0);
      expect(service.themeMode, ThemePreference.system);
      expect(service.materialThemeMode, ThemeMode.system);
      expect(service.ttsSpeechRate, 0.42);
      expect(AppSettings.safeDailyGoal('10'), 10);
      expect(AppSettings.safeDailyGoal('7'), 5);
      expect(AppSettings.safeDailyGoal('bozuk'), 5);
      expect(() => service.setDailyGoal(7), throwsA(isA<ArgumentError>()));
      expect(AppSettings.safeReminderEnabled('bozuk'), isFalse);
      expect(AppSettings.safeReminderHour('24'), 20);
      expect(AppSettings.safeReminderMinute('60'), 0);
      expect(ThemePreference.fromStorage(null), ThemePreference.system);
      expect(ThemePreference.fromStorage('bozuk'), ThemePreference.system);
    },
  );

  test(
    'Tema tercihi kaydedilir, yeniden yüklenir ve anında bildirilir',
    () async {
      final storage = FakeSettingsStorage();
      final first = await createSettingsService(
        repository: FakeSettingsStore(storage),
      );
      var notificationCount = 0;
      first.addListener(() => notificationCount++);

      await first.setThemeMode(ThemePreference.dark);
      expect(first.themeMode, ThemePreference.dark);
      expect(first.materialThemeMode, ThemeMode.dark);
      expect(notificationCount, 1);
      expect(storage.values[SettingsRepository.themeModeKey], 'dark');
      first.dispose();

      final restored = await createSettingsService(
        repository: FakeSettingsStore(storage),
      );
      addTearDown(restored.dispose);
      expect(restored.themeMode, ThemePreference.dark);

      storage.values[SettingsRepository.themeModeKey] = 'desteklenmiyor';
      await restored.reload();
      expect(restored.themeMode, ThemePreference.system);
    },
  );

  test('Koyu tema ortak Material yüzeylerini tutarlı biçimde tanımlar', () {
    final theme = AppTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, isNot(theme.cardColor));
    expect(theme.dialogTheme.backgroundColor, isNotNull);
    expect(theme.bottomSheetTheme.modalBackgroundColor, isNotNull);
    expect(theme.navigationBarTheme.backgroundColor, theme.cardColor);
    expect(
      theme.navigationBarTheme.indicatorColor,
      theme.colorScheme.primaryContainer,
    );
    expect(theme.inputDecorationTheme.filled, isTrue);
    expect(theme.snackBarTheme.backgroundColor, isNotNull);
    expect(theme.dividerTheme.color, theme.colorScheme.outlineVariant);
    expect(theme.progressIndicatorTheme.color, theme.colorScheme.primary);
  });

  test(
    'Hatırlatıcı tercihleri repository yeniden oluşturulunca korunur',
    () async {
      final storage = FakeSettingsStorage();
      final first = await createSettingsService(
        repository: FakeSettingsStore(storage),
      );
      await first.setReminderEnabled(true);
      await first.setReminderTime(hour: 8, minute: 35);
      first.dispose();

      final restored = await createSettingsService(
        repository: FakeSettingsStore(storage),
      );
      addTearDown(restored.dispose);

      expect(restored.reminderEnabled, isTrue);
      expect(restored.reminderHour, 8);
      expect(restored.reminderMinute, 35);
      expect(storage.values[SettingsRepository.reminderEnabledKey], 'true');
      expect(storage.values[SettingsRepository.reminderHourKey], '8');
      expect(storage.values[SettingsRepository.reminderMinuteKey], '35');
      expect(DatabaseService.databaseVersion, 6);
    },
  );

  test('Consent verilmeden reklam preload edilmez', () async {
    final ads = FakeInterstitialAdService(consentAllowed: false);
    addTearDown(ads.dispose);

    await ads.initialize();

    expect(ads.consentCalls, 1);
    expect(ads.preloadCalls, 0);
  });

  test('Reklam sayacı ve cooldown servis yeniden açılınca korunur', () async {
    final storage = FakeInterstitialStorage();
    var now = DateTime.utc(2026, 7, 17, 12);
    final first = FakeInterstitialAdService(storage: storage, now: () => now);
    addTearDown(first.dispose);
    await first.initialize();
    await first.recordQuizCompleted();
    await first.recordQuizCompleted();
    expect(first.canShow, isFalse);
    await first.recordQuizCompleted();
    expect(first.canShow, isTrue);
    expect(await first.showIfEligible(), isTrue);
    expect(storage.state.completedQuizCountSinceLastAd, 0);

    final reopened = FakeInterstitialAdService(
      storage: storage,
      now: () => now,
    );
    addTearDown(reopened.dispose);
    await reopened.initialize();
    await reopened.recordQuizCompleted();
    await reopened.recordQuizCompleted();
    await reopened.recordQuizCompleted();
    expect(reopened.canShow, isFalse);
    now = now.add(const Duration(minutes: 15));
    expect(reopened.canShow, isTrue);
  });

  test('Hatırlatıcı açma, kapama ve saat değişimi tek planı korur', () async {
    final settings = await createSettingsService();
    final notifications = FakeNotificationService();
    final reminder = DailyReminderService(
      settingsService: settings,
      notificationService: notifications,
      learningCenterService: LearningCenterService(
        wordProgressStore: FakeWordProgressStore(),
      ),
    );
    addTearDown(settings.dispose);
    addTearDown(reminder.dispose);
    addTearDown(notifications.dispose);
    await reminder.initialize();

    expect(await reminder.setEnabled(true), ReminderUpdateResult.success);
    expect(settings.reminderEnabled, isTrue);
    expect(notifications.schedules, hasLength(1));
    expect(notifications.schedules.single.hour, 20);

    final cancelBeforeTimeChange = notifications.cancelCalls;
    expect(await reminder.setTime(hour: 9, minute: 25), isTrue);
    expect(notifications.cancelCalls, cancelBeforeTimeChange + 1);
    expect(notifications.schedules, hasLength(1));
    expect(notifications.schedules.single.hour, 9);
    expect(notifications.schedules.single.minute, 25);

    await Future.wait([reminder.refreshSchedule(), reminder.refreshSchedule()]);
    expect(notifications.schedules, hasLength(1));
    expect(await reminder.setEnabled(false), ReminderUpdateResult.success);
    expect(settings.reminderEnabled, isFalse);
    expect(notifications.schedules, isEmpty);
  });

  test(
    'Günlük ve test bildirimleri ayrı kimliklerle birbirini bozmaz',
    () async {
      final settings = await createSettingsService();
      final notifications = FakeNotificationService();
      final reminder = DailyReminderService(
        settingsService: settings,
        notificationService: notifications,
        learningCenterService: LearningCenterService(
          wordProgressStore: FakeWordProgressStore(),
        ),
      );
      addTearDown(settings.dispose);
      addTearDown(reminder.dispose);
      addTearDown(notifications.dispose);
      await reminder.initialize();

      expect(await reminder.setEnabled(true), ReminderUpdateResult.success);
      expect(
        await reminder.scheduleTestNotification(),
        ReminderUpdateResult.success,
      );
      expect(notifications.schedules, hasLength(1));
      expect(notifications.testSchedules, hasLength(1));
      expect(
        notifications.testSchedules.single.delay,
        const Duration(seconds: 10),
      );

      await reminder.scheduleTestNotification();
      expect(notifications.schedules, hasLength(1));
      expect(notifications.testSchedules, hasLength(1));
    },
  );

  test('İzin reddedilince hatırlatıcı kapalı kalır', () async {
    final settings = await createSettingsService();
    final notifications = FakeNotificationService()
      ..status = NotificationPermissionStatus.denied
      ..requestResult = NotificationPermissionStatus.denied;
    final reminder = DailyReminderService(
      settingsService: settings,
      notificationService: notifications,
      learningCenterService: LearningCenterService(
        wordProgressStore: FakeWordProgressStore(),
      ),
    );
    addTearDown(settings.dispose);
    addTearDown(reminder.dispose);
    addTearDown(notifications.dispose);
    await reminder.initialize();

    expect(
      await reminder.setEnabled(true),
      ReminderUpdateResult.permissionDenied,
    );
    expect(settings.reminderEnabled, isFalse);
    expect(notifications.requestCalls, 1);
    expect(notifications.schedules, isEmpty);
  });

  test(
    'Hatırlatıcı içeriği vadesi gelen tekrar durumuna göre değişir',
    () async {
      final settings = await createSettingsService();
      final notifications = FakeNotificationService();
      final store = FakeWordProgressStore({
        animalWords.first.id: testWordProgress(
          wordId: animalWords.first.id,
          mastery: 'again',
          repetitionCount: 1,
          nextReviewAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      });
      final reminder = DailyReminderService(
        settingsService: settings,
        notificationService: notifications,
        learningCenterService: LearningCenterService(wordProgressStore: store),
      );
      addTearDown(settings.dispose);
      addTearDown(reminder.dispose);
      addTearDown(notifications.dispose);
      await reminder.initialize();
      await reminder.setEnabled(true);

      expect(notifications.schedules.single.title, 'Tekrar zamanı!');
      expect(
        notifications.schedules.single.body,
        'Çalışma zamanı gelen kelimelerin seni bekliyor.',
      );
      expect(notifications.schedules.single.payload, 'daily_review');

      store.clearCachedData();
      await reminder.refreshSchedule();
      expect(
        notifications.schedules.single.title,
        'Bugünün kelimelerine hazır mısın?',
      );
    },
  );

  test(
    'Ayarlar yeniden oluşturulunca yüklenir ve bozuk değerler düzeltilir',
    () async {
      final storage = FakeSettingsStorage();
      final first = await createSettingsService(
        repository: FakeSettingsStore(storage),
      );
      await first.setDailyGoal(15);
      await first.setSpeechRate(SpeechRatePreference.fast);
      first.dispose();

      final recreated = await createSettingsService(
        repository: FakeSettingsStore(storage),
      );
      expect(recreated.dailyGoal, 15);
      expect(recreated.speechRate, SpeechRatePreference.fast);
      recreated.dispose();

      storage.values[SettingsRepository.dailyGoalKey] = '999';
      storage.values[SettingsRepository.speechRateKey] = 'çok_hızlı';
      storage.values[SettingsRepository.reminderEnabledKey] = 'bozuk';
      storage.values[SettingsRepository.reminderHourKey] = '99';
      storage.values[SettingsRepository.reminderMinuteKey] = '-1';
      final safe = await createSettingsService(
        repository: FakeSettingsStore(storage),
      );
      addTearDown(safe.dispose);
      expect(safe.dailyGoal, 5);
      expect(safe.speechRate, SpeechRatePreference.normal);
      expect(safe.reminderEnabled, isFalse);
      expect(safe.reminderHour, 20);
      expect(safe.reminderMinute, 0);
    },
  );

  test(
    'Yeni günlük hedef sonraki günde uygulanır ve seri iki kez artmaz',
    () async {
      var now = DateTime(2026, 7, 16, 10);
      final settings = await createSettingsService(
        repository: FakeSettingsStore(),
        now: () => now,
      );
      final dailyStorage = FakeDailyStorage();
      final streak = StreakService(
        repository: FakeDailyProgressStore(dailyStorage),
        settingsService: settings,
        now: () => now,
      );
      addTearDown(settings.dispose);
      addTearDown(streak.dispose);
      await streak.initialize();

      await settings.setDailyGoal(10);
      expect(settings.dailyGoal, 10);
      expect(streak.dailyGoal, 5);
      for (var index = 0; index < 5; index++) {
        await streak.recordEvaluation();
      }
      expect(streak.isTodayCompleted, isTrue);
      expect(streak.currentStreak, 8);
      expect(await streak.recordEvaluation(), isFalse);
      expect(streak.currentStreak, 8);

      now = DateTime(2026, 7, 17, 10);
      expect(await streak.recordEvaluation(), isFalse);
      expect(streak.dailyGoal, 10);
      expect(streak.todayCount, 1);
      expect(streak.remainingForToday, 9);
      expect(streak.currentStreak, 8);
    },
  );

  test('TTS hız tercihleri gerçek konuşma hızına uygulanır', () async {
    expect(SpeechRatePreference.slow.ttsRate, 0.35);
    expect(SpeechRatePreference.normal.ttsRate, 0.42);
    expect(SpeechRatePreference.fast.ttsRate, 0.65);

    final settings = await createSettingsService();
    addTearDown(settings.dispose);
    final engine = FakeTtsEngine();
    final tts = EnglishTtsService(engine: engine, settingsService: settings);
    addTearDown(tts.dispose);

    expect(await tts.speak('Hello'), isTrue);
    expect(engine.speechRate, 0.42);
    await settings.setSpeechRate(SpeechRatePreference.fast);
    expect(await tts.speak('Hello again'), isTrue);
    expect(engine.speechRate, 0.65);
  });

  test('Veri yönetimi tercih ve öğrenme sıfırlama sınırlarını korur', () async {
    final wordStore = FakeWordProgressStore({
      'dog': testWordProgress(
        wordId: 'dog',
        mastery: 'hard',
        repetitionCount: 1,
        isFavorite: true,
      ),
    });
    final xpStorage = FakeXpStorage();
    final xpService = await createXpService(repository: FakeXpStore(xpStorage));
    await xpService.addXp(5);
    final quizStorage = FakeQuizStorage();
    final quizStore = FakeQuizStore(quizStorage, xpStorage);
    await quizStore.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 8,
      totalQuestions: 10,
      scorePercent: 80,
    );
    final dailyStorage = FakeDailyStorage();
    final streak = StreakService(
      repository: FakeDailyProgressStore(dailyStorage),
    );
    await streak.initialize();
    await streak.recordEvaluation();
    final settingsStorage = FakeSettingsStorage();
    final settings = await createSettingsService(
      repository: FakeSettingsStore(settingsStorage),
    );
    await settings.setDailyGoal(10);
    await settings.setSpeechRate(SpeechRatePreference.fast);
    await settings.setThemeMode(ThemePreference.dark);
    final statistics = createStatisticsService(
      streakService: streak,
      xpService: xpService,
      wordProgressStore: wordStore,
      quizStore: quizStore,
    );
    final notificationService = FakeNotificationService();
    final reminderService = DailyReminderService(
      settingsService: settings,
      notificationService: notificationService,
      learningCenterService: LearningCenterService(
        wordProgressStore: wordStore,
      ),
    );
    await reminderService.initialize();
    await reminderService.setTime(hour: 8, minute: 15);
    await reminderService.setEnabled(true);
    final resetStore = FakeDataResetStore(
      onReset: (resetSettings) {
        dailyStorage.dailyProgress.clear();
        dailyStorage.streak = const StreakState(currentStreak: 0);
        if (resetSettings) settingsStorage.values.clear();
      },
    );
    final achievementStore = FakeAchievementStore([
      AchievementUnlock(
        achievementId: 'first_step',
        unlockedAt: DateTime.utc(2026, 7, 16),
      ),
    ]);
    final achievementService = AchievementService(
      repository: achievementStore,
      metricsLoader: AchievementMetricsLoader(
        wordProgressStore: wordStore,
        quizStore: quizStore,
        streakService: streak,
      ),
    );
    await achievementService.initialize();
    final dataManagement = createDataManagementService(
      repository: resetStore,
      wordProgressStore: wordStore,
      quizStore: quizStore,
      streakService: streak,
      xpService: xpService,
      settingsService: settings,
      statisticsService: statistics,
      achievementService: achievementService,
      dailyReminderService: reminderService,
    );
    addTearDown(wordStore.clearCachedData);
    addTearDown(streak.dispose);
    addTearDown(xpService.dispose);
    addTearDown(settings.dispose);
    addTearDown(statistics.dispose);
    addTearDown(dataManagement.dispose);
    addTearDown(achievementService.dispose);
    addTearDown(reminderService.dispose);
    addTearDown(notificationService.dispose);

    await reminderService.scheduleTestNotification();
    expect(notificationService.testSchedules, hasLength(1));
    await reminderService.resetPreferences();
    expect(settings.dailyGoal, 5);
    expect(settings.speechRate, SpeechRatePreference.normal);
    expect(wordStore.progressFor('dog').isFavorite, isTrue);
    expect(wordStore.progressFor('dog').nextReviewAt, isNotNull);
    expect(await quizStore.getTotalQuizCount(), 1);
    expect(xpService.totalXp, 5);
    expect(achievementService.isUnlocked('first_step'), isTrue);
    expect(settings.reminderEnabled, isFalse);
    expect(settings.reminderHour, 20);
    expect(settings.reminderMinute, 0);
    expect(settings.themeMode, ThemePreference.system);
    expect(notificationService.schedules, isEmpty);
    expect(notificationService.testSchedules, isEmpty);

    await settings.setDailyGoal(10);
    await settings.setThemeMode(ThemePreference.dark);
    await reminderService.setTime(hour: 8, minute: 15);
    await reminderService.setEnabled(true);
    await dataManagement.resetLearningData();
    expect(resetStore.calls, [false]);
    expect(settings.dailyGoal, 10);
    expect(wordStore.getAllProgress(), isEmpty);
    expect(wordStore.progressFor('dog').nextReviewAt, isNull);
    expect(await quizStore.getAllAttempts(), isEmpty);
    expect(xpService.totalXp, 0);
    expect(streak.todayCount, 0);
    expect(streak.currentStreak, 0);
    expect(achievementService.unlockedCount, 0);
    expect(settings.reminderEnabled, isTrue);
    expect(settings.reminderHour, 8);
    expect(settings.reminderMinute, 15);
    expect(settings.themeMode, ThemePreference.dark);
    expect(notificationService.schedules, hasLength(1));
    expect(
      notificationService.schedules.single.title,
      'Bugünün kelimelerine hazır mısın?',
    );
    final learning = LearningCenterService(wordProgressStore: wordStore).load();
    expect(learning.totalCount, 540);
    expect(learning.favoriteCount, 0);
    expect(learning.repeatPendingCount, 0);
    expect(learning.learnedCount, 0);

    await achievementStore.unlock('first_step', DateTime.utc(2026, 7, 16));
    await achievementService.initialize();
    expect(achievementService.unlockedCount, 1);
    await settings.setDailyGoal(20);
    await settings.setSpeechRate(SpeechRatePreference.slow);
    await reminderService.scheduleTestNotification();
    expect(notificationService.testSchedules, hasLength(1));
    await dataManagement.resetAllData();
    expect(resetStore.calls, [false, true]);
    expect(settings.dailyGoal, 5);
    expect(settings.speechRate, SpeechRatePreference.normal);
    expect(achievementService.unlockedCount, 0);
    expect(settings.reminderEnabled, isFalse);
    expect(settings.reminderHour, 20);
    expect(settings.reminderMinute, 0);
    expect(settings.themeMode, ThemePreference.system);
    expect(notificationService.schedules, isEmpty);
    expect(notificationService.testSchedules, isEmpty);
    expect(CategoryCatalog.categories, hasLength(18));
    expect(
      CategoryCatalog.categories.expand((category) => category.words),
      hasLength(540),
    );
  });

  test('QuizAttempt SQLite map dönüşümünde sonuç ve tarihi korur', () {
    final completedAt = DateTime.parse('2026-07-14T15:30:00.000');
    final attempt = QuizAttempt(
      id: 4,
      categoryId: 'animals',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
      completedAt: completedAt,
      xpAwarded: 25,
    );

    final restored = QuizAttempt.fromMap(attempt.toMap());

    expect(restored.id, 4);
    expect(restored.categoryId, 'animals');
    expect(restored.correctCount, 10);
    expect(restored.totalQuestions, 10);
    expect(restored.scorePercent, 100);
    expect(restored.completedAt, completedAt);
    expect(restored.xpAwarded, 25);
  });

  test('Kusursuz quiz +25 XP verir ve düşük sonuç XP vermez', () async {
    final xpStorage = FakeXpStorage(totalXp: 250);
    final quizStorage = FakeQuizStorage();
    final repository = FakeQuizStore(quizStorage, xpStorage);

    final perfect = await repository.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );
    final lowerScore = await repository.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 9,
      totalQuestions: 10,
      scorePercent: 90,
    );

    expect(perfect.attempt.xpAwarded, 25);
    expect(perfect.xpState.totalXp, 275);
    expect(lowerScore.attempt.xpAwarded, 0);
    expect(lowerScore.xpState.totalXp, 275);
    expect(quizStorage.attempts, hasLength(2));
    expect(quizStorage.attempts.last.scorePercent, 90);
  });

  test(
    'Quiz istatistik altyapısı toplamları ve en yüksek skoru hesaplar',
    () async {
      final repository = FakeQuizStore(FakeQuizStorage(), FakeXpStorage());
      await repository.saveCompletedQuiz(
        categoryId: 'animals',
        correctCount: 10,
        totalQuestions: 10,
        scorePercent: 100,
      );
      await repository.saveCompletedQuiz(
        categoryId: 'animals',
        correctCount: 7,
        totalQuestions: 10,
        scorePercent: 70,
      );
      await repository.saveCompletedQuiz(
        categoryId: 'foods',
        correctCount: 5,
        totalQuestions: 10,
        scorePercent: 50,
      );

      final statistics = await repository.getStatistics();

      expect(await repository.getTotalQuizCount(), 3);
      expect(await repository.getAllAttempts(), hasLength(3));
      expect(await repository.getHighestScore('animals'), 100);
      expect(await repository.getAttemptsByCategory('animals'), hasLength(2));
      expect(statistics.totalQuizCount, 3);
      expect(statistics.totalCorrectCount, 22);
      expect(statistics.totalQuestionCount, 30);
      expect(statistics.generalSuccessPercentage, 73);
      expect(statistics.highestScoreByCategory, {'animals': 100, 'foods': 50});
    },
  );

  test('Aynı kusursuz quiz tekrar tamamlanınca yeniden 25 XP verir', () async {
    final xpStorage = FakeXpStorage();
    final repository = FakeQuizStore(FakeQuizStorage(), xpStorage);

    await repository.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );
    await repository.saveCompletedQuiz(
      categoryId: 'animals',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );

    expect(xpStorage.state.totalXp, 50);
    expect(await repository.getTotalQuizCount(), 2);
  });

  test('Flashcard değerlendirmeleri doğru XP ödülünü üretir', () {
    expect(xpRewardForRating(LearningRating.easy), 5);
    expect(xpRewardForRating(LearningRating.again), 2);
    expect(xpRewardForRating(LearningRating.hard), 3);
  });

  test('XP servisi seviye sınırlarını ve progress değerini hesaplar', () async {
    final service = await createXpService();
    addTearDown(service.dispose);

    expect(service.totalXp, 0);
    expect(service.currentLevel, 1);
    expect(service.xpInCurrentLevel, 0);
    expect(service.xpRequiredForNextLevel, 1000);
    expect(service.progress, 0.0);
    expect(service.isLoading, isFalse);

    expect(await service.addXp(999), isTrue);
    expect(service.currentLevel, 1);
    expect(service.xpInCurrentLevel, 999);
    expect(service.progress, 0.999);

    expect(await service.addXp(1), isTrue);
    expect(service.totalXp, 1000);
    expect(service.currentLevel, 2);
    expect(service.xpInCurrentLevel, 0);
    expect(service.progress, 0.0);

    expect(await service.addXp(5), isTrue);
    expect(service.totalXp, 1005);
    expect(service.currentLevel, 2);
    expect(service.xpInCurrentLevel, 5);
    expect(service.progress, 0.005);
  });

  test('XP repository kaydı servis yeniden oluşturulunca yüklenir', () async {
    final storage = FakeXpStorage();
    final repository = FakeXpStore(storage);
    final firstService = await createXpService(repository: repository);

    expect(await firstService.addXp(5), isTrue);
    expect(repository.currentTotalXp, 5);
    firstService.dispose();

    final recreatedService = await createXpService(
      repository: FakeXpStore(storage),
    );
    addTearDown(recreatedService.dispose);

    expect(recreatedService.totalXp, 5);
    expect(recreatedService.currentLevel, 1);
    expect(recreatedService.xpInCurrentLevel, 5);
  });

  test('Favori durumu repository yeniden oluşturulduğunda korunur', () async {
    final records = <String, WordProgress>{};
    final firstRepository = FakeWordProgressStore(records);
    await firstRepository.saveFavorite('dog', true);

    final recreatedRepository = FakeWordProgressStore(records);
    await recreatedRepository.initialize();

    expect(recreatedRepository.progressFor('dog').isFavorite, isTrue);
  });

  test(
    'LearningEngine sonucu kelime repository ilerlemesine aktarılır',
    () async {
      final engine = LearningEngine(animalWords);
      final repository = FakeWordProgressStore();

      engine.rateHard();
      await repository.saveLearningResult(
        engine.lastReview!,
        reviewedAt: DateTime.parse('2026-07-14T10:30:00.000'),
      );

      final progress = repository.progressFor('dog');
      expect(progress.mastery, 'hard');
      expect(progress.repetitionCount, 1);
      expect(progress.correctCount, 0);
      expect(progress.wrongCount, 1);
      expect(progress.lastReviewedAt, isNotNull);
      expect(progress.reviewStage, 0);
      expect(
        progress.nextReviewAt,
        DateTime.parse('2026-07-15T10:30:00.000').toUtc(),
      );
    },
  );

  test(
    'Günlük hedef beş değerlendirmede tamamlanır ve seri bir kez artar',
    () async {
      final service = StreakService(repository: FakeDailyProgressStore());
      addTearDown(service.dispose);
      await service.initialize();

      expect(service.todayCount, 0);
      expect(service.dailyGoal, 5);
      expect(service.currentStreak, 7);
      expect(service.isTodayCompleted, isFalse);
      expect(service.remainingForToday, 5);

      for (var count = 1; count < service.dailyGoal; count++) {
        expect(await service.recordEvaluation(), isFalse);
        expect(service.todayCount, count);
        expect(service.remainingForToday, service.dailyGoal - count);
        expect(service.currentStreak, 7);
      }

      expect(await service.recordEvaluation(), isTrue);
      expect(service.todayCount, 5);
      expect(service.remainingForToday, 0);
      expect(service.isTodayCompleted, isTrue);
      expect(service.currentStreak, 8);

      expect(await service.recordEvaluation(), isFalse);
      expect(await service.recordEvaluation(), isFalse);
      expect(service.todayCount, 7);
      expect(service.remainingForToday, 0);
      expect(service.currentStreak, 8);
    },
  );

  test(
    'Seri servisi yeniden oluşturulduğunda kayıtlı değerleri yükler',
    () async {
      final storage = FakeDailyStorage();
      final firstService = StreakService(
        repository: FakeDailyProgressStore(storage),
      );
      await firstService.initialize();
      for (var count = 0; count < 3; count++) {
        await firstService.recordEvaluation();
      }
      firstService.dispose();

      final recreatedService = StreakService(
        repository: FakeDailyProgressStore(storage),
      );
      addTearDown(recreatedService.dispose);
      await recreatedService.initialize();

      expect(recreatedService.todayCount, 3);
      expect(recreatedService.remainingForToday, 2);
      expect(recreatedService.currentStreak, 7);
      expect(recreatedService.isTodayCompleted, isFalse);

      await recreatedService.recordEvaluation();
      expect(await recreatedService.recordEvaluation(), isTrue);
      expect(recreatedService.currentStreak, 8);
    },
  );

  test('İngilizce TTS ayarlanır ve eşzamanlı konuşmayı engeller', () async {
    final engine = FakeTtsEngine()..speakCompleter = Completer<bool>();
    final service = EnglishTtsService(engine: engine);

    final firstSpeech = service.speak('Dog');
    final ignoredSpeech = await service.speak('Cat');
    await Future<void>.delayed(Duration.zero);

    expect(ignoredSpeech, isTrue);
    expect(service.isSpeaking.value, isTrue);
    expect(engine.language, 'en-US');
    expect(engine.speechRate, 0.42);
    expect(engine.volume, 1.0);
    expect(engine.pitch, 1.0);
    expect(engine.spokenTexts, ['Dog']);

    engine.speakCompleter!.complete(true);
    expect(await firstSpeech, isTrue);
    expect(service.isSpeaking.value, isFalse);

    await service.dispose();
  });

  testWidgets('Dinle butonu mevcut kelimeyi kullanır ve aktif durum gösterir', (
    tester,
  ) async {
    final engine = FakeTtsEngine()..speakCompleter = Completer<bool>();
    final service = EnglishTtsService(engine: engine);
    final xpService = await createXpService();

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.animals,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: service,
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pump();

    expect(engine.spokenTexts, ['Dog']);
    expect(find.text('Dinleniyor'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    engine.speakCompleter!.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('Dinle'), findsOneWidget);
    expect(find.text('Dinleniyor'), findsNothing);
  });

  testWidgets('TTS hatası kullanıcıya bildirilir', (tester) async {
    final service = EnglishTtsService(
      engine: FakeTtsEngine()..failOnSpeak = true,
    );
    final xpService = await createXpService();

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.animals,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: service,
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pumpAndSettle();

    expect(find.text('Ses oynatılamadı'), findsOneWidget);
  });

  testWidgets('Favori seçimi anında görünür ve repository kaydından yüklenir', (
    tester,
  ) async {
    final repository = FakeWordProgressStore();
    final xpService = await createXpService();

    Widget wordCard() => MaterialApp(
      home: WordCardScreen(
        category: CategoryCatalog.animals,
        wordProgressStore: repository,
        xpService: xpService,
        ttsService: EnglishTtsService(engine: FakeTtsEngine()),
      ),
    );

    await tester.pumpWidget(wordCard());
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.text('Favori'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(repository.progressFor('dog').isFavorite, isTrue);

    await tester.pumpWidget(wordCard());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  testWidgets(
    'İlk başarılı kelime değerlendirmesi başarım bildirimi gösterir',
    (tester) async {
      final achievementStore = FakeAchievementStore();
      await pumpKelimoApp(tester, achievementStore: achievementStore);
      await openAnimalsCategory(tester);
      await tester.tap(find.text('Öğrenmeye Başla'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kolay'));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Yeni başarım!'), findsOneWidget);
      expect(find.text('İlk Adım'), findsOneWidget);
      expect(achievementStore.records.containsKey('first_step'), isTrue);
      await tester.tap(find.text('Harika!'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Kelime değerlendirmesi açık hatırlatıcıyı yeniden planlar', (
    tester,
  ) async {
    final storage = FakeSettingsStorage()
      ..values[SettingsRepository.reminderEnabledKey] = 'true';
    final notifications = FakeNotificationService();
    await pumpKelimoApp(
      tester,
      settingsStorage: storage,
      notificationService: notifications,
    );
    addTearDown(notifications.dispose);
    final initialScheduleCalls = notifications.scheduleCalls;

    await openAnimalsCategory(tester);
    await tester.tap(find.text('Öğrenmeye Başla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zor'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(notifications.scheduleCalls, initialScheduleCalls + 1);
    expect(notifications.schedules, hasLength(1));
  });

  testWidgets('Zor seçilen kelime bir kart sonra yeniden gösterilir', (
    tester,
  ) async {
    await pumpLearningSession(tester);

    expect(find.text('DOG'), findsOneWidget);
    await selectLearningRating(tester, 'Zor');
    expect(find.text('CAT'), findsOneWidget);

    await selectLearningRating(tester, 'Kolay');
    expect(find.text('DOG'), findsOneWidget);
  });

  testWidgets('Tekrar Et seçilen kelime iki kart sonra yeniden gösterilir', (
    tester,
  ) async {
    await pumpLearningSession(tester);

    await selectLearningRating(tester, 'Tekrar Et');
    expect(find.text('CAT'), findsOneWidget);
    await selectLearningRating(tester, 'Kolay');
    expect(find.text('BIRD'), findsOneWidget);
    await selectLearningRating(tester, 'Kolay');

    expect(find.text('DOG'), findsOneWidget);
  });

  testWidgets('Flashcard seçimleri XP değerini 5, 8 ve 10 yapar', (
    tester,
  ) async {
    final storage = FakeXpStorage();
    final xpService = await createXpService(repository: FakeXpStore(storage));
    addTearDown(xpService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.animals,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: FakeTtsEngine()),
        ),
      ),
    );

    await selectLearningRating(tester, 'Kolay');
    expect(xpService.totalXp, 5);
    expect(storage.state.totalXp, 5);

    await selectLearningRating(tester, 'Zor');
    expect(xpService.totalXp, 8);

    await selectLearningRating(tester, 'Tekrar Et');
    expect(xpService.totalXp, 10);
    expect(storage.state.totalXp, 10);
  });

  testWidgets('Günlük hedef ilk kez tamamlanınca geri bildirim gösterilir', (
    tester,
  ) async {
    final streakService = StreakService(dailyGoal: 1);
    final xpService = await createXpService();
    addTearDown(streakService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.animals,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: FakeTtsEngine()),
          streakService: streakService,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Kolay'));
    await tester.tap(find.text('Kolay'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('🔥 Günlük hedef tamamlandı! Serin 8 güne çıktı.'),
      findsOneWidget,
    );
    expect(streakService.todayCount, 1);
    expect(streakService.currentStreak, 8);
  });

  testWidgets('Tüm kelimeler Kolay seçilince kategori tamamlanır', (
    tester,
  ) async {
    await pumpLearningSession(tester);

    for (
      var index = 0;
      index < 100 && find.text('Kategori Tamamlandı').evaluate().isEmpty;
      index++
    ) {
      await selectLearningRating(tester, 'Kolay');
    }

    expect(find.text('Kategori Tamamlandı'), findsOneWidget);
    expect(
      find.text('Hayvanlar kategorisindeki tüm kelimeleri tamamladın!'),
      findsOneWidget,
    );
  });

  test('Quiz sonucu yüzde, yıldız ve motivasyon değerlerini hesaplar', () {
    expect(calculateQuizPercentage(correct: 9, total: 10), 90);
    expect(quizStarCount(correct: 10, total: 10), 5);
    expect(quizStarCount(correct: 9, total: 10), 4);
    expect(quizStarCount(correct: 7, total: 10), 3);
    expect(quizStarCount(correct: 5, total: 10), 2);
    expect(quizStarCount(correct: 1, total: 10), 1);
    expect(quizStarCount(correct: 0, total: 10), 0);
    expect(quizMotivation(100), 'Mükemmel!');
    expect(quizMotivation(80), 'Harika gidiyorsun!');
    expect(quizMotivation(60), 'Güzel iş!');
    expect(quizMotivation(40), 'Biraz daha çalışırsan çok daha iyi olacak.');
    expect(quizMotivation(30), 'Pes etme, tekrar deneyelim!');
  });

  test('Quiz doğru cevap serisi oturumun en yüksek serisini korur', () {
    int longestFor(List<bool> answers) {
      final counter = QuizCorrectStreakCounter();
      for (final answer in answers) {
        counter.recordAnswer(isCorrect: answer);
      }
      return counter.longest;
    }

    expect(longestFor(List.filled(10, true)), 10);
    expect(
      longestFor([true, true, true, true, false, true, true, true, true, true]),
      5,
    );
    expect(longestFor([true, true, false, true, true, true]), 3);
    expect(longestFor([false, true, true, true]), 3);
    expect(longestFor([true, true, true, false]), 3);
  });

  test('Quiz süresi saniye ve dakika biçiminde gösterilir', () {
    expect(formatQuizDuration(const Duration(seconds: 42)), '42 sn');
    expect(formatQuizDuration(const Duration(seconds: 72)), '1 dk 12 sn');
  });

  test('Türkçe metni dil kurallarına uygun büyük harfe dönüştürür', () {
    expect(toTurkishUpperCase('kedi'), 'KEDİ');
    expect(toTurkishUpperCase('tilki'), 'TİLKİ');
    expect(toTurkishUpperCase('inek'), 'İNEK');
    expect(toTurkishUpperCase('ışık şğüöç'), 'IŞIK ŞĞÜÖÇ');
  });

  test('Hayvanlar listesi 30 benzersiz ve eksiksiz kelime içerir', () {
    expect(animalWords, hasLength(30));
    expect(animalWords.map((word) => word.english).toSet(), hasLength(30));

    for (final word in animalWords) {
      expect(word.english, isNotEmpty);
      expect(word.turkish, isNotEmpty);
      expect(word.emoji, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
      expect(word.exampleTranslation, isNotEmpty);
    }
  });

  test('Kategori kataloğu Hayvanlar kimliğini ve kelime IDlerini korur', () {
    final category = CategoryCatalog.findById('animals');

    expect(category, same(CategoryCatalog.animals));
    expect(category!.id, 'animals');
    expect(category.title, 'Hayvanlar');
    expect(category.words, animalWords);
    expect(
      category.words.take(24).map((word) => word.id).toList(),
      animalWords.take(24).map((word) => word.english.toLowerCase()).toList(),
    );
  });

  test('Yiyecekler kataloğu 30 kararlı ve benzersiz kelime içerir', () {
    final category = CategoryCatalog.findById('foods');

    expect(CategoryCatalog.categories, hasLength(18));
    expect(category, same(CategoryCatalog.foods));
    expect(category!.id, 'foods');
    expect(category.title, 'Yiyecekler');
    expect(category.isAvailable, isTrue);
    expect(category.words, foodWords);
    expect(foodWords, hasLength(30));
    expect(foodWords.map((word) => word.id).toSet(), hasLength(30));
    expect(foodWords.every((word) => word.id.startsWith('foods_')), isTrue);
    expect(foodWords.take(20).map((word) => word.id).toList(), [
      'foods_apple',
      'foods_banana',
      'foods_orange',
      'foods_strawberry',
      'foods_grape',
      'foods_watermelon',
      'foods_bread',
      'foods_cheese',
      'foods_milk',
      'foods_water',
      'foods_rice',
      'foods_soup',
      'foods_salad',
      'foods_cake',
      'foods_cookie',
      'foods_chocolate',
      'foods_ice_cream',
      'foods_hamburger',
      'foods_pizza',
      'foods_sandwich',
    ]);
    for (final word in foodWords) {
      expect(word.english, isNotEmpty);
      expect(word.turkish, isNotEmpty);
      expect(word.emoji, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
      expect(word.exampleTranslation, isNotEmpty);
    }

    final upcoming = CategoryCatalog.categories
        .where((item) => !item.isAvailable)
        .map((item) => item.title)
        .toSet();
    expect(upcoming, isEmpty);
  });

  test('Renkler kataloğu 30 kararlı ve benzersiz kelime içerir', () {
    final category = CategoryCatalog.findById('colors');

    expect(category, same(CategoryCatalog.colors));
    expect(category!.id, 'colors');
    expect(category.title, 'Renkler');
    expect(category.isAvailable, isTrue);
    expect(category.words, colorWords);
    expect(colorWords, hasLength(30));
    expect(colorWords.map((word) => word.id).toSet(), hasLength(30));
    expect(colorWords.every((word) => word.id.startsWith('colors_')), isTrue);
    expect(colorWords.take(16).map((word) => word.id).toList(), [
      'colors_red',
      'colors_blue',
      'colors_yellow',
      'colors_green',
      'colors_orange',
      'colors_purple',
      'colors_pink',
      'colors_brown',
      'colors_black',
      'colors_white',
      'colors_gray',
      'colors_light_blue',
      'colors_dark_blue',
      'colors_gold',
      'colors_silver',
      'colors_colorful',
    ]);
    for (final word in colorWords) {
      expect(word.english, isNotEmpty);
      expect(word.turkish, isNotEmpty);
      expect(word.emoji, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
      expect(word.exampleTranslation, isNotEmpty);
    }
    expect(
      colorWords.map((word) => word.turkish),
      containsAll(['Kırmızı', 'Sarı', 'Yeşil', 'Açık Mavi', 'Gümüş Rengi']),
    );
  });

  test('Ev kataloğu 30 kararlı ve benzersiz kelime içerir', () {
    final category = CategoryCatalog.findById('home');

    expect(category, same(CategoryCatalog.home));
    expect(category!.id, 'home');
    expect(category.title, 'Ev');
    expect(category.isAvailable, isTrue);
    expect(category.words, homeWords);
    expect(homeWords, hasLength(30));
    expect(homeWords.map((word) => word.id).toSet(), hasLength(30));
    expect(homeWords.every((word) => word.id.startsWith('home_')), isTrue);
    expect(homeWords.take(22).map((word) => word.id).toList(), [
      'home_house',
      'home_room',
      'home_kitchen',
      'home_bathroom',
      'home_bedroom',
      'home_living_room',
      'home_door',
      'home_window',
      'home_wall',
      'home_floor',
      'home_roof',
      'home_table',
      'home_chair',
      'home_bed',
      'home_sofa',
      'home_lamp',
      'home_television',
      'home_refrigerator',
      'home_oven',
      'home_washing_machine',
      'home_garden',
      'home_key',
    ]);
    for (final word in homeWords) {
      expect(word.english, isNotEmpty);
      expect(word.turkish, isNotEmpty);
      expect(word.emoji, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
      expect(word.exampleTranslation, isNotEmpty);
    }
    expect(
      homeWords.map((word) => word.turkish),
      containsAll([
        'Çatı',
        'Fırın',
        'Çamaşır Makinesi',
        'Buzdolabı',
        'Yatak Odası',
        'Oturma Odası',
      ]),
    );
  });

  test('Aile kataloğu 30 kararlı ve benzersiz kelime içerir', () {
    final category = CategoryCatalog.findById('family');

    expect(category, same(CategoryCatalog.family));
    expect(category!.id, 'family');
    expect(category.title, 'Aile');
    expect(category.emoji, '👨‍👩‍👧‍👦');
    expect(category.isAvailable, isTrue);
    expect(category.words, familyWords);
    expect(familyWords, hasLength(30));
    expect(familyWords.map((word) => word.id).toSet(), hasLength(30));
    expect(familyWords.every((word) => word.id.startsWith('family_')), isTrue);
    expect(familyWords.take(20).map((word) => word.id).toList(), [
      'family_family',
      'family_mother',
      'family_father',
      'family_parents',
      'family_sister',
      'family_brother',
      'family_grandmother',
      'family_grandfather',
      'family_grandparents',
      'family_daughter',
      'family_son',
      'family_child',
      'family_children',
      'family_baby',
      'family_aunt',
      'family_uncle',
      'family_cousin',
      'family_wife',
      'family_husband',
      'family_relative',
    ]);
    expect(familyWords.first.english, 'Family');
    expect(familyWords.first.turkish, 'Aile');
    expect(familyWords[19].english, 'Relative');
    expect(familyWords[19].turkish, 'Akraba');
    for (final word in familyWords) {
      expect(word.english, isNotEmpty);
      expect(word.turkish, isNotEmpty);
      expect(word.emoji, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
      expect(word.exampleTranslation, isNotEmpty);
    }
    final availableCategories = CategoryCatalog.categories.where(
      (item) => item.isAvailable,
    );
    expect(availableCategories, hasLength(18));
    expect(availableCategories.expand((item) => item.words), hasLength(540));
  });

  test('Ulaşım kataloğu 30 kararlı ve benzersiz kelime içerir', () {
    final category = CategoryCatalog.findById('transportation');

    expect(category, same(CategoryCatalog.transportation));
    expect(category!.id, 'transportation');
    expect(category.title, 'Ulaşım');
    expect(category.emoji, '🚍');
    expect(category.isAvailable, isTrue);
    expect(category.words, transportationWords);
    expect(transportationWords, hasLength(30));
    expect(transportationWords.map((word) => word.id).toSet(), hasLength(30));
    expect(
      transportationWords.every(
        (word) => word.id.startsWith('transportation_'),
      ),
      isTrue,
    );
    expect(transportationWords.take(20).map((word) => word.id).toList(), [
      'transportation_car',
      'transportation_bus',
      'transportation_train',
      'transportation_bicycle',
      'transportation_motorcycle',
      'transportation_airplane',
      'transportation_ship',
      'transportation_boat',
      'transportation_taxi',
      'transportation_truck',
      'transportation_subway',
      'transportation_tram',
      'transportation_helicopter',
      'transportation_ambulance',
      'transportation_fire_truck',
      'transportation_police_car',
      'transportation_station',
      'transportation_airport',
      'transportation_road',
      'transportation_bridge',
    ]);
    expect(transportationWords.first.english, 'Car');
    expect(transportationWords.first.turkish, 'Araba');
    expect(transportationWords[19].english, 'Bridge');
    expect(transportationWords[19].turkish, 'Köprü');
    for (final word in transportationWords) {
      expect(word.english, isNotEmpty);
      expect(word.turkish, isNotEmpty);
      expect(word.emoji, isNotEmpty);
      expect(word.exampleSentence, isNotEmpty);
      expect(word.exampleTranslation, isNotEmpty);
    }
  });

  test('Öğrenme Merkezi gerçek kayıtları ortak kurallarla sınıflandırır', () {
    final store = FakeWordProgressStore({
      'dog': testWordProgress(
        wordId: 'dog',
        mastery: 'again',
        repetitionCount: 1,
        isFavorite: true,
      ),
      'cat': testWordProgress(
        wordId: 'cat',
        mastery: 'hard',
        repetitionCount: 1,
      ),
      'bird': testWordProgress(
        wordId: 'bird',
        mastery: 'easy',
        repetitionCount: 1,
      ),
      'home_house': testWordProgress(
        wordId: 'home_house',
        mastery: 'easy',
        repetitionCount: 1,
      ),
    });
    final snapshot = LearningCenterService(wordProgressStore: store).load();

    expect(snapshot.totalCount, 540);
    expect(snapshot.favoriteCount, 1);
    expect(snapshot.repeatPendingCount, 2);
    expect(snapshot.learnedCount, 2);
    expect(
      snapshot
          .wordsFor(LearningCenterFilter.repeatPending)
          .map((entry) => entry.word.id),
      ['dog', 'cat'],
    );
    expect(
      snapshot
          .wordsFor(LearningCenterFilter.learned)
          .map((entry) => '${entry.category.id}:${entry.word.id}'),
      ['animals:bird', 'home:home_house'],
    );
    expect(
      snapshot.wordsFor(LearningCenterFilter.favorites).single.word.id,
      'dog',
    );

    final mouse = snapshot.allWords.firstWhere(
      (entry) => entry.word.english == 'Mouse',
    );
    expect(mouse.status, LearningCenterWordStatus.newWord);
    for (final filter in [
      LearningCenterFilter.repeatPending,
      LearningCenterFilter.favorites,
      LearningCenterFilter.learned,
    ]) {
      expect(
        snapshot
            .wordsFor(filter)
            .any((entry) => entry.word.id == mouse.word.id),
        isFalse,
      );
    }
  });

  test('Öğrenme Merkezi katalog ve kategori sırasını korur', () {
    final snapshot = LearningCenterService(
      wordProgressStore: FakeWordProgressStore(),
    ).load();

    expect(snapshot.allWords.first.word.english, 'Dog');
    expect(snapshot.allWords.first.category.id, 'animals');
    expect(snapshot.allWords[30].word.english, 'Apple');
    expect(snapshot.allWords[30].category.id, 'foods');
    expect(snapshot.allWords.last.word.english, 'Relaxed');
    expect(snapshot.allWords.last.category.id, 'feelings');
    expect(
      snapshot.allWords.map((entry) => entry.word.id).toSet(),
      hasLength(540),
    );
  });

  test('İstatistikler boş veride güvenli başlangıç değerleri üretir', () async {
    final streakService = StreakService(initialStreak: 0);
    final xpService = await createXpService();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
    );
    addTearDown(streakService.dispose);
    addTearDown(xpService.dispose);
    addTearDown(statisticsService.dispose);

    await statisticsService.refresh();
    final statistics = statisticsService.statistics!;

    expect(statistics.currentLevel, 1);
    expect(statistics.totalXp, 0);
    expect(statistics.currentStreak, 0);
    expect(statistics.todayReviewCount, 0);
    expect(statistics.startedWordCount, 0);
    expect(statistics.favoriteWordCount, 0);
    expect(statistics.distribution.totalCount, 540);
    expect(statistics.distribution.newCount, 540);
    expect(statistics.distribution.learningCount, 0);
    expect(statistics.distribution.learnedCount, 0);
    expect(statistics.quizStatistics.totalQuizCount, 0);
    expect(statistics.quizStatistics.generalSuccessPercentage, 0);
    expect(statistics.recentAttempts, isEmpty);
  });

  test('Genel ilerleme veri olmadığında güvenli boş açıklama üretir', () {
    const distribution = WordLearningDistribution(
      totalCount: 0,
      newCount: 0,
      learningCount: 0,
      learnedCount: 0,
    );

    expect(generalProgressDescription(distribution), 'Henüz kelime bulunmuyor');
  });

  test(
    'İstatistikler kelime dağılımı, quiz sırası ve kategori değerlerini hesaplar',
    () async {
      final wordStore = FakeWordProgressStore({
        'dog': testWordProgress(
          wordId: 'dog',
          mastery: 'easy',
          repetitionCount: 1,
          isFavorite: true,
        ),
        'cat': testWordProgress(wordId: 'cat', isFavorite: true),
        'bird': testWordProgress(
          wordId: 'bird',
          mastery: 'hard',
          repetitionCount: 2,
        ),
        'fish': testWordProgress(
          wordId: 'fish',
          mastery: 'again',
          repetitionCount: 1,
        ),
        'horse': testWordProgress(
          wordId: 'horse',
          mastery: 'easy',
          repetitionCount: 1,
        ),
      });
      final xpStorage = FakeXpStorage(totalXp: 250);
      final quizStorage = FakeQuizStorage();
      final quizStore = FakeQuizStore(quizStorage, xpStorage);
      final attempts = [
        ('animals', 10, 100),
        ('animals', 7, 70),
        ('animals', 5, 50),
        ('animals', 9, 90),
        ('animals', 8, 80),
        ('animals', 6, 60),
        ('foods', 4, 40),
      ];
      for (var index = 0; index < attempts.length; index++) {
        final attempt = attempts[index];
        await quizStore.saveCompletedQuiz(
          categoryId: attempt.$1,
          correctCount: attempt.$2,
          totalQuestions: 10,
          scorePercent: attempt.$3,
          completedAt: DateTime(2026, 7, index + 1),
        );
      }
      final streakService = StreakService(initialStreak: 3);
      for (var count = 0; count < 4; count++) {
        await streakService.recordEvaluation();
      }
      final xpService = await createXpService(
        repository: FakeXpStore(xpStorage),
      );
      final statisticsService = createStatisticsService(
        streakService: streakService,
        xpService: xpService,
        wordProgressStore: wordStore,
        quizStore: quizStore,
      );
      addTearDown(streakService.dispose);
      addTearDown(xpService.dispose);
      addTearDown(statisticsService.dispose);

      await statisticsService.refresh();
      final statistics = statisticsService.statistics!;
      final category = await statisticsService.loadCategory('animals');

      expect(statistics.startedWordCount, 4);
      expect(statistics.favoriteWordCount, 2);
      expect(statistics.distribution.totalCount, 540);
      expect(statistics.distribution.newCount, 536);
      expect(statistics.distribution.learningCount, 2);
      expect(statistics.distribution.learnedCount, 2);
      expect(statistics.quizStatistics.totalQuizCount, 7);
      expect(statistics.quizStatistics.generalSuccessPercentage, 70);
      expect(statistics.bestCategoryName, 'Hayvanlar');
      expect(statistics.highestQuizScore, 100);
      expect(statistics.recentAttempts, hasLength(5));
      expect(statistics.recentAttempts.first.categoryId, 'foods');
      expect(statistics.recentAttempts.first.completedAt, DateTime(2026, 7, 7));
      expect(statistics.recentAttempts.last.completedAt, DateTime(2026, 7, 3));

      expect(category.totalWordCount, 30);
      expect(category.reviewedWordCount, 4);
      expect(category.learnedWordCount, 2);
      expect(category.favoriteWordCount, 2);
      expect(category.averageMasteryPercentage, 10);
      expect(category.completedQuizCount, 6);
      expect(category.highestQuizScore, 100);
      expect(category.averageQuizPercentage, 75);
    },
  );

  test(
    'Yiyecekler istatistikleri yalnızca foods verilerini kullanır',
    () async {
      final wordStore = FakeWordProgressStore({
        'foods_apple': testWordProgress(
          wordId: 'foods_apple',
          mastery: 'easy',
          repetitionCount: 1,
          isFavorite: true,
        ),
        'dog': testWordProgress(
          wordId: 'dog',
          mastery: 'easy',
          repetitionCount: 1,
          isFavorite: true,
        ),
      });
      final xpStorage = FakeXpStorage();
      final quizStorage = FakeQuizStorage();
      final quizStore = FakeQuizStore(quizStorage, xpStorage);
      await quizStore.saveCompletedQuiz(
        categoryId: 'foods',
        correctCount: 8,
        totalQuestions: 10,
        scorePercent: 80,
      );
      await quizStore.saveCompletedQuiz(
        categoryId: 'animals',
        correctCount: 10,
        totalQuestions: 10,
        scorePercent: 100,
      );
      final streakService = StreakService();
      final xpService = await createXpService();
      final statisticsService = createStatisticsService(
        streakService: streakService,
        xpService: xpService,
        wordProgressStore: wordStore,
        quizStore: quizStore,
      );
      addTearDown(streakService.dispose);
      addTearDown(xpService.dispose);
      addTearDown(statisticsService.dispose);

      final statistics = await statisticsService.loadCategory('foods');

      expect(statistics.categoryId, 'foods');
      expect(statistics.totalWordCount, 30);
      expect(statistics.reviewedWordCount, 1);
      expect(statistics.learnedWordCount, 1);
      expect(statistics.favoriteWordCount, 1);
      expect(statistics.completedQuizCount, 1);
      expect(statistics.highestQuizScore, 80);
      expect(statistics.averageQuizPercentage, 80);
    },
  );

  test('Renkler istatistikleri yalnızca colors verilerini kullanır', () async {
    final wordStore = FakeWordProgressStore({
      'colors_red': testWordProgress(
        wordId: 'colors_red',
        mastery: 'easy',
        repetitionCount: 1,
        isFavorite: true,
      ),
      'foods_apple': testWordProgress(
        wordId: 'foods_apple',
        mastery: 'easy',
        repetitionCount: 1,
        isFavorite: true,
      ),
    });
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    final quizStore = FakeQuizStore(quizStorage, xpStorage);
    await quizStore.saveCompletedQuiz(
      categoryId: 'colors',
      correctCount: 9,
      totalQuestions: 10,
      scorePercent: 90,
    );
    await quizStore.saveCompletedQuiz(
      categoryId: 'foods',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );
    final streakService = StreakService();
    final xpService = await createXpService();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
      wordProgressStore: wordStore,
      quizStore: quizStore,
    );
    addTearDown(streakService.dispose);
    addTearDown(xpService.dispose);
    addTearDown(statisticsService.dispose);

    final statistics = await statisticsService.loadCategory('colors');

    expect(statistics.categoryId, 'colors');
    expect(statistics.totalWordCount, 30);
    expect(statistics.reviewedWordCount, 1);
    expect(statistics.learnedWordCount, 1);
    expect(statistics.favoriteWordCount, 1);
    expect(statistics.completedQuizCount, 1);
    expect(statistics.highestQuizScore, 90);
    expect(statistics.averageQuizPercentage, 90);
  });

  test('Ev istatistikleri yalnızca home verilerini kullanır', () async {
    final wordStore = FakeWordProgressStore({
      'home_house': testWordProgress(
        wordId: 'home_house',
        mastery: 'easy',
        repetitionCount: 1,
        isFavorite: true,
      ),
      'colors_red': testWordProgress(
        wordId: 'colors_red',
        mastery: 'easy',
        repetitionCount: 1,
        isFavorite: true,
      ),
    });
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    final quizStore = FakeQuizStore(quizStorage, xpStorage);
    await quizStore.saveCompletedQuiz(
      categoryId: 'home',
      correctCount: 7,
      totalQuestions: 10,
      scorePercent: 70,
    );
    await quizStore.saveCompletedQuiz(
      categoryId: 'colors',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );
    final streakService = StreakService();
    final xpService = await createXpService();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
      wordProgressStore: wordStore,
      quizStore: quizStore,
    );
    addTearDown(streakService.dispose);
    addTearDown(xpService.dispose);
    addTearDown(statisticsService.dispose);

    final statistics = await statisticsService.loadCategory('home');

    expect(statistics.categoryId, 'home');
    expect(statistics.totalWordCount, 30);
    expect(statistics.reviewedWordCount, 1);
    expect(statistics.learnedWordCount, 1);
    expect(statistics.favoriteWordCount, 1);
    expect(statistics.completedQuizCount, 1);
    expect(statistics.highestQuizScore, 70);
    expect(statistics.averageQuizPercentage, 70);
  });

  test('Aile istatistikleri yalnızca family verilerini kullanır', () async {
    final wordStore = FakeWordProgressStore({
      'family_family': testWordProgress(
        wordId: 'family_family',
        mastery: 'easy',
        repetitionCount: 1,
        isFavorite: true,
      ),
      'home_house': testWordProgress(
        wordId: 'home_house',
        mastery: 'easy',
        repetitionCount: 1,
        isFavorite: true,
      ),
    });
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    final quizStore = FakeQuizStore(quizStorage, xpStorage);
    await quizStore.saveCompletedQuiz(
      categoryId: 'family',
      correctCount: 8,
      totalQuestions: 10,
      scorePercent: 80,
    );
    await quizStore.saveCompletedQuiz(
      categoryId: 'home',
      correctCount: 10,
      totalQuestions: 10,
      scorePercent: 100,
    );
    final streakService = StreakService();
    final xpService = await createXpService();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
      wordProgressStore: wordStore,
      quizStore: quizStore,
    );
    addTearDown(streakService.dispose);
    addTearDown(xpService.dispose);
    addTearDown(statisticsService.dispose);

    final statistics = await statisticsService.loadCategory('family');

    expect(statistics.categoryId, 'family');
    expect(statistics.totalWordCount, 30);
    expect(statistics.reviewedWordCount, 1);
    expect(statistics.learnedWordCount, 1);
    expect(statistics.favoriteWordCount, 1);
    expect(statistics.completedQuizCount, 1);
    expect(statistics.highestQuizScore, 80);
    expect(statistics.averageQuizPercentage, 80);
  });

  test(
    'Ulaşım istatistikleri yalnızca transportation verilerini kullanır',
    () async {
      final wordStore = FakeWordProgressStore({
        'transportation_car': testWordProgress(
          wordId: 'transportation_car',
          mastery: 'easy',
          repetitionCount: 1,
          isFavorite: true,
        ),
        'family_family': testWordProgress(
          wordId: 'family_family',
          mastery: 'easy',
          repetitionCount: 1,
          isFavorite: true,
        ),
      });
      final xpStorage = FakeXpStorage();
      final quizStorage = FakeQuizStorage();
      final quizStore = FakeQuizStore(quizStorage, xpStorage);
      await quizStore.saveCompletedQuiz(
        categoryId: 'transportation',
        correctCount: 9,
        totalQuestions: 10,
        scorePercent: 90,
      );
      await quizStore.saveCompletedQuiz(
        categoryId: 'family',
        correctCount: 10,
        totalQuestions: 10,
        scorePercent: 100,
      );
      final streakService = StreakService();
      final xpService = await createXpService();
      final statisticsService = createStatisticsService(
        streakService: streakService,
        xpService: xpService,
        wordProgressStore: wordStore,
        quizStore: quizStore,
      );
      addTearDown(streakService.dispose);
      addTearDown(xpService.dispose);
      addTearDown(statisticsService.dispose);

      final statistics = await statisticsService.loadCategory('transportation');

      expect(statistics.categoryId, 'transportation');
      expect(statistics.totalWordCount, 30);
      expect(statistics.reviewedWordCount, 1);
      expect(statistics.learnedWordCount, 1);
      expect(statistics.favoriteWordCount, 1);
      expect(statistics.completedQuizCount, 1);
      expect(statistics.highestQuizScore, 90);
      expect(statistics.averageQuizPercentage, 90);
    },
  );

  testWidgets('ana ekran gerekli bölümleri gösterir', (tester) async {
    await pumpKelimoApp(tester);

    expect(find.text('Merhaba!'), findsOneWidget);
    expect(find.text('Bugün öğrenmeye hazır mısın?'), findsOneWidget);
    expect(find.text('Genel ilerleme'), findsOneWidget);
    expect(find.text('0 / 540 kelime'), findsOneWidget);
    expect(find.text('Henüz öğrenmeye başlamadın'), findsOneWidget);
    expect(find.text('Günlük ilerleme'), findsNothing);
    expect(find.text('18 / 30 kelime'), findsNothing);
    expect(find.text('🔥 7 günlük seri'), findsNothing);
    expect(find.text('Seviye 1'), findsOneWidget);
    expect(find.text('0 / 1000 XP'), findsOneWidget);
    expect(find.text('Günlük Seri'), findsOneWidget);
    expect(find.text('7 gün'), findsOneWidget);
    expect(find.text('Günlük Görev'), findsOneWidget);
    expect(find.text('0 / 5'), findsOneWidget);
    expect(find.text('Bugün 5 kelime değerlendir'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    await tester.scrollUntilVisible(find.text('Kategoriler'), 300);
    expect(find.text('Kategoriler'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Öğrenme Merkezi dört gerçek çalışma kartını gösterir', (
    tester,
  ) async {
    final store = FakeWordProgressStore({
      'dog': testWordProgress(
        wordId: 'dog',
        mastery: 'again',
        repetitionCount: 1,
        isFavorite: true,
      ),
      'cat': testWordProgress(
        wordId: 'cat',
        mastery: 'hard',
        repetitionCount: 1,
      ),
      'bird': testWordProgress(
        wordId: 'bird',
        mastery: 'easy',
        repetitionCount: 1,
      ),
    });
    await pumpKelimoApp(tester, wordProgressStore: store);
    await openLearningCenter(tester);

    expect(find.byType(LearningCenterScreen), findsOneWidget);
    expect(find.text('Öğrenme Merkezi'), findsOneWidget);
    expect(find.text('Çalışma zamanı gelen kelimeler'), findsOneWidget);
    expect(find.text('Toplam kelime'), findsOneWidget);
    expect(find.text('Favoriler'), findsOneWidget);
    expect(find.text('Tekrar bekleyenler'), findsOneWidget);
    expect(find.text('Öğrenilenler'), findsNWidgets(2));
    for (final title in [
      'Tekrar Bekleyenler',
      'Favorilerim',
      'Öğrenilenler',
      'Tüm Kelimeler',
    ]) {
      expect(find.text(title), findsWidgets);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-filter-repeat')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-filter-favorites')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-filter-learned')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-filter-all')),
        matching: find.text('540'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Öğrenme Merkezi filtreleri kullanıcı dostu durumları gösterir', (
    tester,
  ) async {
    final store = FakeWordProgressStore({
      'dog': testWordProgress(
        wordId: 'dog',
        mastery: 'hard',
        repetitionCount: 1,
      ),
      'bird': testWordProgress(
        wordId: 'bird',
        mastery: 'easy',
        repetitionCount: 1,
      ),
    });
    await pumpKelimoApp(tester, wordProgressStore: store);
    await openLearningCenter(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('learning-filter-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learning-filter-all')));
    await tester.pumpAndSettle();

    expect(find.byType(LearningWordListScreen), findsOneWidget);
    expect(find.text('Tüm Kelimeler'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('Köpek'), findsOneWidget);
    expect(find.text('Hayvanlar'), findsWidgets);
    expect(find.text('Öğreniliyor'), findsOneWidget);
    expect(find.text('Şimdi'), findsOneWidget);
    expect(find.text('Yeni'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('learning-word-bird')),
      180,
    );
    expect(find.text('Öğrenildi'), findsOneWidget);
    expect(find.text('hard'), findsNothing);
    expect(find.text('easy'), findsNothing);
  });

  testWidgets('Öğrenme Merkezi boş filtre mesajlarını gösterir', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openLearningCenter(tester);

    final emptyFilters = [
      (
        const ValueKey('learning-filter-repeat'),
        'Tekrar bekleyen kelimen yok.',
      ),
      (
        const ValueKey('learning-filter-favorites'),
        'Henüz favori kelimen yok.',
      ),
      (
        const ValueKey('learning-filter-learned'),
        'Henüz öğrenilen kelimen yok.',
      ),
    ];
    for (final entry in emptyFilters) {
      await tester.ensureVisible(find.byKey(entry.$1));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(entry.$1));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Kelime listesi doğru kategori ve indeksten flashcard açar', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openLearningCenter(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('learning-filter-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learning-filter-all')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('learning-word-home_washing_machine')),
      500,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('learning-word-home_washing_machine')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('learning-word-home_washing_machine')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WordCardScreen), findsOneWidget);
    expect(find.text('Ev'), findsOneWidget);
    expect(find.text('20 / 30'), findsOneWidget);
    expect(find.text('WASHING MACHINE'), findsOneWidget);
  });

  testWidgets('Flashcard dönüşünde Öğrenme Merkezi sayaçları yenilenir', (
    tester,
  ) async {
    final store = FakeWordProgressStore({
      'dog': testWordProgress(
        wordId: 'dog',
        mastery: 'hard',
        repetitionCount: 1,
        isFavorite: true,
      ),
    });
    await pumpKelimoApp(tester, wordProgressStore: store);
    await openLearningCenter(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('learning-filter-favorites')),
    );
    await tester.tap(find.byKey(const ValueKey('learning-filter-favorites')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learning-word-dog')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Favori'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Henüz favori kelimen yok.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-filter-favorites')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('learning-filter-repeat')),
    );
    await tester.tap(find.byKey(const ValueKey('learning-filter-repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learning-word-dog')));
    await tester.pumpAndSettle();
    await selectLearningRating(tester, 'Kolay');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Tekrar bekleyen kelimen yok.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-filter-repeat')),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-filter-learned')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Öğrenme Merkezi küçük ekranda uzun kelimelerde taşmaz', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(280, 650));
    final store = FakeWordProgressStore();
    final streakService = StreakService(repository: FakeDailyProgressStore());
    await streakService.initialize();
    addTearDown(streakService.dispose);
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    final settingsService = await createSettingsService();
    addTearDown(settingsService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LearningCenterScreen(
          service: LearningCenterService(wordProgressStore: store),
          wordProgressStore: store,
          streakService: streakService,
          xpService: xpService,
          settingsService: settingsService,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.byKey(const ValueKey('learning-filter-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('learning-filter-all')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('learning-word-home_washing_machine')),
      500,
    );

    expect(find.text('Washing Machine'), findsOneWidget);
    expect(find.text('Çamaşır Makinesi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ayarlar sekmesi gerçek tercih ve veri bölümlerini gösterir', (
    tester,
  ) async {
    final resetStore = FakeDataResetStore();
    await pumpKelimoApp(tester, dataResetStore: resetStore);

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Ayarlar'), findsWidgets);
    expect(find.text('Uygulama'), findsOneWidget);
    expect(find.text('Hakkında'), findsOneWidget);
    expect(find.text('Gizlilik Merkezi'), findsOneWidget);
    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Uygulamanın görünümünü seç'), findsOneWidget);
    expect(find.text('Öğrenme'), findsOneWidget);
    expect(find.text('Günlük kelime hedefi'), findsOneWidget);
    expect(
      find.text('Yeni hedef bir sonraki günlük çalışmada uygulanır.'),
      findsOneWidget,
    );
    expect(find.text('Hatırlatıcılar'), findsOneWidget);
    expect(find.text('Günlük çalışma hatırlatıcısı'), findsOneWidget);
    expect(find.text('Hatırlatma saati'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.text('Ses'), findsOneWidget);
    expect(find.text('Telaffuz hızı'), findsOneWidget);
    expect(find.text('Sesi dene'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Veri Yönetimi'), 250);
    expect(find.text('Tercihleri varsayılana döndür'), findsOneWidget);
    expect(find.text('Öğrenme verilerini sıfırla'), findsOneWidget);
    expect(find.text('Tüm verileri sıfırla'), findsOneWidget);

    await tester.ensureVisible(find.text('Öğrenme verilerini sıfırla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Öğrenme verilerini sıfırla'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Favoriler, kelime ilerlemesi, quiz geçmişi, XP ve seri bilgileri '
        'kalıcı olarak silinecek. Ayarların korunacak.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(resetStore.calls, isEmpty);
  });

  testWidgets('Kök uygulama kayıtlı sistem, açık ve koyu temayı uygular', (
    tester,
  ) async {
    final expectations = {
      ThemePreference.system: ThemeMode.system,
      ThemePreference.light: ThemeMode.light,
      ThemePreference.dark: ThemeMode.dark,
    };

    for (final entry in expectations.entries) {
      final storage = FakeSettingsStorage()
        ..values[SettingsRepository.themeModeKey] = entry.key.storageValue;
      await pumpKelimoApp(tester, settingsStorage: storage);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, entry.value);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Ayarlar üç tema seçeneğini anında uygular', (tester) async {
    final storage = FakeSettingsStorage();
    await pumpKelimoApp(tester, settingsStorage: storage);
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    final selector = find.byKey(const ValueKey('theme-mode-system'));
    expect(selector, findsOneWidget);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(find.text('Sistem ayarı'), findsWidgets);
    expect(find.text('Açık'), findsOneWidget);
    expect(find.text('Koyu'), findsOneWidget);

    await tester.tap(find.text('Koyu'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
    expect(storage.values[SettingsRepository.themeModeKey], 'dark');

    await tester.tap(find.byKey(const ValueKey('theme-mode-dark')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Açık'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(storage.values[SettingsRepository.themeModeKey], 'light');
  });

  testWidgets('Hakkında ekranı sürüm, gizlilik ve lisansları gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AboutScreen(appInfoProvider: FakeAppInfoProvider())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kelimo'), findsOneWidget);
    expect(find.text('Sürüm 2.3.4 • Yapı 56'), findsOneWidget);
    expect(find.text('Gizlilik Merkezi'), findsOneWidget);
    expect(find.text('Açık kaynak lisansları'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('about-privacy-center')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyCenterScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('about-open-source-licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('Koyu temada Hakkında ve Gizlilik Merkezi taşmadan çalışır', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    final ads = FakeInterstitialAdService(privacyRequired: true);
    addTearDown(ads.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: AboutScreen(
          appInfoProvider: FakeAppInfoProvider(),
          interstitialAdService: ads,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(AboutScreen))).brightness,
      Brightness.dark,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('about-open-source-licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(LicensePage))).brightness,
      Brightness.dark,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('about-privacy-center')));
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyCenterScreen), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(PrivacyCenterScreen))).brightness,
      Brightness.dark,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('privacy-manage-data')),
      250,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Gizlilik Merkezi gerçek veri, bildirim ve reklam davranışlarını açıklar',
    (tester) async {
      final ads = FakeInterstitialAdService(privacyRequired: true);
      addTearDown(ads.dispose);
      var manageDataCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacyCenterScreen(
            interstitialAdService: ads,
            onManageData: () => manageDataCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gizlilik Merkezi'), findsOneWidget);
      expect(find.text('Gizlilik Özeti'), findsOneWidget);
      expect(find.text('Öğrenme verilerin'), findsOneWidget);
      expect(find.textContaining('yerel SQLite veritabanında'), findsOneWidget);
      expect(find.text('Hesap ve bulut'), findsOneWidget);
      expect(find.textContaining('hesap oluşturma'), findsOneWidget);
      expect(find.text('Hatırlatıcılar'), findsOneWidget);
      expect(find.textContaining('yerel bildirim sistemiyle'), findsOneWidget);
      expect(find.text('Reklamlar ve seçimlerin'), findsOneWidget);
      expect(find.textContaining('Google Mobile Ads'), findsOneWidget);
      expect(find.text('Verilerini yönet'), findsOneWidget);
      expect(
        find.textContaining('Öğrenme verilerini veya tüm verileri'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('privacy-center-ad-options')),
        250,
      );
      final privacyOptions = find.byKey(
        const ValueKey('privacy-center-ad-options'),
      );
      await tester.ensureVisible(privacyOptions);
      await tester.pumpAndSettle();
      await tester.tap(privacyOptions);
      await tester.pump();
      expect(ads.privacyCalls, 1);
      expect(ads.showCalls, 0);
      expect(ads.testShowCalls, 0);

      await tester.pump(const Duration(seconds: 5));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('privacy-manage-data')),
        250,
      );
      final manageData = find.byKey(const ValueKey('privacy-manage-data'));
      await tester.ensureVisible(manageData);
      await tester.pumpAndSettle();
      await tester.tap(manageData);
      expect(manageDataCalls, 1);
    },
  );

  testWidgets('Gizlilik Merkezi gereksiz UMP aksiyonunu pasif açıklar', (
    tester,
  ) async {
    final ads = FakeInterstitialAdService(privacyRequired: false);
    addTearDown(ads.dispose);
    await tester.pumpWidget(
      MaterialApp(home: PrivacyCenterScreen(interstitialAdService: ads)),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Şu anda ek reklam gizliliği seçeneği yok.'),
      250,
    );
    expect(
      find.byKey(const ValueKey('privacy-center-ad-options')),
      findsNothing,
    );
    expect(
      find.text('Şu anda ek reklam gizliliği seçeneği yok.'),
      findsOneWidget,
    );
  });

  testWidgets('Gizlilik Merkezi mevcut Veri Yönetimi bölümüne döner', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-privacy-center')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('privacy-manage-data')),
      250,
    );
    final manageData = find.byKey(const ValueKey('privacy-manage-data'));
    await tester.ensureVisible(manageData);
    await tester.pumpAndSettle();
    await tester.tap(manageData);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Veri Yönetimi'), findsOneWidget);
    expect(find.text('Öğrenme verilerini sıfırla'), findsOneWidget);
  });

  testWidgets('Hatırlatma saati gece yarısında 00:35 olarak gösterilir', (
    tester,
  ) async {
    final storage = FakeSettingsStorage()
      ..values[SettingsRepository.reminderHourKey] = '0'
      ..values[SettingsRepository.reminderMinuteKey] = '35';
    await pumpKelimoApp(tester, settingsStorage: storage);

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();

    expect(find.text('00:35'), findsOneWidget);
    expect(find.text('12:35'), findsNothing);
  });

  testWidgets(
    'Ayarlar gizlilik seçeneklerini ve debug test reklamını kullanır',
    (tester) async {
      final ads = FakeInterstitialAdService();
      await pumpKelimoApp(tester, interstitialAdService: ads);
      addTearDown(ads.dispose);

      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Gizlilik ve Reklamlar'), 250);
      await tester.pumpAndSettle();

      expect(find.text('Gizlilik ve Reklamlar'), findsOneWidget);
      expect(find.text('Gizlilik seçenekleri'), findsOneWidget);
      expect(find.text('Test reklamını göster'), findsOneWidget);

      await tester.tap(find.text('Gizlilik seçenekleri'));
      await tester.pump();
      expect(ads.privacyCalls, 1);

      await tester.pump(const Duration(seconds: 5));
      await tester.ensureVisible(find.text('Test reklamını göster'));
      await tester.tap(find.text('Test reklamını göster'));
      await tester.pump();
      expect(ads.testShowCalls, 1);
    },
  );

  testWidgets(
    'Bildirimi test et günlük planı değiştirmeden geri bildirim verir',
    (tester) async {
      final notifications = FakeNotificationService();
      await pumpKelimoApp(tester, notificationService: notifications);
      addTearDown(notifications.dispose);

      await tester.tap(find.text('Ayarlar'));
      await tester.pumpAndSettle();
      final reminderSwitch = find.byKey(
        const ValueKey('daily-reminder-switch'),
      );
      await tester.ensureVisible(reminderSwitch);
      await tester.pumpAndSettle();
      await tester.tap(reminderSwitch);
      await tester.pumpAndSettle();
      expect(notifications.schedules, hasLength(1));
      await tester.pump(const Duration(seconds: 5));

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('test-reminder-notification')),
        180,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('test-reminder-notification')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(notifications.schedules, hasLength(1));
      expect(notifications.testSchedules, hasLength(1));
      expect(
        find.text('Test bildirimi 10 saniye sonrası için planlandı'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Sesi dene seçili telaffuz hızını kullanır ve küçük ekranda taşmaz',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 568));
      final settings = await createSettingsService();
      await settings.setSpeechRate(SpeechRatePreference.fast);
      final engine = FakeTtsEngine();
      final previewTts = EnglishTtsService(
        engine: engine,
        settingsService: settings,
      );
      final wordStore = FakeWordProgressStore();
      final quizStore = FakeQuizStore(FakeQuizStorage(), FakeXpStorage());
      final streak = StreakService(repository: FakeDailyProgressStore());
      await streak.initialize();
      final xp = await createXpService();
      final statistics = createStatisticsService(
        streakService: streak,
        xpService: xp,
        wordProgressStore: wordStore,
        quizStore: quizStore,
      );
      final dataManagement = createDataManagementService(
        wordProgressStore: wordStore,
        quizStore: quizStore,
        streakService: streak,
        xpService: xp,
        settingsService: settings,
        statisticsService: statistics,
      );
      addTearDown(settings.dispose);
      addTearDown(previewTts.dispose);
      addTearDown(streak.dispose);
      addTearDown(xp.dispose);
      addTearDown(statistics.dispose);
      addTearDown(dataManagement.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsScreen(
            settingsService: settings,
            dataManagementService: dataManagement,
            previewTtsService: previewTts,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sesi dene'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sesi dene'));
      await tester.pumpAndSettle();

      expect(engine.spokenTexts, ['Hello, welcome to Kelimo.']);
      expect(engine.speechRate, 0.65);
      await tester.scrollUntilVisible(find.text('Tüm verileri sıfırla'), 250);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Hatırlatıcı switch açma ve kapama planı günceller', (
    tester,
  ) async {
    final notifications = FakeNotificationService();
    await pumpKelimoApp(tester, notificationService: notifications);
    addTearDown(notifications.dispose);

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    final reminderSwitch = find.byKey(const ValueKey('daily-reminder-switch'));
    await tester.ensureVisible(reminderSwitch);
    await tester.pumpAndSettle();
    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();

    expect(find.text('Günlük hatırlatıcı açıldı'), findsOneWidget);
    expect(notifications.schedules, hasLength(1));
    expect(notifications.schedules.single.payload, 'daily_review');

    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();
    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('daily-reminder-switch')),
    );
    expect(switchTile.value, isFalse);
    expect(notifications.schedules, isEmpty);
  });

  testWidgets('İzin reddedilince switch kapalı ve açıklama görünür kalır', (
    tester,
  ) async {
    final notifications = FakeNotificationService()
      ..status = NotificationPermissionStatus.denied
      ..requestResult = NotificationPermissionStatus.permanentlyDenied;
    await pumpKelimoApp(tester, notificationService: notifications);
    addTearDown(notifications.dispose);

    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    final reminderSwitch = find.byKey(const ValueKey('daily-reminder-switch'));
    await tester.ensureVisible(reminderSwitch);
    await tester.pumpAndSettle();
    await tester.tap(reminderSwitch);
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('daily-reminder-switch')),
    );
    expect(switchTile.value, isFalse);
    expect(
      find.text('Bildirim izni kapalı. Cihaz ayarlarından izin vermelisin.'),
      findsOneWidget,
    );
    expect(find.text('Bildirim izni ver'), findsOneWidget);
    expect(notifications.schedules, isEmpty);
  });

  testWidgets('Açık hatırlatıcı başlangıçta yeniden planlanır', (tester) async {
    final storage = FakeSettingsStorage()
      ..values[SettingsRepository.reminderEnabledKey] = 'true'
      ..values[SettingsRepository.reminderHourKey] = '7'
      ..values[SettingsRepository.reminderMinuteKey] = '45';
    final notifications = FakeNotificationService();
    await pumpKelimoApp(
      tester,
      settingsStorage: storage,
      notificationService: notifications,
    );
    addTearDown(notifications.dispose);

    expect(notifications.initializeCalls, 1);
    expect(notifications.schedules, hasLength(1));
    expect(notifications.schedules.single.hour, 7);
    expect(notifications.schedules.single.minute, 45);

    final scheduleCalls = notifications.scheduleCalls;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(notifications.scheduleCalls, scheduleCalls + 1);
    expect(notifications.schedules, hasLength(1));
  });

  testWidgets('daily_review payload Öğrenme Merkezine bir kez yönlendirir', (
    tester,
  ) async {
    var now = DateTime(2026, 7, 16, 10);
    final navigation = AppNavigationController(now: () => now);
    var navigationEvents = 0;
    navigation.addListener(() => navigationEvents++);
    final notifications = FakeNotificationService()
      ..launchPayload = LocalNotificationService.dailyReminderPayload;
    await pumpKelimoApp(
      tester,
      notificationService: notifications,
      navigationController: navigation,
    );
    addTearDown(notifications.dispose);
    addTearDown(navigation.dispose);

    expect(find.text('Öğrenme Merkezi'), findsOneWidget);
    expect(find.text('Tekrar Bekleyenler'), findsOneWidget);
    final eventsAfterLaunch = navigationEvents;
    notifications
      ..sendPayload(LocalNotificationService.dailyReminderPayload)
      ..sendPayload(LocalNotificationService.dailyReminderPayload);
    await tester.pumpAndSettle();
    expect(navigationEvents, eventsAfterLaunch);

    now = now.add(const Duration(seconds: 3));
    notifications.sendPayload(LocalNotificationService.dailyReminderPayload);
    await tester.pumpAndSettle();
    expect(navigationEvents, eventsAfterLaunch + 1);
    expect(find.text('Öğrenme Merkezi'), findsOneWidget);
  });

  testWidgets(
    'İlerleme ekranı boş veride güvenli değerleri ve boş quiz durumunu gösterir',
    (tester) async {
      await pumpKelimoApp(tester);

      await tester.tap(find.text('İlerleme'));
      await tester.pumpAndSettle();

      expect(find.text('Tüm çalışmalarının güncel özeti'), findsOneWidget);
      expect(find.text('Toplam XP'), findsOneWidget);
      expect(find.text('Başlanan kelime'), findsOneWidget);
      expect(find.text('Favori kelime'), findsOneWidget);
      expect(find.text('Tamamlanan quiz'), findsOneWidget);
      expect(find.text('Quiz başarısı'), findsOneWidget);
      expect(find.text('Başarımlar'), findsOneWidget);
      expect(find.text('12 / 12 rozet'), findsOneWidget);
      expect(find.text('Yeni'), findsOneWidget);
      expect(find.text('540 • %100'), findsOneWidget);
      expect(find.text('Henüz tamamlanmış bir quiz yok.'), findsOneWidget);
    },
  );

  testWidgets('İlerleme ekranı küçük boyutta taşma yapmaz', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await pumpKelimoApp(tester);

    await tester.tap(find.text('İlerleme'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Kelime öğrenme dağılımı'), findsOneWidget);
  });

  testWidgets('Ana ekran tamamlanan günlük hedefi servisten gösterir', (
    tester,
  ) async {
    final streakService = StreakService(repository: FakeDailyProgressStore());
    addTearDown(streakService.dispose);
    await streakService.initialize();
    for (var count = 0; count < streakService.dailyGoal; count++) {
      await streakService.recordEvaluation();
    }
    final xpService = await createXpService();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
    );
    addTearDown(statisticsService.dispose);
    final home = await createTestHomeScreen(
      streakService: streakService,
      xpService: xpService,
      statisticsService: statisticsService,
    );
    addTearDown(home.settingsService.dispose);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: home.screen),
    );

    expect(find.text('🔥 8 günlük seri'), findsNothing);
    expect(find.text('8 gün'), findsOneWidget);
    expect(find.text('5 / 5'), findsOneWidget);
    expect(find.text('Günlük hedef tamamlandı'), findsOneWidget);
  });

  testWidgets('Ana ekran seviye kartını gerçek XP servisinden gösterir', (
    tester,
  ) async {
    final streakService = StreakService(repository: FakeDailyProgressStore());
    final xpService = await createXpService(totalXp: 1005);
    addTearDown(streakService.dispose);
    addTearDown(xpService.dispose);
    await streakService.initialize();
    final statisticsService = createStatisticsService(
      streakService: streakService,
      xpService: xpService,
    );
    addTearDown(statisticsService.dispose);
    final home = await createTestHomeScreen(
      streakService: streakService,
      xpService: xpService,
      statisticsService: statisticsService,
    );
    addTearDown(home.settingsService.dispose);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: home.screen),
    );

    expect(find.text('Seviye 2'), findsOneWidget);
    expect(find.text('5 / 1000 XP'), findsOneWidget);
    final levelProgress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator).at(1),
    );
    expect(levelProgress.value, 0.005);
  });

  testWidgets(
    'Günlük görev kartı hedef üstü sayacı yalnızca görünümde sınırlar',
    (tester) async {
      final streakService = StreakService(repository: FakeDailyProgressStore());
      addTearDown(streakService.dispose);
      await streakService.initialize();
      for (var count = 0; count < 52; count++) {
        await streakService.recordEvaluation();
      }
      final xpService = await createXpService();
      final statisticsService = createStatisticsService(
        streakService: streakService,
        xpService: xpService,
      );
      addTearDown(statisticsService.dispose);
      final home = await createTestHomeScreen(
        streakService: streakService,
        xpService: xpService,
        statisticsService: statisticsService,
      );
      addTearDown(home.settingsService.dispose);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: home.screen),
      );

      expect(streakService.todayCount, 52);
      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('52 / 5'), findsNothing);
      expect(find.text('Günlük hedef tamamlandı'), findsOneWidget);

      final taskProgress = tester
          .widgetList<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          )
          .last;
      expect(taskProgress.value, 1.0);
    },
  );

  testWidgets('on sekiz kategori kartı ve içerikleri bulunur', (tester) async {
    await pumpKelimoApp(tester);

    for (final category in [
      'Hayvanlar',
      'Yiyecekler',
      'Renkler',
      'Ev',
      'Aile',
      'Ulaşım',
      'Günlük Rutinler',
      'Okul',
      'Giysiler',
      'Vücut',
      'Sağlık',
      'Şehir ve Mekânlar',
      'Doğa ve Hava Durumu',
      'Zaman ve Tarihler',
      'Sayılar ve Miktarlar',
      'Temel Fiiller',
      'Yaygın Sıfatlar',
      'Duygular',
    ]) {
      await tester.scrollUntilVisible(find.text(category), 200);
      expect(find.text(category), findsOneWidget);
    }
  });

  testWidgets('Gerçek kategoriler mock yüzde veya Yakında göstermez', (
    tester,
  ) async {
    await pumpKelimoApp(tester);

    for (final mockPercentage in ['%45', '%60', '%50', '%20']) {
      expect(find.text(mockPercentage), findsNothing);
    }

    await tester.scrollUntilVisible(find.text('Ulaşım'), 300);
    expect(find.text('Yakında'), findsNothing);
  });

  testWidgets(
    'Yeni kategori ortak kart, flashcard, quiz ve istatistik akışını kullanır',
    (tester) async {
      await pumpKelimoApp(tester);
      await tester.scrollUntilVisible(find.text('Günlük Rutinler'), 300);

      final categoryCard = find.ancestor(
        of: find.text('Günlük Rutinler'),
        matching: find.byType(Card),
      );
      expect(categoryCard, findsOneWidget);
      expect(
        find.descendant(of: categoryCard, matching: find.text('30 kelime')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: categoryCard, matching: find.text('Yakında')),
        findsNothing,
      );

      await tester.tap(find.text('Günlük Rutinler'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryScreen), findsOneWidget);
      expect(find.text('0 / 30 kelime'), findsOneWidget);

      await tester.tap(find.text('Öğrenmeye Başla'));
      await tester.pumpAndSettle();
      expect(find.byType(WordCardScreen), findsOneWidget);
      expect(find.text('WAKE UP'), findsOneWidget);
      expect(find.text('1 / 30'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiz Çöz'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryQuizScreen), findsOneWidget);
      expect(find.text('Günlük Rutinler Quiz'), findsOneWidget);
      expect(
        CategoryCatalog.dailyRoutines.words,
        contains(currentQuizWord(tester, CategoryCatalog.dailyRoutines.words)),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('İstatistik'));
      await tester.pumpAndSettle();
      expect(find.text('Günlük Rutinler İstatistikleri'), findsOneWidget);
      expect(find.text('Günlük Rutinler performansı'), findsOneWidget);
    },
  );

  testWidgets(
    'İkinci paket kategorisi ortak karttan flashcard quiz ve istatistiğe gider',
    (tester) async {
      await pumpKelimoApp(tester);
      await tester.scrollUntilVisible(find.text('Doğa ve Hava Durumu'), 300);

      final categoryCard = find.ancestor(
        of: find.text('Doğa ve Hava Durumu'),
        matching: find.byType(Card),
      );
      expect(categoryCard, findsOneWidget);
      expect(
        find.descendant(of: categoryCard, matching: find.text('30 kelime')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: categoryCard, matching: find.text('Yakında')),
        findsNothing,
      );

      await tester.ensureVisible(categoryCard);
      await tester.pumpAndSettle();
      await tester.tap(categoryCard);
      await tester.pumpAndSettle();
      expect(find.byType(CategoryScreen), findsOneWidget);
      expect(find.text('0 / 30 kelime'), findsOneWidget);

      await tester.tap(find.text('Öğrenmeye Başla'));
      await tester.pumpAndSettle();
      expect(find.byType(WordCardScreen), findsOneWidget);
      expect(find.text('NATURE'), findsOneWidget);
      expect(find.text('1 / 30'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quiz Çöz'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryQuizScreen), findsOneWidget);
      expect(find.text('Doğa ve Hava Durumu Quiz'), findsOneWidget);
      expect(
        CategoryCatalog.natureWeather.words,
        contains(currentQuizWord(tester, CategoryCatalog.natureWeather.words)),
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('İstatistik'));
      await tester.pumpAndSettle();
      expect(find.text('Doğa ve Hava Durumu İstatistikleri'), findsOneWidget);
      expect(find.text('Doğa ve Hava Durumu performansı'), findsOneWidget);
    },
  );

  testWidgets('On sekiz kategori kartı küçük iPhone genişliğinde taşmaz', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    await pumpKelimoApp(tester);

    await tester.scrollUntilVisible(find.text('Duygular'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Duygular'), findsOneWidget);
    expect(find.text('Yakında'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uygulama Türkçe ve Material 3 kullanır', (tester) async {
    await pumpKelimoApp(tester);

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.locale, const Locale('tr', 'TR'));
    expect(app.theme?.useMaterial3, isTrue);
    expect(app.darkTheme?.useMaterial3, isTrue);
    expect(app.theme?.scaffoldBackgroundColor, AppColors.lightBackground);
    expect(app.darkTheme?.scaffoldBackgroundColor, AppColors.darkBackground);
    expect(app.theme?.colorScheme.primary, AppColors.turquoise);
    expect(app.theme?.colorScheme.secondary, AppColors.warmOrange);
  });

  testWidgets('Hayvanlar kartı kategori detay ekranını açar', (tester) async {
    await pumpKelimoApp(tester);

    await openAnimalsCategory(tester);

    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(find.text('Hayvanlar'), findsOneWidget);
    expect(find.text('30 kelime'), findsOneWidget);
    expect(find.text('Kategori ilerlemesi'), findsOneWidget);
    expect(find.text('0 / 30 kelime'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);
    expect(find.text('Öğrenmeye Başla'), findsOneWidget);
    expect(find.text('Quiz Çöz'), findsOneWidget);
    expect(find.text('İstatistik'), findsOneWidget);
    expect(find.text('Son çalışmalar'), findsOneWidget);
    expect(find.text('Dog'), findsOneWidget);
    expect(find.text('Köpek'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('Yiyecekler ekranı ve ilk flashcard ortak akışı kullanır', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openFoodsCategory(tester);

    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(find.text('Yiyecekler'), findsOneWidget);
    expect(find.text('30 kelime'), findsOneWidget);
    expect(find.text('0 / 30 kelime'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Elma'), findsOneWidget);

    await tester.tap(find.text('Öğrenmeye Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Yiyecekler'), findsOneWidget);
    expect(find.text('1 / 30'), findsOneWidget);
    expect(find.text('APPLE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-card')));
    await tester.pumpAndSettle();
    expect(find.text('ELMA'), findsOneWidget);
    expect(find.text('I eat an apple.'), findsOneWidget);
    expect(find.text('Elma yerim.'), findsOneWidget);
  });

  testWidgets('Yiyecekler flashcard TTSye İngilizce kelimeyi gönderir', (
    tester,
  ) async {
    final engine = FakeTtsEngine();
    final xpService = await createXpService();
    addTearDown(xpService.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.foods,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: engine),
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pumpAndSettle();

    expect(engine.spokenTexts, ['Apple']);
  });

  testWidgets('Uzun flashcard kelimeleri küçük ekranda tek satıra sığar', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(280, 700));
    final xpService = await createXpService();
    addTearDown(xpService.dispose);

    final longWords = [
      ...foodWords.where(
        (word) => const {
          'Strawberry',
          'Watermelon',
          'Chocolate',
        }.contains(word.english),
      ),
      ...colorWords.where(
        (word) => const {
          'Light Blue',
          'Dark Blue',
          'Colorful',
        }.contains(word.english),
      ),
      ...homeWords.where(
        (word) => const {
          'Living Room',
          'Refrigerator',
          'Washing Machine',
        }.contains(word.english),
      ),
    ];
    for (final word in longWords) {
      final english = word.english;
      final category = LearningCategory(
        id: 'layout-test',
        title: 'Test',
        emoji: word.emoji,
        words: [word],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: WordCardScreen(
            key: ValueKey('word-card-$english'),
            category: category,
            wordProgressStore: FakeWordProgressStore(),
            xpService: xpService,
            ttsService: EnglishTtsService(engine: FakeTtsEngine()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final label = english.toUpperCase();
      final scalableText = find.byType(ScaleDownSingleLineText);
      expect(find.text(label), findsOneWidget);
      expect(scalableText, findsOneWidget);
      expect(
        tester
            .widget<FittedBox>(
              find.descendant(
                of: scalableText,
                matching: find.byType(FittedBox),
              ),
            )
            .fit,
        BoxFit.scaleDown,
      );
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(text.overflow, TextOverflow.visible);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Kısa flashcard kelimesi mevcut temel yazı stilini korur', (
    tester,
  ) async {
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WordCardScreen(
          category: CategoryCatalog.foods,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: FakeTtsEngine()),
        ),
      ),
    );

    final scalableText = tester.widget<ScaleDownSingleLineText>(
      find.byType(ScaleDownSingleLineText),
    );
    final expectedFontSize = Theme.of(
      tester.element(find.byType(WordCardScreen)),
    ).textTheme.displayMedium?.fontSize;
    expect(find.text('APPLE'), findsOneWidget);
    expect(scalableText.style?.fontSize, expectedFontSize);
    expect(scalableText.style?.fontWeight, FontWeight.bold);
    expect(scalableText.style?.letterSpacing, 2);
  });

  testWidgets(
    'Flashcard arka yüzü ve quiz sorusu tek satır ölçekleme kullanır',
    (tester) async {
      final xpStorage = FakeXpStorage();
      final xpService = await createXpService(
        repository: FakeXpStore(xpStorage),
      );
      addTearDown(xpService.dispose);
      final chocolate = foodWords.firstWhere(
        (word) => word.english == 'Chocolate',
      );
      final category = LearningCategory(
        id: 'layout-test',
        title: 'Test',
        emoji: chocolate.emoji,
        words: [chocolate],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: WordCardScreen(
            category: category,
            wordProgressStore: FakeWordProgressStore(),
            xpService: xpService,
            ttsService: EnglishTtsService(engine: FakeTtsEngine()),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('word-card')));
      await tester.pumpAndSettle();

      expect(find.text('ÇİKOLATA'), findsOneWidget);
      expect(find.byType(ScaleDownSingleLineText), findsOneWidget);
      expect(tester.widget<Text>(find.text('ÇİKOLATA')).maxLines, 1);

      final lightBlue = colorWords.firstWhere(
        (word) => word.english == 'Light Blue',
      );
      final quizCategory = LearningCategory(
        id: 'layout-quiz',
        title: 'Test',
        emoji: lightBlue.emoji,
        words: [lightBlue, ...colorWords.take(3)],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CategoryQuizScreen(
            category: quizCategory,
            quizStore: FakeQuizStore(FakeQuizStorage(), xpStorage),
            xpService: xpService,
            random: NoShuffleRandom(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LIGHT BLUE'), findsOneWidget);
      expect(find.byType(ScaleDownSingleLineText), findsOneWidget);
      expect(tester.widget<Text>(find.text('LIGHT BLUE')).maxLines, 1);
    },
  );

  testWidgets('Uzun Ev ifadeleri küçük ekranda tek satırda kalır', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(280, 700));
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    final expectations = {
      'Bedroom': 'YATAK ODASI',
      'Living Room': 'OTURMA ODASI',
      'Washing Machine': 'ÇAMAŞIR MAKİNESİ',
    };

    for (final entry in expectations.entries) {
      final word = homeWords.firstWhere((item) => item.english == entry.key);
      await tester.pumpWidget(
        MaterialApp(
          home: WordCardScreen(
            key: ValueKey('home-layout-${word.id}'),
            category: LearningCategory(
              id: 'home-layout',
              title: 'Ev',
              emoji: word.emoji,
              words: [word],
            ),
            wordProgressStore: FakeWordProgressStore(),
            xpService: xpService,
            ttsService: EnglishTtsService(engine: FakeTtsEngine()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.key.toUpperCase()), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('word-card')));
      await tester.pumpAndSettle();
      final backText = tester.widget<Text>(find.text(entry.value));
      expect(backText.maxLines, 1);
      expect(backText.softWrap, isFalse);
      expect(tester.takeException(), isNull);
    }

    final washingMachine = homeWords.firstWhere(
      (word) => word.english == 'Washing Machine',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryQuizScreen(
          category: LearningCategory(
            id: 'home-layout-quiz',
            title: 'Ev',
            emoji: washingMachine.emoji,
            words: [washingMachine, ...homeWords.take(3)],
          ),
          quizStore: FakeQuizStore(FakeQuizStorage(), FakeXpStorage()),
          xpService: xpService,
          random: NoShuffleRandom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WASHING MACHINE'), findsOneWidget);
    expect(tester.widget<Text>(find.text('WASHING MACHINE')).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Önemli Aile ifadeleri küçük ekranda tek satırda kalır', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(280, 700));
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    final expectations = {
      'Grandmother': 'BÜYÜKANNE',
      'Grandfather': 'BÜYÜKBABA',
      'Grandparents': 'BÜYÜKANNE VE BÜYÜKBABA',
      'Brother': 'ERKEK KARDEŞ',
      'Aunt': 'TEYZE / HALA',
    };

    for (final entry in expectations.entries) {
      final word = familyWords.firstWhere((item) => item.english == entry.key);
      await tester.pumpWidget(
        MaterialApp(
          home: WordCardScreen(
            key: ValueKey('family-layout-${word.id}'),
            category: LearningCategory(
              id: 'family-layout',
              title: 'Aile',
              emoji: word.emoji,
              words: [word],
            ),
            wordProgressStore: FakeWordProgressStore(),
            xpService: xpService,
            ttsService: EnglishTtsService(engine: FakeTtsEngine()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final frontLabel = entry.key.toUpperCase();
      final frontText = tester.widget<Text>(find.text(frontLabel));
      expect(frontText.maxLines, 1);
      expect(frontText.softWrap, isFalse);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('word-card')));
      await tester.pumpAndSettle();
      final backText = tester.widget<Text>(find.text(entry.value));
      expect(backText.maxLines, 1);
      expect(backText.softWrap, isFalse);
      expect(tester.takeException(), isNull);
    }

    final grandparents = familyWords.firstWhere(
      (word) => word.english == 'Grandparents',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryQuizScreen(
          category: LearningCategory(
            id: 'family-layout-quiz',
            title: 'Aile',
            emoji: grandparents.emoji,
            words: [grandparents, ...familyWords.take(3)],
          ),
          quizStore: FakeQuizStore(FakeQuizStorage(), FakeXpStorage()),
          xpService: xpService,
          random: NoShuffleRandom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('GRANDPARENTS'), findsOneWidget);
    expect(tester.widget<Text>(find.text('GRANDPARENTS')).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Önemli Ulaşım ifadeleri küçük ekranda tek satırda kalır', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(280, 700));
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    final expectations = {
      'Motorcycle': 'MOTOSİKLET',
      'Helicopter': 'HELİKOPTER',
      'Ambulance': 'AMBULANS',
      'Fire Truck': 'İTFAİYE ARACI',
      'Police Car': 'POLİS ARABASI',
    };

    for (final entry in expectations.entries) {
      final word = transportationWords.firstWhere(
        (item) => item.english == entry.key,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: WordCardScreen(
            key: ValueKey('transportation-layout-${word.id}'),
            category: LearningCategory(
              id: 'transportation-layout',
              title: 'Ulaşım',
              emoji: word.emoji,
              words: [word],
            ),
            wordProgressStore: FakeWordProgressStore(),
            xpService: xpService,
            ttsService: EnglishTtsService(engine: FakeTtsEngine()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final frontLabel = entry.key.toUpperCase();
      final frontText = tester.widget<Text>(find.text(frontLabel));
      expect(frontText.maxLines, 1);
      expect(frontText.softWrap, isFalse);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('word-card')));
      await tester.pumpAndSettle();
      final backText = tester.widget<Text>(find.text(entry.value));
      expect(backText.maxLines, 1);
      expect(backText.softWrap, isFalse);
      expect(tester.takeException(), isNull);
    }

    final fireTruck = transportationWords.firstWhere(
      (word) => word.english == 'Fire Truck',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CategoryQuizScreen(
          category: LearningCategory(
            id: 'transportation-layout-quiz',
            title: 'Ulaşım',
            emoji: fireTruck.emoji,
            words: [fireTruck, ...transportationWords.take(3)],
          ),
          quizStore: FakeQuizStore(FakeQuizStorage(), FakeXpStorage()),
          xpService: xpService,
          random: NoShuffleRandom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FIRE TRUCK'), findsOneWidget);
    expect(tester.widget<Text>(find.text('FIRE TRUCK')).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Yiyecekler quizi foods kimliğiyle kaydedilir', (tester) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openFoodsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Yiyecekler Quiz'), findsOneWidget);
    expect(foodWords, contains(currentQuizWord(tester, foodWords)));
    expect(
      animalWords.any(
        (word) => find
            .byKey(ValueKey('quiz-question-${word.id}'))
            .evaluate()
            .isNotEmpty,
      ),
      isFalse,
    );

    await completeQuiz(tester, words: foodWords);

    expect(quizStorage.attempts.single.categoryId, 'foods');
    expect(find.text('Yiyecekler Quizi Tamamlandı'), findsOneWidget);
  });

  testWidgets('Renkler ekranı ve ilk flashcard ortak akışı kullanır', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openColorsCategory(tester);

    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(find.text('Renkler'), findsOneWidget);
    expect(find.text('30 kelime'), findsOneWidget);
    expect(find.text('0 / 30 kelime'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);
    expect(find.text('Red'), findsOneWidget);
    expect(find.text('Kırmızı'), findsOneWidget);

    await tester.tap(find.text('Öğrenmeye Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Renkler'), findsOneWidget);
    expect(find.text('1 / 30'), findsOneWidget);
    expect(find.text('RED'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-card')));
    await tester.pumpAndSettle();
    expect(find.text('KIRMIZI'), findsOneWidget);
    expect(find.text('The apple is red.'), findsOneWidget);
    expect(find.text('Elma kırmızıdır.'), findsOneWidget);
  });

  testWidgets('Renkler flashcard TTSye İngilizce kelimeyi gönderir', (
    tester,
  ) async {
    final engine = FakeTtsEngine();
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.colors,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: engine),
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pumpAndSettle();

    expect(engine.spokenTexts, ['Red']);
  });

  testWidgets('Renkler quizi colors kimliğiyle kaydedilir', (tester) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openColorsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Renkler Quiz'), findsOneWidget);
    expect(colorWords, contains(currentQuizWord(tester, colorWords)));

    await completeQuiz(tester, words: colorWords);

    expect(quizStorage.attempts.single.categoryId, 'colors');
    expect(find.text('Renkler Quizi Tamamlandı'), findsOneWidget);
  });

  testWidgets('Ev ekranı ve ilk flashcard ortak akışı kullanır', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openHomeCategory(tester);

    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(find.text('Ev'), findsWidgets);
    expect(find.text('30 kelime'), findsOneWidget);
    expect(find.text('0 / 30 kelime'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);
    expect(find.text('House'), findsOneWidget);

    await tester.tap(find.text('Öğrenmeye Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Ev'), findsOneWidget);
    expect(find.text('1 / 30'), findsOneWidget);
    expect(find.text('HOUSE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-card')));
    await tester.pumpAndSettle();
    expect(find.text('EV'), findsOneWidget);
    expect(find.text('This is my house.'), findsOneWidget);
    expect(find.text('Bu benim evim.'), findsOneWidget);
  });

  testWidgets('Ev flashcard TTSye İngilizce kelimeyi gönderir', (tester) async {
    final engine = FakeTtsEngine();
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.home,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: engine),
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pumpAndSettle();

    expect(engine.spokenTexts, ['House']);
  });

  testWidgets('Ev quizi home kimliğiyle kaydedilir', (tester) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openHomeCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Ev Quiz'), findsOneWidget);
    expect(homeWords, contains(currentQuizWord(tester, homeWords)));

    await completeQuiz(tester, words: homeWords);

    expect(quizStorage.attempts.single.categoryId, 'home');
    expect(find.text('Ev Quizi Tamamlandı'), findsOneWidget);
  });

  testWidgets('Aile kartı ve ilk flashcard ortak akışı kullanır', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await tester.scrollUntilVisible(find.text('Aile'), 300);

    final familyCard = find.ancestor(
      of: find.text('Aile'),
      matching: find.byType(Card),
    );
    expect(familyCard, findsOneWidget);
    expect(
      find.descendant(of: familyCard, matching: find.text('30 kelime')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: familyCard, matching: find.text('Yakında')),
      findsNothing,
    );

    await openFamilyCategory(tester);
    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(find.text('Aile'), findsWidgets);
    expect(find.text('30 kelime'), findsOneWidget);
    expect(find.text('0 / 30 kelime'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);
    expect(find.text('Family'), findsOneWidget);

    await tester.tap(find.text('Öğrenmeye Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Aile'), findsOneWidget);
    expect(find.text('1 / 30'), findsOneWidget);
    expect(find.text('FAMILY'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-card')));
    await tester.pumpAndSettle();
    expect(find.text('AİLE'), findsOneWidget);
    expect(find.text('This is my family.'), findsOneWidget);
    expect(find.text('Bu benim ailem.'), findsOneWidget);
  });

  testWidgets('Aile flashcard TTSye İngilizce kelimeyi gönderir', (
    tester,
  ) async {
    final engine = FakeTtsEngine();
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.family,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: engine),
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pumpAndSettle();

    expect(engine.spokenTexts, ['Family']);
  });

  testWidgets('Aile quizi family kimliğiyle kaydedilir', (tester) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openFamilyCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Aile Quiz'), findsOneWidget);
    expect(familyWords, contains(currentQuizWord(tester, familyWords)));

    await completeQuiz(tester, words: familyWords);

    expect(quizStorage.attempts.single.categoryId, 'family');
    expect(find.text('Aile Quizi Tamamlandı'), findsOneWidget);
  });

  testWidgets('Aile istatistik ekranı family kategorisiyle açılır', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openFamilyCategory(tester);
    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();

    expect(find.text('Aile İstatistikleri'), findsOneWidget);
    expect(find.text('Aile performansı'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Ev performansı'), findsNothing);
  });

  testWidgets('Ulaşım kartı ve ilk flashcard ortak akışı kullanır', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await tester.scrollUntilVisible(find.text('Ulaşım'), 300);

    final transportationCard = find.ancestor(
      of: find.text('Ulaşım'),
      matching: find.byType(Card),
    );
    expect(transportationCard, findsOneWidget);
    expect(
      find.descendant(of: transportationCard, matching: find.text('30 kelime')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: transportationCard, matching: find.text('Yakında')),
      findsNothing,
    );

    await openTransportationCategory(tester);
    expect(find.byType(CategoryScreen), findsOneWidget);
    expect(find.text('Ulaşım'), findsOneWidget);
    expect(find.text('30 kelime'), findsOneWidget);
    expect(find.text('0 / 30 kelime'), findsOneWidget);
    expect(find.text('%0 tamamlandı'), findsOneWidget);
    expect(find.text('Car'), findsOneWidget);

    await tester.tap(find.text('Öğrenmeye Başla'));
    await tester.pumpAndSettle();

    expect(find.text('Ulaşım'), findsOneWidget);
    expect(find.text('1 / 30'), findsOneWidget);
    expect(find.text('CAR'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('word-card')));
    await tester.pumpAndSettle();
    expect(find.text('ARABA'), findsOneWidget);
    expect(find.text('The car is red.'), findsOneWidget);
    expect(find.text('Araba kırmızı.'), findsOneWidget);
  });

  testWidgets('Ulaşım flashcard TTSye İngilizce kelimeyi gönderir', (
    tester,
  ) async {
    final engine = FakeTtsEngine();
    final xpService = await createXpService();
    addTearDown(xpService.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          category: CategoryCatalog.transportation,
          wordProgressStore: FakeWordProgressStore(),
          xpService: xpService,
          ttsService: EnglishTtsService(engine: engine),
        ),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pumpAndSettle();

    expect(engine.spokenTexts, ['Car']);
  });

  testWidgets('Ulaşım quizi transportation kimliğiyle kaydedilir', (
    tester,
  ) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openTransportationCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Ulaşım Quiz'), findsOneWidget);
    expect(
      transportationWords,
      contains(currentQuizWord(tester, transportationWords)),
    );

    await completeQuiz(tester, words: transportationWords);

    expect(quizStorage.attempts.single.categoryId, 'transportation');
    expect(find.text('Ulaşım Quizi Tamamlandı'), findsOneWidget);
  });

  testWidgets('Ulaşım istatistik ekranı transportation kategorisiyle açılır', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openTransportationCategory(tester);
    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();

    expect(find.text('Ulaşım İstatistikleri'), findsOneWidget);
    expect(find.text('Ulaşım performansı'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Aile performansı'), findsNothing);
  });

  testWidgets(
    'Ana ekran, kategori ekranı ve istatistik ekranı aynı öğrenilen sayısını kullanır',
    (tester) async {
      final records = <String, WordProgress>{};
      for (var index = 0; index < animalWords.length; index++) {
        final word = animalWords[index];
        records[word.id] = testWordProgress(
          wordId: word.id,
          mastery: index < 22 ? 'easy' : 'hard',
          repetitionCount: 1,
        );
      }

      await pumpKelimoApp(
        tester,
        wordProgressStore: FakeWordProgressStore(records),
      );

      expect(find.text('22 / 540 kelime'), findsOneWidget);
      expect(find.text('8 kelime öğreniliyor'), findsOneWidget);
      final generalProgress = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('general-progress')),
      );
      expect(generalProgress.value, 22 / 540);

      await tester.scrollUntilVisible(find.text('Hayvanlar'), 300);
      expect(find.text('%73'), findsOneWidget);

      await tester.tap(find.text('Hayvanlar'));
      await tester.pumpAndSettle();
      expect(find.text('22 / 30 kelime'), findsOneWidget);
      expect(find.text('%73 tamamlandı'), findsOneWidget);

      await tester.tap(find.text('İstatistik'));
      await tester.pumpAndSettle();
      expect(find.text('Öğrenilen'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
    },
  );

  testWidgets('Bütün kelimeler öğrenildiğinde genel ilerleme tamamlanır', (
    tester,
  ) async {
    final records = {
      for (final word in CategoryCatalog.categories.expand(
        (category) => category.words,
      ))
        word.id: testWordProgress(
          wordId: word.id,
          mastery: 'easy',
          repetitionCount: 1,
        ),
    };

    await pumpKelimoApp(
      tester,
      wordProgressStore: FakeWordProgressStore(records),
    );

    expect(find.text('540 / 540 kelime'), findsOneWidget);
    expect(find.text('Tüm kelimeleri öğrendin!'), findsOneWidget);
    final generalProgress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('general-progress')),
    );
    expect(generalProgress.value, 1.0);
  });

  testWidgets(
    'Kelime değerlendirmesinden sonra kategori ilerlemesi yenilenir',
    (tester) async {
      final wordStore = FakeWordProgressStore();
      await pumpKelimoApp(tester, wordProgressStore: wordStore);

      await openAnimalsCategory(tester);
      expect(find.text('0 / 30 kelime'), findsOneWidget);

      await tester.tap(find.text('Öğrenmeye Başla'));
      await tester.pumpAndSettle();
      await selectLearningRating(tester, 'Kolay');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('1 / 30 kelime'), findsOneWidget);
      expect(find.text('%3 tamamlandı'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Hayvanlar'), 300);
      expect(find.text('%3'), findsOneWidget);
    },
  );

  testWidgets('Kategori İstatistik kartı gerçek kategori özetini açar', (
    tester,
  ) async {
    await pumpKelimoApp(tester);
    await openAnimalsCategory(tester);

    await tester.tap(find.text('İstatistik'));
    await tester.pumpAndSettle();

    expect(find.text('Hayvanlar İstatistikleri'), findsOneWidget);
    expect(find.text('Hayvanlar performansı'), findsOneWidget);
    expect(find.text('Toplam kelime'), findsOneWidget);
    expect(find.text('Değerlendirilen'), findsOneWidget);
    expect(find.text('Öğrenilen'), findsOneWidget);
    expect(find.text('Ortalama mastery'), findsOneWidget);
    expect(find.text('Tamamlanan quiz'), findsOneWidget);
    expect(find.text('En yüksek skor'), findsOneWidget);
    expect(find.text('Ortalama quiz'), findsOneWidget);
  });

  testWidgets('Öğrenmeye Başla ilk kelime kartını açar ve kart çevrilir', (
    tester,
  ) async {
    await pumpKelimoApp(tester);

    await openAnimalsCategory(tester);
    await tester.tap(find.text('Öğrenmeye Başla'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 30'), findsOneWidget);
    expect(find.text('DOG'), findsOneWidget);
    expect(find.text('Kartı çevirmek için dokun'), findsOneWidget);
    expect(find.text('Dinle'), findsOneWidget);
    expect(find.text('Favori'), findsOneWidget);
    expect(find.text('Bu kelime nasıldı?'), findsOneWidget);
    expect(find.text('Önceki'), findsOneWidget);
    expect(find.text('Sonraki'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('word-card')));
    await tester.pumpAndSettle();

    expect(find.text('KÖPEK'), findsOneWidget);
    expect(find.text('The dog is sleeping.'), findsOneWidget);
    expect(find.text('Köpek uyuyor.'), findsOneWidget);

    await tester.ensureVisible(find.text('Sonraki'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    expect(find.text('2 / 30'), findsOneWidget);
    expect(find.text('CAT'), findsOneWidget);
    expect(find.text('Kartı çevirmek için dokun'), findsOneWidget);

    await tester.tap(find.text('Önceki'));
    await tester.pumpAndSettle();

    expect(find.text('1 / 30'), findsOneWidget);
    expect(find.text('DOG'), findsOneWidget);
  });

  testWidgets('Quiz seçimi kilitlenir ve doğru cevap gösterilir', (
    tester,
  ) async {
    await pumpKelimoApp(tester);

    await openAnimalsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Hayvanlar Quiz'), findsOneWidget);
    expect(find.text('Soru 1 / 10'), findsOneWidget);
    expect(find.text('Doğru Türkçe karşılığı seç'), findsOneWidget);
    final firstWord = currentQuizWord(tester, animalWords);
    final wrongAnswer = visibleWrongQuizAnswer(
      tester,
      animalWords,
      firstWord.turkish,
    );

    var nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sonraki Soru'),
    );
    expect(nextButton.onPressed, isNull);

    final wrongOption = find.byKey(ValueKey('quiz-option-$wrongAnswer'));
    await tester.ensureVisible(wrongOption);
    await tester.pumpAndSettle();
    await tester.tap(wrongOption);
    await tester.pump();

    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final lockedOption = tester.widget<InkWell>(wrongOption);
    expect(lockedOption.onTap, isNull);

    nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sonraki Soru'),
    );
    expect(nextButton.onPressed, isNotNull);

    await tester.ensureVisible(find.text('Sonraki Soru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sonraki Soru'));
    await tester.pumpAndSettle();

    expect(find.text('Soru 2 / 10'), findsOneWidget);
    expect(currentQuizWord(tester, animalWords).id, isNot(firstWord.id));
    expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
  });

  testWidgets('Quiz tamamlanınca sonuç gösterilir ve tekrar başlatılır', (
    tester,
  ) async {
    final quizStorage = FakeQuizStorage();
    await pumpKelimoApp(tester, quizStorage: quizStorage);

    await openAnimalsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();
    await completeQuiz(tester);

    expect(find.text('Tebrikler!'), findsOneWidget);
    expect(find.text('Hayvanlar Quizi Tamamlandı'), findsOneWidget);
    expect(find.text('10 / 10'), findsOneWidget);
    expect(find.text('%100 başarı'), findsOneWidget);
    expect(find.text('Mükemmel!'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
    expect(find.text('10 doğru'), findsOneWidget);
    expect(find.text('7 doğru'), findsNothing);
    expect(find.text('1 dk 42 sn'), findsNothing);
    expect(find.text('+25 XP'), findsOneWidget);
    expect(find.text('🏆 Kusursuz sonuç! +25 XP kazandın.'), findsOneWidget);
    expect(quizStorage.attempts.single.categoryId, 'animals');

    await tester.ensureVisible(find.text('Tekrar Çöz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrar Çöz'));
    await tester.pumpAndSettle();

    expect(find.text('Hayvanlar Quiz'), findsOneWidget);
    expect(find.text('Soru 1 / 10'), findsOneWidget);
    final nextButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Sonraki Soru'),
    );
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('Quiz gerçek süreyi gösterir ve tekrar çöz sayaçları sıfırlar', (
    tester,
  ) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    final xpService = await createXpService(repository: FakeXpStore(xpStorage));
    addTearDown(xpService.dispose);
    final quizStore = FakeQuizStore(quizStorage, xpStorage);
    final startedAt = DateTime(2026, 7, 16, 12);
    var currentTime = startedAt;

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryQuizScreen(
          category: CategoryCatalog.animals,
          quizStore: quizStore,
          xpService: xpService,
          now: () => currentTime,
        ),
      ),
    );
    await completeQuiz(
      tester,
      beforeAnswer: (index) {
        if (index == 9) {
          currentTime = startedAt.add(const Duration(seconds: 42));
        }
      },
    );

    expect(find.text('10 doğru'), findsOneWidget);
    expect(find.text('42 sn'), findsOneWidget);
    expect(xpStorage.state.totalXp, 25);

    await tester.ensureVisible(find.text('Tekrar Çöz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tekrar Çöz'));
    await tester.pumpAndSettle();
    final retryStartedAt = currentTime;

    await completeQuiz(
      tester,
      answerPattern: [
        false,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
      ],
      beforeAnswer: (index) {
        if (index == 9) {
          currentTime = retryStartedAt.add(const Duration(seconds: 6));
        }
      },
    );

    expect(find.text('9 / 10'), findsOneWidget);
    expect(find.text('9 doğru'), findsOneWidget);
    expect(find.text('6 sn'), findsOneWidget);
    expect(find.text('10 doğru'), findsNothing);
    expect(quizStorage.attempts, hasLength(2));
    expect(xpStorage.state.totalXp, 25);
  });

  testWidgets('Sonuç ekranı rebuild olduğunda quiz ve XP ikinci kez eklenmez', (
    tester,
  ) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openAnimalsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();
    await completeQuiz(tester);

    expect(quizStorage.attempts, hasLength(1));
    expect(xpStorage.state.totalXp, 25);

    await tester.binding.setSurfaceSize(const Size(700, 1000));
    await tester.pumpAndSettle();

    expect(find.text('🏆 Kusursuz sonuç! +25 XP kazandın.'), findsOneWidget);
    expect(quizStorage.attempts, hasLength(1));
    expect(xpStorage.state.totalXp, 25);
  });

  testWidgets('Düşük quiz sonucu kaydedilir fakat XP kazandırmaz', (
    tester,
  ) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    await pumpKelimoApp(tester, xpStorage: xpStorage, quizStorage: quizStorage);
    await openAnimalsCategory(tester);
    await tester.tap(find.text('Quiz Çöz'));
    await tester.pumpAndSettle();
    await completeQuiz(tester, perfect: false);

    expect(find.text('%90 başarı'), findsOneWidget);
    expect(find.text('0 XP'), findsOneWidget);
    expect(find.text('🏆 Kusursuz sonuç! +25 XP kazandın.'), findsNothing);
    expect(quizStorage.attempts.single.xpAwarded, 0);
    expect(xpStorage.state.totalXp, 0);
  });

  testWidgets(
    '250 XP ile kusursuz quiz sonrası ana ekran ve yeniden açılış 275 gösterir',
    (tester) async {
      final xpStorage = FakeXpStorage(totalXp: 250);
      final quizStorage = FakeQuizStorage();
      await pumpKelimoApp(
        tester,
        xpStorage: xpStorage,
        quizStorage: quizStorage,
      );
      await openAnimalsCategory(tester);
      await tester.tap(find.text('Quiz Çöz'));
      await tester.pumpAndSettle();
      await completeQuiz(tester);

      await tester.ensureVisible(find.text('Ana Sayfa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Sayfa'));
      await tester.pumpAndSettle();
      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 1000),
        1000,
      );
      await tester.pumpAndSettle();
      expect(find.text('275 / 1000 XP'), findsOneWidget);

      await pumpKelimoApp(
        tester,
        xpStorage: xpStorage,
        quizStorage: quizStorage,
      );
      expect(find.text('275 / 1000 XP'), findsOneWidget);
      expect(quizStorage.attempts, hasLength(1));
    },
  );

  testWidgets('Sonuç ekranı dönüş butonlarını doğru callbacklere bağlar', (
    tester,
  ) async {
    var selectedAction = '';

    Widget resultScreen() => MaterialApp(
      home: QuizResultScreen(
        categoryName: 'Hayvanlar',
        correctAnswerCount: 8,
        totalQuestionCount: 10,
        successPercentage: 80,
        xpAwarded: 0,
        longestCorrectStreak: 3,
        elapsedDuration: const Duration(seconds: 72),
        onRetry: () => selectedAction = 'retry',
        onReturnToCategory: () => selectedAction = 'category',
        onReturnHome: () => selectedAction = 'home',
      ),
    );

    await tester.pumpWidget(resultScreen());
    expect(find.text('0 XP'), findsOneWidget);
    expect(find.text('3 doğru'), findsOneWidget);
    expect(find.text('1 dk 12 sn'), findsOneWidget);
    expect(find.text('🏆 Kusursuz sonuç! +25 XP kazandın.'), findsNothing);
    await tester.ensureVisible(find.text('Kategoriye Dön'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kategoriye Dön'));
    expect(selectedAction, 'category');

    selectedAction = '';
    await tester.pumpWidget(resultScreen());
    await tester.ensureVisible(find.text('Ana Sayfa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Sayfa'));
    expect(selectedAction, 'home');
  });

  testWidgets('Quiz sonuç başlığı verilen kategori adını kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QuizResultScreen(
          categoryName: 'Renkler',
          correctAnswerCount: 8,
          totalQuestionCount: 10,
          successPercentage: 80,
          xpAwarded: 0,
          longestCorrectStreak: 4,
          elapsedDuration: const Duration(seconds: 42),
          onRetry: () {},
          onReturnToCategory: () {},
          onReturnHome: () {},
        ),
      ),
    );

    expect(find.text('Renkler Quizi Tamamlandı'), findsOneWidget);
    expect(find.text('Hayvanlar Quizi Tamamlandı'), findsNothing);
  });

  testWidgets(
    'Quiz sonucu yalnızca doğal çıkışta reklam dener ve hata navigasyonu engellemez',
    (tester) async {
      final ads = FakeInterstitialAdService()..showSucceeds = false;
      addTearDown(ads.dispose);
      await ads.recordQuizCompleted();
      await ads.recordQuizCompleted();
      await ads.recordQuizCompleted();
      var action = '';

      await tester.pumpWidget(
        MaterialApp(
          home: QuizResultScreen(
            categoryName: 'Hayvanlar',
            correctAnswerCount: 8,
            totalQuestionCount: 10,
            successPercentage: 80,
            xpAwarded: 0,
            longestCorrectStreak: 3,
            elapsedDuration: const Duration(seconds: 30),
            interstitialAdService: ads,
            onRetry: () => action = 'retry',
            onReturnToCategory: () => action = 'category',
            onReturnHome: () => action = 'home',
          ),
        ),
      );

      await tester.scrollUntilVisible(find.text('Tekrar Çöz'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tekrar Çöz'));
      expect(action, 'retry');
      expect(ads.showCalls, 0);

      action = '';
      await tester.scrollUntilVisible(find.text('Ana Sayfa'), 180);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana Sayfa'));
      await tester.pump();
      expect(ads.showCalls, 1);
      expect(action, 'home');
    },
  );

  testWidgets('Reklam kapanınca sayaç sıfırlanır', (tester) async {
    final ads = FakeInterstitialAdService();
    addTearDown(ads.dispose);
    for (var index = 0; index < 3; index++) {
      await ads.recordQuizCompleted();
    }
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: QuizResultScreen(
          categoryName: 'Hayvanlar',
          correctAnswerCount: 10,
          totalQuestionCount: 10,
          successPercentage: 100,
          xpAwarded: 25,
          longestCorrectStreak: 10,
          elapsedDuration: const Duration(seconds: 30),
          interstitialAdService: ads,
          onRetry: () {},
          onReturnToCategory: () => returned = true,
          onReturnHome: () {},
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('Kategoriye Dön'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kategoriye Dön'));
    await tester.pump();

    expect(returned, isTrue);
    expect(ads.storage.state.completedQuizCountSinceLastAd, 0);
    expect(ads.storage.state.lastInterstitialShownAt, isNotNull);
  });

  testWidgets('Ortak quiz verilen kategori kimliğiyle kayıt oluşturur', (
    tester,
  ) async {
    final xpStorage = FakeXpStorage();
    final quizStorage = FakeQuizStorage();
    final xpService = await createXpService(repository: FakeXpStore(xpStorage));
    addTearDown(xpService.dispose);
    final category = LearningCategory(
      id: 'test-category',
      title: 'Test Kategorisi',
      emoji: '🧪',
      words: animalWords.take(10).toList(growable: false),
    );
    final ads = FakeInterstitialAdService();
    addTearDown(ads.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CategoryQuizScreen(
          category: category,
          quizStore: FakeQuizStore(quizStorage, xpStorage),
          xpService: xpService,
          interstitialAdService: ads,
        ),
      ),
    );
    await completeQuiz(tester);

    expect(quizStorage.attempts.single.categoryId, 'test-category');
    expect(ads.storage.state.completedQuizCountSinceLastAd, 1);
    expect(find.text('Test Kategorisi Quizi Tamamlandı'), findsOneWidget);
  });
}
