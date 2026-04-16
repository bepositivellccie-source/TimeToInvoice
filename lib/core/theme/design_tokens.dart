import 'package:flutter/material.dart';

/// Design tokens extraits du template Figma (Y7eWQkg1WoNz9iJU5NfkLI)
/// Font : Plus Jakarta Sans
/// Palette : Primary, Secondary, Success, Error, Warning, Information

// ─── Primary ────────────────────────────────────────────────────────────────

class FigmaPrimary {
  static const Color c900 = Color(0xFF305DA8);
  static const Color c800 = Color(0xFF305DA8);
  static const Color c700 = Color(0xFF305DA8);
  static const Color c600 = Color(0xFF305DA8);
  static const Color c500 = Color(0xFF305DA8); // ← couleur principale
  static const Color c400 = Color(0xFF305DA8);
  static const Color c300 = Color(0xFF305DA8);
  static const Color c200 = Color(0xFF305DA8);
  static const Color c100 = Color(0xFF305DA8);
  static const Color c0   = Color(0xFFFFFFFF);
}

// ─── Secondary (neutrals / dark text) ───────────────────────────────────────

class FigmaSecondary {
  static const Color c900 = Color(0xFF030410);
  static const Color c800 = Color(0xFF060713);
  static const Color c700 = Color(0xFF0A0A18);
  static const Color c600 = Color(0xFF0E0F1D);
  static const Color c500 = Color(0xFF141522); // ← texte principal (light)
  static const Color c400 = Color(0xFF54577A); // ← texte secondaire
  static const Color c300 = Color(0xFF8E92BC); // ← placeholder, hint
  static const Color c200 = Color(0xFFC2C6E8); // ← bordures
  static const Color c100 = Color(0xFFDFE1F3); // ← fond cards, dividers
}

// ─── Semantic ───────────────────────────────────────────────────────────────

class FigmaSuccess {
  static const Color c700 = Color(0xFF659711);
  static const Color c500 = Color(0xFF9CD323);
  static const Color c300 = Color(0xFFD3F178);
  static const Color c100 = Color(0xFFF5FCD2);
}

class FigmaError {
  static const Color c700 = Color(0xFFB71112);
  static const Color c500 = Color(0xFFFF4423);
  static const Color c400 = Color(0xFFFF7F59);
  static const Color c300 = Color(0xFFFFA37A);
  static const Color c100 = Color(0xFFFFE7D3);
}

class FigmaWarning {
  static const Color c700 = Color(0xFFB7821D);
  static const Color c500 = Color(0xFFFFC73A);
  static const Color c300 = Color(0xFFFFE488);
  static const Color c100 = Color(0xFFFFF8D7);
}

class FigmaInfo {
  static const Color c700 = Color(0xFF305DA8);
  static const Color c500 = Color(0xFF305DA8);
  static const Color c300 = Color(0xFF305DA8);
  static const Color c100 = Color(0xFF305DA8);
}

// ─── Spacing (base 8dp grid, adapté mobile) ─────────────────────────────────

class FigmaSpacing {
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

// ─── Radius ─────────────────────────────────────────────────────────────────

class FigmaRadius {
  static const double sm   = 8;
  static const double md   = 10; // boutons, badges
  static const double lg   = 14; // cards
  static const double xl   = 20; // modals, bottom sheets
  static const double full = 100; // cercles, pills
}

// ─── Typography scale ───────────────────────────────────────────────────────
// Font : Plus Jakarta Sans
// Line-height : 150%
// Letter-spacing : -2% à -3%

class FigmaType {
  // Mobile-adapted type scale
  static const double caption  = 11;
  static const double body2    = 12;
  static const double body1    = 14;
  static const double subtitle = 16;
  static const double title    = 18;
  static const double h3       = 20;
  static const double h2       = 24;
  static const double h1       = 32;

  static const double lineHeight = 1.5;
  static const double letterSpacing = -0.3;
  static const double letterSpacingTight = -0.5;
}
