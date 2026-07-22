import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/repositories/daily_progress_repository.dart';
import 'package:kelimo/repositories/achievement_repository.dart';
import 'package:kelimo/repositories/data_reset_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/settings_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/repositories/ad_frequency_repository.dart';
import 'package:kelimo/repositories/category_unlock_repository.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/services/data_management_service.dart';
import 'package:kelimo/services/achievement_service.dart';
import 'package:kelimo/services/app_navigation_controller.dart';
import 'package:kelimo/services/daily_reminder_service.dart';
import 'package:kelimo/services/learning_center_service.dart';
import 'package:kelimo/services/notification_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/xp_service.dart';
import 'package:kelimo/services/interstitial_ad_service.dart';
import 'package:kelimo/services/category_access_service.dart';
import 'package:kelimo/services/rewarded_ad_service.dart';
import 'package:kelimo/services/rewarded_bonus_service.dart';
import 'package:kelimo/screens/onboarding_screen.dart';
import 'package:kelimo/theme/app_theme.dart';

void main() {
  runApp(const KelimoApp());
}

class KelimoApp extends StatefulWidget {
  const KelimoApp({
    super.key,
    this.wordProgressStore,
    this.dailyProgressStore,
    this.xpStore,
    this.quizStore,
    this.settingsStore,
    this.dataResetStore,
    this.achievementStore,
    this.notificationService,
    this.navigationController,
    this.interstitialAdService,
    this.categoryUnlockStore,
    this.rewardedAdService,
  });

  final WordProgressStore? wordProgressStore;
  final DailyProgressStore? dailyProgressStore;
  final XpStore? xpStore;
  final QuizStore? quizStore;
  final SettingsStore? settingsStore;
  final DataResetStore? dataResetStore;
  final AchievementStore? achievementStore;
  final NotificationService? notificationService;
  final AppNavigationController? navigationController;
  final InterstitialAdService? interstitialAdService;
  final CategoryUnlockStore? categoryUnlockStore;
  final RewardedAdService? rewardedAdService;

  @override
  State<KelimoApp> createState() => _KelimoAppState();
}

