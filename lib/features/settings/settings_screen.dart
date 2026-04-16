import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/theme_mode_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Paramètres',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Groupe 1 : Mon compte ─────────────────────────────
          const _GroupHeader(label: 'Mon compte'),
          _SettingsTile(
            title: 'Profil vendeur',
            subtitle: 'Identité, adresse, SIRET, IBAN',
            onTap: () => context.push('/profile'),
          ),
          _SettingsTile(
            title: 'Abonnement',
            subtitle: 'Gérer votre forfait',
            onTap: () => _showComingSoon(context),
          ),

          const SizedBox(height: 24),

          // ── Groupe 2 : Préférences ────────────────────────────
          const _GroupHeader(label: 'Préférences'),
          _SettingsTile(
            title: 'Mode sombre',
            subtitle: themeMode == ThemeMode.system
                ? 'Automatique (système)'
                : isDark
                    ? 'Activé'
                    : 'Désactivé',
            trailing: Switch.adaptive(
              value: themeMode == ThemeMode.system
                  ? isDark
                  : themeMode == ThemeMode.dark,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).setMode(
                      v ? ThemeMode.dark : ThemeMode.light,
                    );
              },
            ),
          ),
          _SettingsTile(
            title: 'Conformité e-invoicing',
            subtitle: 'Factur-X · Calendrier DGFiP 2026-2027',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _ComplianceScreen(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Groupe 3 : Légal ──────────────────────────────────
          const _GroupHeader(label: 'Légal'),
          _SettingsTile(
            title: 'Conditions générales',
            subtitle: "CGU et politique de confidentialité",
            onTap: () => _showComingSoon(context),
          ),
          _SettingsTile(
            title: 'Déconnexion',
            subtitle: 'Se déconnecter de votre compte',
            titleColor: const Color(0xFFDC2626),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Se déconnecter ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Déconnexion'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await Supabase.instance.client.auth.signOut();
              }
            },
          ),

          const SizedBox(height: 32),

          // ── Version ─────────────────────────────────────────
          Center(
            child: Text(
              'ChronoFacture v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
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

// ─── Group header ──────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final String label;

  const _GroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF6B7280),
        ),
      ),
    );
  }
}

// ─── Settings tile ──────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6B7280);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ??
                          (isDark
                              ? const Color(0xFFF1F5F9)
                              : const Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && onTap != null)
              Icon(LucideIcons.chevronRight, size: 18, color: mutedColor),
          ],
        ),
      ),
    );
  }
}

// ─── Compliance info screen ───────────────────────────────────────────────

class _ComplianceScreen extends StatelessWidget {
  const _ComplianceScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF111827);
    final bodyColor =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF374151);
    final mutedColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Conformité e-invoicing',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Calendrier DGFiP',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 12),
          _ComplianceRow(
            label: 'Réception obligatoire',
            value: 'septembre 2026',
            titleColor: titleColor,
            bodyColor: bodyColor,
          ),
          const SizedBox(height: 16),
          _ComplianceRow(
            label: 'Émission obligatoire',
            value: 'septembre 2027',
            titleColor: titleColor,
            bodyColor: bodyColor,
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Vos factures ChronoFacture sont au format Factur-X — conformes à la réforme DGFiP.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: bodyColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplianceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color titleColor;
  final Color bodyColor;

  const _ComplianceRow({
    required this.label,
    required this.value,
    required this.titleColor,
    required this.bodyColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: bodyColor,
          ),
        ),
      ],
    );
  }
}
