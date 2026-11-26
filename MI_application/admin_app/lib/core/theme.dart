import 'package:flutter/material.dart';

class AppTheme {
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const homeAvatarSize = 48.0;
  static const homeDonutSize = 104.0;
  static const homeKpiHeight = 120.0;
  static const homeActionHeight = 60.0;
  static const pageSpacing = 20.0;
  static const cardPadding = 18.0;
  static const sectionSpacing = 24.0;
  static const cardRadius = 22.0;
  static const buttonRadius = 18.0;
  static const fieldRadius = 16.0;
  static const pillRadius = 20.0;
  static const surface = Colors.white;
  static const onPrimary = Colors.white;
  static const onPrimaryMuted = Colors.white70;
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
  static const border = Color(0xFFDDE5DF);
  static const shadow = Color(0x12000000);
  static const warn = Color(0xFFE65100);
  static const amber = Color(0xFF9A6A00);
  static const amberSoft = Color(0xFFFFF3D9);
  static const taskSell = Color(0xFF0277BD);
  static const taskVet = Color(0xFF6A1B9A);
  static const taskButcher = Color(0xFF8D4E00);
  static const taskWeight = Color(0xFF00838F);

  static ThemeData get theme {
    OutlineInputBorder inputBorder(Color color, [double width = 1.2]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(56),
          side: const BorderSide(color: border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        hintStyle: const TextStyle(fontSize: 17, color: Colors.black38),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        focusedBorder: inputBorder(primary, 2),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primary,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillRadius),
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(buttonRadius),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textDark,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(fieldRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: Colors.white,
        indicatorColor: primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? primary : textGrey,
            )),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
      ),
    );
  }
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
