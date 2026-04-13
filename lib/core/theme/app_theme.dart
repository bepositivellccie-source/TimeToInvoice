import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'design_tokens.dart';

class AppTheme {
  // ─── Base text theme (Plus Jakarta Sans — depuis Figma) ─────────────────

  static TextTheme get _baseTextTheme => GoogleFonts.plusJakartaSansTextTheme();

  // ─── Light ──────────────────────────────────────────────────────────────

  static ThemeData get light {
    final textTheme = _baseTextTheme.apply(
      bodyColor: FigmaSecondary.c500,
      displayColor: FigmaSecondary.c500,
    );

    return ThemeData(
      useMaterial3: true,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.textMuted,
        error: AppColors.danger,
        surface: Colors.white,
        onSurface: AppColors.textDark,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: FigmaSecondary.c500,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: FigmaType.title,
          fontWeight: FontWeight.w600,
          color: FigmaSecondary.c500,
          letterSpacing: FigmaType.letterSpacingTight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.lg),
          side: BorderSide(color: FigmaSecondary.c100),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: FigmaPrimary.c500,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FigmaRadius.md),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: FigmaType.subtitle,
            fontWeight: FontWeight.w600,
            letterSpacing: FigmaType.letterSpacing,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FigmaPrimary.c500,
          side: BorderSide(color: FigmaSecondary.c200),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FigmaRadius.md),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: FigmaType.body1,
            fontWeight: FontWeight.w600,
            letterSpacing: FigmaType.letterSpacing,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FigmaPrimary.c500,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: FigmaType.body1,
            fontWeight: FontWeight.w600,
            letterSpacing: FigmaType.letterSpacing,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.md),
          borderSide: BorderSide(color: FigmaPrimary.c500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.md),
          borderSide: BorderSide(color: FigmaError.c500, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FigmaSpacing.lg,
          vertical: FigmaSpacing.lg,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: FigmaSecondary.c300,
          fontSize: FigmaType.body1,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: FigmaSecondary.c400,
          fontSize: FigmaType.body1,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: FigmaSecondary.c100,
        thickness: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: FigmaPrimary.c500,
        unselectedItemColor: FigmaSecondary.c300,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FigmaPrimary.c100,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: FigmaType.body2,
          fontWeight: FontWeight.w600,
          color: FigmaPrimary.c600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.full),
        ),
      ),
    );
  }

  // ─── Dark ───────────────────────────────────────────────────────────────

  static ThemeData get dark {
    final textTheme = _baseTextTheme.apply(
      bodyColor: const Color(0xFFE2E8F0),
      displayColor: const Color(0xFFF1F5F9),
    );

    const darkBg = Color(0xFF0F172A);
    const darkSurface = Color(0xFF1E293B);
    const darkBorder = Color(0xFF334155);
    const darkTextPrimary = Color(0xFFF1F5F9);
    const darkTextSecondary = Color(0xFF94A3B8);

    return ThemeData(
      useMaterial3: true,
      textTheme: textTheme,
      colorScheme: ColorScheme.fromSeed(
        seedColor: FigmaPrimary.c500,
        brightness: Brightness.dark,
        primary: FigmaPrimary.c400,
        onPrimary: FigmaSecondary.c900,
        secondary: darkTextSecondary,
        error: FigmaError.c400,
        surface: darkSurface,
        onSurface: darkTextPrimary,
      ),
      scaffoldBackgroundColor: darkBg,
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: FigmaType.title,
          fontWeight: FontWeight.w600,
          color: darkTextPrimary,
          letterSpacing: FigmaType.letterSpacingTight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.lg),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: FigmaPrimary.c500,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FigmaRadius.md),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: FigmaType.subtitle,
            fontWeight: FontWeight.w600,
            letterSpacing: FigmaType.letterSpacing,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FigmaPrimary.c300,
          side: const BorderSide(color: darkBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FigmaRadius.md),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: FigmaType.body1,
            fontWeight: FontWeight.w600,
            letterSpacing: FigmaType.letterSpacing,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: FigmaPrimary.c300,
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: FigmaType.body1,
            fontWeight: FontWeight.w600,
            letterSpacing: FigmaType.letterSpacing,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.md),
          borderSide: BorderSide(color: FigmaPrimary.c400, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.md),
          borderSide: BorderSide(color: FigmaError.c400, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FigmaSpacing.lg,
          vertical: FigmaSpacing.lg,
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          color: darkTextSecondary,
          fontSize: FigmaType.body1,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: darkTextSecondary,
          fontSize: FigmaType.body1,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: FigmaPrimary.c400,
        unselectedItemColor: darkTextSecondary,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: darkSurface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: FigmaPrimary.c900,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: FigmaType.body2,
          fontWeight: FontWeight.w600,
          color: FigmaPrimary.c300,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FigmaRadius.full),
        ),
      ),
    );
  }
}
