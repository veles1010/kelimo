import 'package:flutter/material.dart';

abstract final class AppColors {
  static const turquoise = Color(0xFF159D9A);
  static const warmOrange = Color(0xFFF28C4B);
  static const lightBackground = Color(0xFFFFF9F1);
  static const darkBackground = Color(0xFF121C1D);
}

abstract final class AppDimensions {
  static const buttonRadius = 16.0;
  static const cardRadius = 20.0;
  static const cardPadding = EdgeInsets.all(20);
}

abstract final class AppTheme {
  static ThemeData get light => _createTheme(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    onBackground: const Color(0xFF243333),
    cardColor: const Color(0xFFFFFFFF),
  );

  static ThemeData get dark => _createTheme(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    onBackground: const Color(0xFFE4ECEB),
    cardColor: const Color(0xFF1B292A),
  );

  static ThemeData _createTheme({
    required Brightness brightness,
    required Color background,
    required Color onBackground,
    required Color cardColor,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.turquoise,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? const Color(0xFF71D5D0) : AppColors.turquoise,
          onPrimary: isDark ? const Color(0xFF003736) : Colors.white,
          secondary: isDark ? const Color(0xFFFFB783) : AppColors.warmOrange,
          onSecondary: isDark ? const Color(0xFF522300) : Colors.white,
          surface: background,
          onSurface: onBackground,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: cardColor,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
      ),
    );
  }
}
