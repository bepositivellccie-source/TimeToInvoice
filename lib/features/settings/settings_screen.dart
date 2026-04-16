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
          // ── Profil vendeur ───────────────────────────────────
          _SettingsTile(
            icon: LucideIcons.userCircle2,
            title: 'Profil vendeur',
            subtitle: 'Identité, adresse, SIRET, IBAN',
            onTap: () => context.push('/profile'),
          ),

          const SizedBox(height: 4),

          // ── Abonnement ──────────────────────────────────────
          _SettingsTile(
            icon: LucideIcons.crown,
            title: 'Abonnement',
            subtitle: 'Gérer votre forfait',
            onTap: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Bientôt disponible'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
            },
          ),

          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 4),

          // ── Mode sombre / clair ─────────────────────────────
          _SettingsTile(
            icon: isDark ? LucideIcons.moon : LucideIcons.sun,
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

          const SizedBox(height: 4),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 4),

          // ── CGU ─────────────────────────────────────────────
          _SettingsTile(
            icon: LucideIcons.fileText,
            title: 'Conditions générales',
            subtitle: "CGU et politique de confidentialité",
            onTap: () {
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Bientôt disponible'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
            },
          ),

          const SizedBox(height: 4),

          // ── Déconnexion ─────────────────────────────────────
          _SettingsTile(
            icon: LucideIcons.logOut,
            title: 'Déconnexion',
            subtitle: 'Se déconnecter de votre compte',
            iconColor: const Color(0xFFDC2626),
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

          const SizedBox(height: 24),

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
}

// ─── Settings tile ──────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF6B7280);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor ?? defaultIconColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
            if (trailing == null && onTap != null)
              Icon(LucideIcons.chevronRight,
                  size: 18, color: defaultIconColor),
          ],
        ),
      ),
    );
  }
}
