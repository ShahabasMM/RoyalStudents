import 'package:flutter/material.dart';

class AppTheme {
  static const navy = Color(0xFF082B6F);
  static const navyDark = Color(0xFF061D4A);
  static const purple = Color(0xFF7C3AED);
  static const softPurple = Color(0xFFF0E8FF);
  static const background = Color(0xFFF8F7FC);
  static const outline = Color(0xFFE5E1EF);
  static const muted = Color(0xFF68708A);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: purple,
      ),
      fontFamily: 'Arial',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: navy,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
      ),
    );
  }
}
