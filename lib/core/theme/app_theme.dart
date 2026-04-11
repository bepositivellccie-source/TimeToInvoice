import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF1A56DB); // bleu confiance
  static const _bgColor = Color(0xFFF8FAFC);
  static const _surfaceColor = Colors.white;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primaryColor,
          brightness: Brightness.light,
          surface: _surfaceColor,
        ),
        scaffoldBackgroundColor: _bgColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: _surfaceColor,
          foregroundColor: Color(0xFF111827),
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: _surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _primaryColor, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
