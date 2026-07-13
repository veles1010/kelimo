import 'package:flutter/material.dart';

void main() {
  runApp(const KelimoApp());
}

class KelimoApp extends StatelessWidget {
  const KelimoApp({super.key});

  static const _seedColor = Color(0xFFF28C62);

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: brightness,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kelimo',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Kelimo',
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kelimeleri keşfet, öğrenmenin keyfini çıkar.',
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () {},
                  child: const Text('Öğrenmeye başla'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
