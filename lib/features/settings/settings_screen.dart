import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/providers/theme_mode_provider.dart';
import '../../core/theme/cf_palette.dart';

/// Paramètres — push depuis Menu. Sections : Préférences (Mode sombre) /
/// Données (Exporter / Supprimer compte). Header custom avec back arrow.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _appVersion = 'Version 1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(title: 'Paramètres'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 20),
                children: [
                  // ── PRÉFÉRENCES ───────────────────────────────────────
                  const _SectionLabel('Préférences'),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.moon,
                      label: 'Mode sombre',
                      showChevron: false,
                      trailing: _ThemeSegmented(
                        value: themeMode,
                        onChanged: (m) =>
                            ref.read(themeModeProvider.notifier).setMode(m),
                      ),
                    ),
                  ),

                  // ── DONNÉES ──────────────────────────────────────────
                  const _SectionLabel('Données'),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.download,
                      label: 'Exporter mes données',
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.trash2,
                      label: 'Supprimer mon compte',
                      danger: true,
                      onTap: () => _confirmDelete(context),
                    ),
                  ),

                  // ── Footer ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
                    child: Column(
                      children: [
                        Text(
                          'ChronoFacture · $_appVersion',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: CF.muted(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FooterLink(
                              label: 'Mentions légales',
                              onTap: () => _showComingSoon(context),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '·',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: CF.faint(context),
                                ),
                              ),
                            ),
                            _FooterLink(
                              label: 'Politique de confidentialité',
                              onTap: () => _showComingSoon(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte ?'),
        content: const Text(
            'Cette action est irréversible. Toutes vos données (clients, projets, factures) seront supprimées définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) _showComingSoon(context);
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Bientôt disponible'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 20, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.arrowLeft,
                size: 22, color: CF.text(context)),
            onPressed: () => Navigator.of(context).maybePop(),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CF.text(context),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ─── Section label ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: CFType.caption,
          fontWeight: FontWeight.w600,
          color: CF.faint(context),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─── Card (single row, individuelle) ────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CF.surface(context),
          borderRadius: BorderRadius.circular(CFRadius.md),
          border: Border.all(color: CF.border(context), width: 0.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(CFRadius.md),
          child: child,
        ),
      ),
    );
  }
}

// ─── Row ────────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool danger;

  const _Row({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final dangerColor = const Color(0xFFDC2626);
    final iconColor = danger ? dangerColor : CF.muted(context);
    final labelColor = danger ? dangerColor : CF.text(context);

    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: CF.surfaceAlt(context),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: CFType.subtitle,
                fontWeight: FontWeight.w500,
                color: labelColor,
                letterSpacing: -0.1,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (showChevron) ...[
            const SizedBox(width: 6),
            Icon(LucideIcons.chevronRight,
                size: 16,
                color: danger
                    ? dangerColor.withValues(alpha: 0.5)
                    : CF.faint(context)),
          ],
        ],
      ),
    );

    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

// ─── Theme segmented control ───────────────────────────────────────────────

class _ThemeSegmented extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSegmented({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = const [
      (ThemeMode.system, 'Auto'),
      (ThemeMode.light, 'Clair'),
      (ThemeMode.dark, 'Sombre'),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: CF.surfaceAlt(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final active = opt.$1 == value;
          return GestureDetector(
            onTap: () => onChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.symmetric(horizontal: 1),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: active ? CF.surface(context) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: active
                    ? const [
                        BoxShadow(
                          color: Color(0x0F000000),
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                opt.$2,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? CF.text(context) : CF.muted(context),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Footer link ───────────────────────────────────────────────────────────

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: CF.faint(context),
            decoration: TextDecoration.underline,
            decorationColor: CF.faint(context).withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}
