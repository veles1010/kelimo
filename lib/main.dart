import 'package:flutter/material.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/services/streak_service.dart';
import 'package:kelimo/theme/app_theme.dart';

void main() {
  runApp(const KelimoApp());
}

class KelimoApp extends StatefulWidget {
  const KelimoApp({super.key});

  @override
  State<KelimoApp> createState() => _KelimoAppState();
}

class _KelimoAppState extends State<KelimoApp> {
  final StreakService _streakService = StreakService();

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
      home: HomeScreen(streakService: _streakService),
    );
  }
}