class _KelimoAppState extends State<KelimoApp> with WidgetsBindingObserver {
  late final WordProgressStore _wordProgressStore;
  late final DailyProgressStore _dailyProgressStore;
  late final StreakService _streakService;
  late final XpService _xpService;
  late final QuizStore _quizStore;
  late final StatisticsService _statisticsService;
  late final SettingsService _settingsService;
  late final DataManagementService _dataManagementService;
  late final AchievementService _achievementService;
  late final LearningCenterService _learningCenterService;
  late final NotificationService _notificationService;
  late final bool _ownsNotificationService;
  late final DailyReminderService _dailyReminderService;
  late final AppNavigationController _navigationController;
  late final bool _ownsNavigationController;
  late final InterstitialAdService _interstitialAdService;
  late final CategoryAccessService _categoryAccessService;
  late final RewardedBonusService _rewardedBonusService;
  late final bool _ownsInterstitialAdService;
  late final StreamSubscription<String> _notificationPayloadSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final Future<void> _initialization;
  bool _adsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final databaseService = DatabaseService();
    _wordProgressStore =
        widget.wordProgressStore ?? WordProgressRepository(databaseService);
    _dailyProgressStore =
        widget.dailyProgressStore ?? DailyProgressRepository(databaseService);
    _settingsService = SettingsService(
      repository: widget.settingsStore ?? SettingsRepository(databaseService),
    );
    _streakService = StreakService(
      repository: _dailyProgressStore,
      settingsService: _settingsService,
    );
    final xpStore = widget.xpStore ?? XpRepository(databaseService);
    _xpService = XpService(repository: xpStore);
    _quizStore = widget.quizStore ?? QuizRepository(databaseService);
    _categoryAccessService = CategoryAccessService(
      repository:
          widget.categoryUnlockStore ??
          (widget.wordProgressStore == null
              ? CategoryUnlockRepository(databaseService)
              : MemoryCategoryUnlockStore()),
      wordProgressStore: _wordProgressStore,
      quizStore: _quizStore,
      xpService: _xpService,
    );
    _statisticsService = StatisticsService(
      wordProgressStore: _wordProgressStore,
      quizStore: _quizStore,
      streakService: _streakService,
      xpService: _xpService,
    );
    _learningCenterService = LearningCenterService(
      wordProgressStore: _wordProgressStore,
    );
    _ownsNotificationService = widget.notificationService == null;
    _notificationService =
        widget.notificationService ?? LocalNotificationService();
    _dailyReminderService = DailyReminderService(
      settingsService: _settingsService,
      notificationService: _notificationService,
      learningCenterService: _learningCenterService,
    );
    _ownsInterstitialAdService = widget.interstitialAdService == null;
    _interstitialAdService =
        widget.interstitialAdService ??
        GoogleInterstitialAdService(AdFrequencyRepository(databaseService));
    final rewardedAdService =
        widget.rewardedAdService ??
        (widget.xpStore == null
            ? GoogleRewardedAdService(_interstitialAdService)
            : DisabledRewardedAdService());
    final rewardedXpStore = xpStore is RewardedXpStore
        ? xpStore as RewardedXpStore
        : MemoryRewardedXpStore();
    _rewardedBonusService = RewardedBonusService(
      repository: rewardedXpStore,
      adService: rewardedAdService,
      xpService: _xpService,
    );
    _ownsNavigationController = widget.navigationController == null;
    _navigationController =
        widget.navigationController ?? AppNavigationController();
    _notificationPayloadSubscription = _dailyReminderService.payloads.listen(
      _handleNotificationPayload,
    );
    _achievementService = AchievementService(
      repository:
          widget.achievementStore ?? AchievementRepository(databaseService),
      metricsLoader: AchievementMetricsLoader(
        wordProgressStore: _wordProgressStore,
        quizStore: _quizStore,
        streakService: _streakService,
      ),
    );
    _dataManagementService = DataManagementService(
      repository: widget.dataResetStore ?? DataResetRepository(databaseService),
      wordProgressStore: _wordProgressStore,
      quizStore: _quizStore,
      streakService: _streakService,
      xpService: _xpService,
      settingsService: _settingsService,
      statisticsService: _statisticsService,
      achievementService: _achievementService,
      dailyReminderService: _dailyReminderService,
      categoryAccessService: _categoryAccessService,
      rewardedBonusService: _rewardedBonusService,
    );
    _initialization = _initializePersistence();
  }

  void _handleNotificationPayload(String payload) {
    if (!_navigationController.handlePayload(payload)) return;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  Future<void> _initializePersistence() async {
    try {
      await _wordProgressStore.initialize();
    } catch (error, stackTrace) {
      debugPrint('Kelime verileri olmadan devam ediliyor: $error\n$stackTrace');
    }
    await _settingsService.initialize();
    await _streakService.initialize();
    await _xpService.initialize();
    await _categoryAccessService.initialize();
    await _achievementService.initialize();
    await _dailyReminderService.initialize();
    if (_settingsService.onboardingCompleted) {
      await _initializeAdsOnce();
    } else {
      await _rewardedBonusService.refresh();
    }
    try {
      _navigationController.handlePayload(
        await _dailyReminderService.getLaunchPayload(),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Bildirim başlangıç yönlendirmesi okunamadı: $error\n$stackTrace',
      );
    }
  }

  Future<void> _initializeAdsOnce() async {
    if (_adsInitialized) return;
    _adsInitialized = true;
    await _interstitialAdService.initialize();
    await _rewardedBonusService.initialize();
  }

  Future<void> _completeInitialOnboarding() async {
    await _settingsService.completeOnboarding();
    unawaited(_initializeAdsOnce());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _interstitialAdService.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      unawaited(_streakService.refresh());
      unawaited(_dailyReminderService.refreshSchedule());
      unawaited(_rewardedBonusService.refresh());
      unawaited(_rewardedBonusService.adService.preload());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_notificationPayloadSubscription.cancel());
    _streakService.dispose();
    _xpService.dispose();
    _categoryAccessService.dispose();
    _rewardedBonusService.dispose();
    _statisticsService.dispose();
    _settingsService.dispose();
    _dataManagementService.dispose();
    _achievementService.dispose();
    _dailyReminderService.dispose();
    if (_ownsNotificationService) _notificationService.dispose();
    if (_ownsNavigationController) _navigationController.dispose();
    if (_ownsInterstitialAdService) _interstitialAdService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsService,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Kelimo',
        debugShowCheckedModeBanner: false,
        locale: const Locale('tr', 'TR'),
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _settingsService.materialThemeMode,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.systemUiOverlayStyle(Theme.of(context).brightness),
          child: child!,
        ),
        home: FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (!_settingsService.onboardingCompleted) {
              return OnboardingScreen(onComplete: _completeInitialOnboarding);
            }
            return HomeScreen(
              streakService: _streakService,
              wordProgressStore: _wordProgressStore,
              xpService: _xpService,
              quizStore: _quizStore,
              statisticsService: _statisticsService,
              settingsService: _settingsService,
              dataManagementService: _dataManagementService,
              achievementService: _achievementService,
              learningCenterService: _learningCenterService,
              dailyReminderService: _dailyReminderService,
              navigationController: _navigationController,
              interstitialAdService: _interstitialAdService,
              categoryAccessService: _categoryAccessService,
              rewardedBonusService: _rewardedBonusService,
            );
          },
        ),
      ),
    );
  }
}
