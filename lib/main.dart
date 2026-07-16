import 'package:flutter/material.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/repositories/daily_progress_repository.dart';
import 'package:kelimo/repositories/data_reset_repository.dart';
import 'package:kelimo/repositories/quiz_repository.dart';
import 'package:kelimo/repositories/settings_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/repositories/xp_repository.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/services/data_management_service.dart';
import 'package:kelimo/services/settings_service.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/services/statistics_service.dart';
import 'package:kelimo/services/xp_service.dart';
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
  });

  final WordProgressStore? wordProgressStore;
  final DailyProgressStore? dailyProgressStore;
  final XpStore? xpStore;
  final QuizStore? quizStore;
  final SettingsStore? settingsStore;
  final DataResetStore? dataResetStore;

  @override
  State<KelimoApp> createState() => _KelimoAppState();
}

class _KelimoAppState extends State<KelimoApp> {
  late final WordProgressStore _wordProgressStore;
  late final DailyProgressStore _dailyProgressStore;
  late final StreakService _streakService;
  late final XpService _xpService;
  late final QuizStore _quizStore;
  late final StatisticsService _statisticsService;
  late final SettingsService _settingsService;
  late final DataManagementService _dataManagementService;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
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
    _xpService = XpService(
      repository: widget.xpStore ?? XpRepository(databaseService),
    );
    _quizStore = widget.quizStore ?? QuizRepository(databaseService);
    _statisticsService = StatisticsService(
      wordProgressStore: _wordProgressStore,
      quizStore: _quizStore,
      streakService: _streakService,
      xpService: _xpService,
    );
    _dataManagementService = DataManagementService(
      repository: widget.dataResetStore ?? DataResetRepository(databaseService),
      wordProgressStore: _wordProgressStore,
      quizStore: _quizStore,
      streakService: _streakService,
      xpService: _xpService,
      settingsService: _settingsService,
      statisticsService: _statisticsService,
    );
    _initialization = _initializePersistence();
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
  }

  @override
  void dispose() {
    _streakService.dispose();
    _xpService.dispose();
    _statisticsService.dispose();
    _settingsService.dispose();
    _dataManagementService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelimo',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: FutureBuilder<void>(
        future: _initialization,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return HomeScreen(
            streakService: _streakService,
            wordProgressStore: _wordProgressStore,
            xpService: _xpService,
            quizStore: _quizStore,
            statisticsService: _statisticsService,
            settingsService: _settingsService,
            dataManagementService: _dataManagementService,
          );
        },
      ),
    );
  }
}
