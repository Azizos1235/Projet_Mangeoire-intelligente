import 'package:flutter/material.dart';

/// Shared colors and Material theme for the application.
class AppTheme {
  static const primary = Color(0xFF2E7D32);
  static const primarySoft = Color(0xFFE5F2E6);
  static const appetiteIncreasing = Color(0xFF2F80ED);
  static const appetiteIncreasingSoft = Color(0xFFEAF2FF);
  static const appetiteDecreasing = Color(0xFFE5484D);
  static const appetiteDecreasingSoft = Color(0xFFFFECEC);
  static const appetiteStable = Color(0xFF2E7D32);
  static const appetiteStableSoft = Color(0xFFE8F5E9);
  static const background = Color(0xFFF5F7F2);
  static const textDark = Color(0xFF1F2A24);
  static const textGrey = Color(0xFF6E7B73);
  static const error = Color(0xFFB3261E);
  static const border = Color(0xFFDDE5DF);
  static const disabledSurface = Color(0xFFE0E0E0);
  static const disabledText = Color(0xFF757575);
  static const shadow = Color(0x12000000);
  static const scanAccent = Color(0xFF66BB6A);
  static const scanAccentSoft = Color(0x8866BB6A);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
        scaffoldBackgroundColor: background,
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: textDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            minimumSize: const Size.fromHeight(60),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle:
                const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          hintStyle: const TextStyle(fontSize: 17, color: Colors.black38),
          border: _border(border, 1.2),
          enabledBorder: _border(border, 1.2),
          focusedBorder: _border(primary, 2),
        ),
      );

  static OutlineInputBorder _border(Color c, double w) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: c, width: w),
      );
}

enum AppetiteTrend { increasing, decreasing, stable }

extension AppetiteTrendStyle on AppetiteTrend {
  Color get color => switch (this) {
        AppetiteTrend.increasing => AppTheme.appetiteIncreasing,
        AppetiteTrend.decreasing => AppTheme.appetiteDecreasing,
        AppetiteTrend.stable => AppTheme.appetiteStable,
      };

  Color get lightColor => switch (this) {
        AppetiteTrend.increasing => AppTheme.appetiteIncreasingSoft,
        AppetiteTrend.decreasing => AppTheme.appetiteDecreasingSoft,
        AppetiteTrend.stable => AppTheme.appetiteStableSoft,
      };

  IconData get icon => switch (this) {
        AppetiteTrend.increasing => Icons.trending_up_rounded,
        AppetiteTrend.decreasing => Icons.trending_down_rounded,
        AppetiteTrend.stable => Icons.trending_flat_rounded,
      };

  String get labelFr => switch (this) {
        AppetiteTrend.increasing => 'En hausse',
        AppetiteTrend.decreasing => 'En baisse',
        AppetiteTrend.stable => 'Stable',
      };

  String get labelAr => switch (this) {
        AppetiteTrend.increasing => 'في ارتفاع',
        AppetiteTrend.decreasing => 'في انخفاض',
        AppetiteTrend.stable => 'مستقر',
      };

  static AppetiteTrend? parse(String? value) =>
      switch (value?.trim().toLowerCase().replaceAll('-', '_')) {
        'high' ||
        'increasing' ||
        'increased' ||
        'increase' =>
          AppetiteTrend.increasing,
        'low' ||
        'decreasing' ||
        'decreased' ||
        'decrease' =>
          AppetiteTrend.decreasing,
        'normal' || 'stable' || 'steady' => AppetiteTrend.stable,
        _ => null,
      };
}
