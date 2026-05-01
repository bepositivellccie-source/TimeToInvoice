import 'package:flutter/material.dart';

/// ChronoFacture v2 design tokens.
///
/// Source : `chronofacture-2/project/tokens.jsx` (Claude Design handoff
/// du 2026-04-23). Palette « horlogerie suisse de la facture » : blanc cassé,
/// bleu primaire #305DA8 (logo), vert validation #049A83.
///
/// Toujours utiliser ces tokens pour les nouveaux écrans plutôt que
/// `AppColors` (legacy) ou `FigmaPrimary` (design Figma précédent).
class CF {
  // ─── Brand ─────────────────────────────────────────────────────────────────
  /// CTA principal (boutons, navbar actif). Aligné sur le bleu du logo.
  static const Color primary = Color(0xFF305DA8);

  /// Validation / dégradé vert — start.
  static const Color accentA = Color(0xFF05B89C);

  /// Validation / dégradé vert — end. Bouton play, encaisser, badge Pro.
  static const Color accentB = Color(0xFF049A83);

  /// Bleu logo « horlogerie ».
  static const Color chrono = Color(0xFF305DA8);

  /// Stop session, destructif.
  static const Color bordeaux = Color(0xFF8B1F2F);

  /// Relance, alerte (échéance dépassée).
  static const Color orange = Color(0xFFF59E0B);

  // ─── Neutres clairs (style Tailwind) ───────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color g50 = Color(0xFFF9FAFB);
  static const Color g100 = Color(0xFFF3F4F6);
  static const Color g200 = Color(0xFFE5E7EB);
  static const Color g300 = Color(0xFFD1D5DB);
  static const Color g400 = Color(0xFF9CA3AF);
  static const Color g500 = Color(0xFF6B7280);
  static const Color g600 = Color(0xFF4B5563);
  static const Color g900 = Color(0xFF111827);

  // ─── Dark mode (surfaces étagées) ──────────────────────────────────────────
  static const Color d0 = Color(0xFF0B0D10); // app background
  static const Color d1 = Color(0xFF14171C); // card surface
  static const Color d2 = Color(0xFF1C2027); // active element
  static const Color d3 = Color(0xFF262B33); // border / divider
  static const Color dText = Color(0xFFF3F4F6);
  static const Color dMuted = Color(0xFF9CA3AF);
  static const Color dFaint = Color(0xFF6B7280);

  // ─── Test mode ─────────────────────────────────────────────────────────────
  static const Color testBg = Color(0xFFD1FAE5);
  static const Color testFg = Color(0xFF047857);

  // ─── Statut bandeaux détail facture ────────────────────────────────────────
  static const Color pendingBg = Color(0xFFF3F4F6);
  static const Color pendingFg = Color(0xFF374151);
  static const Color overdueBg = Color(0xFFFEF3C7);
  static const Color overdueFg = Color(0xFFB45309);
  static const Color paidBg = Color(0xFFD1FAE5);
  static const Color paidFg = Color(0xFF047857);

  // ─── Helpers context-aware ─────────────────────────────────────────────────

  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color bg(BuildContext c) => _dark(c) ? d0 : g50;
  static Color surface(BuildContext c) => _dark(c) ? d1 : white;
  static Color surfaceAlt(BuildContext c) => _dark(c) ? d2 : g100;
  static Color text(BuildContext c) => _dark(c) ? dText : g900;
  static Color muted(BuildContext c) => _dark(c) ? dMuted : g500;
  static Color faint(BuildContext c) => _dark(c) ? dFaint : g400;
  static Color border(BuildContext c) => _dark(c) ? d3 : g200;
}

/// Tailles de typo cohérentes avec les mockups (Inter).
class CFType {
  static const double caption = 11;
  static const double small = 12;
  static const double body = 14;
  static const double subtitle = 15;
  static const double title = 16;
  static const double h3 = 20;
  static const double h2 = 24;
  static const double h1 = 28;
  static const double timerMega = 82;
  static const double kpiHero = 48;
}

/// Border radius selon les mockups.
class CFRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
}
