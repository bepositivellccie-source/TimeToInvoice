import 'package:flutter/material.dart';

class AppColors {
  static const primary     = Color(0xFF305DA8);
  static const primaryDark = Color(0xFF305DA8);
  static const primarySurf = Color(0xFFE8EBFA);
  static const textDark    = Color(0xFF1A1F3C);
  static const textMuted   = Color(0xFF8B90A7);
  static const background  = Color(0xFFF7F8FC);

  // Statuts — uniquement pour les badges projet
  static const statusActive   = Color(0xFF639922);
  static const statusActiveBg = Color(0xFFEAF3DE);
  static const statusWait     = Color(0xFFBA7517);
  static const statusWaitBg   = Color(0xFFFAEEDA);
  static const statusDone     = Color(0xFF888780);
  static const statusDoneBg   = Color(0xFFF1EFE8);

  // Destructif
  static const danger     = Color(0xFFE24B4A);
  static const dangerSurf = Color(0xFFFCEBEB);

  // ─── Dark-aware semantic colors ──────────────────────────────────────────
  static bool _isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  /// Gray-700 light / Slate-200 dark — body text
  static Color textBody(BuildContext c) => _isDark(c)
      ? const Color(0xFFE2E8F0)
      : const Color(0xFF374151);

  /// Gray-500 light / Slate-300 dark — secondary/muted text
  static Color textSecondary(BuildContext c) => _isDark(c)
      ? const Color(0xFFCBD5E1)
      : const Color(0xFF6B7280);

  /// Gray-400 light / Slate-400 dark — tertiary/hint text, icons
  static Color textTertiary(BuildContext c) => _isDark(c)
      ? const Color(0xFF94A3B8)
      : const Color(0xFF9CA3AF);

  /// Gray-100 light / Slate-800 dark — input fills, card bg
  static Color surfaceFill(BuildContext c) => _isDark(c)
      ? const Color(0xFF1E293B)
      : const Color(0xFFF3F4F6);

  /// Gray-200 light / Slate-700 dark — borders, dividers
  static Color border(BuildContext c) => _isDark(c)
      ? const Color(0xFF334155)
      : const Color(0xFFE5E7EB);

  /// Gray-300 light / Slate-600 dark — unselected chips, subtle borders
  static Color borderStrong(BuildContext c) => _isDark(c)
      ? const Color(0xFF475569)
      : const Color(0xFFD1D5DB);
}
