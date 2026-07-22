import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppColors {
  static const turquoise = Color(0xFF159D9A);
  static const warmOrange = Color(0xFFF28C4B);
  static const lightBackground = Color(0xFFFFF9F1);
  static const darkBackground = Color(0xFF0E1720);
}

abstract final class AppDimensions {
  static const buttonRadius = 16.0;
  static const cardRadius = 20.0;
  static const cardPadding = EdgeInsets.all(20);
}

abstract final class AppTheme {
  static SystemUiOverlayStyle systemUiOverlayStyle(Brightness brightness) =>
      (brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent);

  static ThemeData get light => _createTheme(
    brightness: Brightness.light,
    background: AppColors.lightBackground,
    onBackground: const Color(0xFF243333),
    cardColor: const Color(0xFFFFFFFF),
    elevatedSurface: const Color(0xFFFFFDFC),
    outline: const Color(0xFF71807F),
  );

  static ThemeData get dark => _createTheme(
    brightness: Brightness.dark,
    background: AppColors.darkBackground,
    onBackground: const Color(0xFFE6EDF3),
    cardColor: const Color(0xFF182633),
    elevatedSurface: const Color(0xFF223441),
    outline: const Color(0xFF8A9BA8),
  );

  static ThemeData _createTheme({
    required Brightness brightness,
    required Color background,
    required Color onBackground,
    required Color cardColor,
    required Color elevatedSurface,
    required Color outline,
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
          surfaceContainer: cardColor,
          surfaceContainerHigh: elevatedSurface,
          surfaceContainerHighest: isDark
              ? const Color(0xFF2B404E)
              : const Color(0xFFF4EDE5),
          outline: outline,
          outlineVariant: isDark
              ? const Color(0xFF405461)
              : const Color(0xFFD4C8BE),
          errorContainer: isDark
              ? const Color(0xFF5B2027)
              : const Color(0xFFFFDAD6),
          onErrorContainer: isDark
              ? const Color(0xFFFFDAD9)
              : const Color(0xFF410002),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      cardColor: cardColor,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemUiOverlayStyle(brightness),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
      dialogTheme: DialogThemeData(
        backgroundColor: elevatedSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevatedSurface,
        modalBackgroundColor: elevatedSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardColor,
        indicatorColor: colorScheme.primaryContainer,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: elevatedSurface,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        helperStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.buttonRadius),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevatedSurface,
        contentTextStyle: TextStyle(color: onBackground),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}
