import 'package:flutter/material.dart';
import 'package:kelimo/data/local/database_service.dart';
import 'package:kelimo/repositories/daily_progress_repository.dart';
import 'package:kelimo/repositories/word_progress_repository.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/theme/app_theme.dart';

void main() {
  runApp(const KelimoApp());
}

class KelimoApp extends StatefulWidget {
  const KelimoApp({super.key, this.wordProgressStore, this.dailyProgressStore});

  final WordProgressStore? wordProgressStore;
  final DailyProgressStore? dailyProgressStore;

  @override
  State<KelimoApp> createState() => _KelimoAppState();
}

class _KelimoAppState extends State<KelimoApp> {
  late final WordProgressStore _wordProgressStore;
  late final DailyProgressStore _dailyProgressStore;
  late final StreakService _streakService;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    final databaseService = DatabaseService();
    _wordProgressStore =
        widget.wordProgressStore ?? WordProgressRepository(databaseService);
    _dailyProgressStore =
        widget.dailyProgressStore ?? DailyProgressRepository(databaseService);
    _streakService = StreakService(repository: _dailyProgressStore);
    _initialization = _initializePersistence();
  }

  Future<void> _initializePersistence() async {
    try {
      await _wordProgressStore.initialize();
    } catch (error, stackTrace) {
      debugPrint('Kelime verileri olmadan devam ediliyor: $error\n$stackTrace');
    }
    await _streakService.initialize();
  }

  @override
  void dispose() {
    _streakService.dispose();
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
          );
        },
      ),
    );
  }
}
