import 'package:flutter/material.dart';

class AppTheme {
  static const primary = Color(0xFF1B4332);
  static const accent = Color(0xFF2D6A4F);
  static const primarySoft = Color(0xFFE3EFE7);
  static const bg = Color(0xFFF3F5F1);
  static const textDark = Color(0xFF16231C);
  static const textGrey = Color(0xFF66756C);
  static const line = Color(0xFFE0E6DF);
  static const warn = Color(0xFFE65100);
  static const amber = Color(0xFF9A6A00);
  static const amberSoft = Color(0xFFFFF3D9);

  static ThemeData get theme {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: accent, primary: primary),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textDark,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: textDark),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: line, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        border: border(line),
        enabledBorder: border(line),
        focusedBorder: border(primary, 1.6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primarySoft,
        labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
