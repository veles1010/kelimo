import 'package:flutter/material.dart';
import 'package:kelimo/screens/home_screen.dart';
import 'package:kelimo/theme/app_theme.dart';

void main() {
  runApp(const KelimoApp());
}

class KelimoApp extends StatelessWidget {
  const KelimoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelimo',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
