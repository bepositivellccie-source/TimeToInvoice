import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/profile.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/theme_mode_provider.dart';
import '../../core/theme/cf_palette.dart';

/// Paramètres — push depuis Menu. Sections : Mon profil / Mon activité /
/// Préférences / Données. Header custom avec back arrow + titre centré.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _appVersion = 'Version 1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final user = Supabase.instance.client.auth.currentUser;
    final profileName = profile?.headerName ?? '';
    final fullName = profileName.isNotEmpty
        ? profileName
        : (user?.userMetadata?['full_name'] as String? ?? user?.email ?? '');
    final initials = _initials(fullName);
    final subtitle = _profileSubtitle(profile);

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
                  // ── MON PROFIL ────────────────────────────────────────
                  const _SectionLabel('Mon profil'),
                  _Card(
                    child: InkWell(
                      onTap: () => context.push('/profile'),
                      borderRadius: BorderRadius.circular(CFRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [CF.chrono, CF.primary],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fullName.isEmpty ? 'Mon compte' : fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: CFType.subtitle,
                                      fontWeight: FontWeight.w600,
                                      color: CF.text(context),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        color: CF.muted(context),
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(LucideIcons.chevronRight,
                                size: 16, color: CF.faint(context)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── MON ACTIVITÉ ─────────────────────────────────────
                  const _SectionLabel('Mon activité'),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.mapPin,
                      label: 'Mes coordonnées',
                      onTap: () => context.push('/profile'),
                    ),
                  ),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.landmark,
                      label: 'Mes coordonnées bancaires',
                      onTap: () => context.push('/profile'),
                    ),
                  ),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.hash,
                      label: 'Numérotation des factures',
                      sub: 'F-{YYYY}-{NNN} · auto-incrémenté',
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.euro,
                      label: 'Tarif horaire par défaut',
                      value: _hourlyRateHint(profile),
                      onTap: () => _showComingSoon(context),
                    ),
                  ),

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
                  _Card(
                    child: _Row(
                      icon: LucideIcons.bell,
                      label: 'Notifications',
                      showChevron: false,
                      trailing: const _Toggle(value: true, onChanged: _noop),
                    ),
                  ),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.clock,
                      label: 'Délai de paiement par défaut',
                      value: '30 jours',
                      onTap: () => _showComingSoon(context),
                    ),
                  ),
                  _Card(
                    child: _Row(
                      icon: LucideIcons.globe,
                      label: 'Langue',
                      value: 'Français',
                      onTap: () => _showComingSoon(context),
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
                        const SizedBox(height: 4),
                        Text(
                          'Mentions légales · Politique de confidentialité',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: CF.faint(context),
                          ),
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

  static String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  static String _profileSubtitle(Profile? profile) {
    if (profile == null) return '';
    final siret = profile.siret?.trim();
    if (siret == null || siret.isEmpty) return '';
    final masked = _formatSiret(siret);
    return 'Micro-entrepreneur · SIRET $masked';
  }

  static String _formatSiret(String s) {
    final digits = s.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 9) return s;
    final head = digits.substring(0, 9);
    return '${head.substring(0, 3)} ${head.substring(3, 6)} ${head.substring(6, 9)}';
  }

  static String _hourlyRateHint(Profile? profile) {
    final rate = profile?.defaultHourlyRate;
    if (rate == null || rate <= 0) return '—';
    final fmt = rate % 1 == 0 ? rate.toInt().toString() : rate.toStringAsFixed(0);
    return '$fmt €/h';
  }

  static void _noop(bool _) {}
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
  final String? sub;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool danger;

  const _Row({
    required this.icon,
    required this.label,
    this.sub,
    this.value,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: CF.muted(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Text(
              value!,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: CF.muted(context),
                letterSpacing: -0.1,
              ),
            ),
          ],
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

// ─── Toggle ─────────────────────────────────────────────────────────────────

class _Toggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 26,
        decoration: BoxDecoration(
          color: value ? CF.accentB : CF.border(context),
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
