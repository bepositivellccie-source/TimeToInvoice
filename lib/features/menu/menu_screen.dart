import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/auth_constants.dart';
import '../../core/providers/subscription_provider.dart';
import '../../core/theme/cf_palette.dart';

/// Menu — 4e onglet. Hub des données, outils et compte utilisateur.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  static const _appVersion = 'v 1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName =
        user?.userMetadata?['full_name'] as String? ?? user?.email ?? '';
    final initials = _initials(fullName);
    final isPro = ref.watch(subscriptionProvider).isPro;

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            // ── Title ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Text(
                'Menu',
                style: GoogleFonts.inter(
                  fontSize: CFType.h1,
                  fontWeight: FontWeight.w700,
                  color: CF.text(context),
                  letterSpacing: -0.6,
                ),
              ),
            ),

            // ── Account card ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _AccountCard(
                fullName: fullName.isEmpty ? 'Mon compte' : fullName,
                initials: initials,
                email: user?.email ?? '',
                onTap: () => context.push('/profile'),
              ),
            ),

            // ── MES DONNÉES ──────────────────────────────────────
            const _SectionLabel('Mes données'),
            _MenuCard(children: [
              _MenuRow(
                icon: LucideIcons.user,
                label: 'Clients',
                onTap: () => context.push('/clients'),
              ),
              _Divider(),
              _MenuRow(
                icon: LucideIcons.folder,
                label: 'Projets',
                onTap: () => context.push('/projects'),
              ),
              _Divider(),
              _MenuRow(
                icon: LucideIcons.fileText,
                label: 'Mes factures',
                onTap: () => context.go('/invoices'),
              ),
            ]),

            // ── OUTILS ───────────────────────────────────────────
            const _SectionLabel('Outils'),
            _MenuCard(children: [
              _MenuRow(
                icon: LucideIcons.download,
                label: 'Export comptable',
                onTap: () => _showComingSoon(context),
              ),
            ]),

            // ── COMPTE ───────────────────────────────────────────
            const _SectionLabel('Compte'),
            _MenuCard(children: [
              _MenuRow(
                icon: LucideIcons.crown,
                label: 'Abonnement',
                trailing: isPro ? const _ProBadge() : null,
                onTap: () => _showComingSoon(context),
              ),
              _Divider(),
              _MenuRow(
                icon: LucideIcons.settings,
                label: 'Paramètres',
                onTap: () => context.push('/settings'),
              ),
              _Divider(),
              _MenuRow(
                icon: LucideIcons.helpCircle,
                label: 'Aide',
                onTap: () => _showComingSoon(context),
              ),
            ]),

            // ── Sign out ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
              child: Center(
                child: TextButton(
                  onPressed: () => _confirmSignOut(context),
                  style: TextButton.styleFrom(
                    foregroundColor: CF.bordeaux,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Se déconnecter',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                      color: CF.bordeaux,
                    ),
                  ),
                ),
              ),
            ),

            // ── Version footer ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Center(
                child: Text(
                  _appVersion,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CF.faint(context),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
            'Vous reviendrez à l\'écran de connexion. Vos données restent en sécurité.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CF.bordeaux),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Purger la session Google locale en plus de Supabase. Sans ça,
      // la SDK Google rouvre silencieusement le dernier compte au
      // prochain "Continuer avec Google" et l'utilisateur ne peut pas
      // changer de compte Gmail.
      try {
        final googleSignIn =
            GoogleSignIn(serverClientId: kGoogleWebClientId);
        await googleSignIn.signOut();
        await googleSignIn.disconnect();
      } catch (_) {
        // Pas de session Google active. On ignore.
      }
      await Supabase.instance.client.auth.signOut();
    }
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
}

// ─── Account card ───────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final String fullName;
  final String initials;
  final String email;
  final VoidCallback onTap;

  const _AccountCard({
    required this.fullName,
    required this.initials,
    required this.email,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CF.surface(context),
      borderRadius: BorderRadius.circular(CFRadius.xl),
      child: InkWell(
        borderRadius: BorderRadius.circular(CFRadius.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CFRadius.xl),
            border: Border.all(color: CF.border(context), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: CFType.title,
                        fontWeight: FontWeight.w700,
                        color: CF.text(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: CF.faint(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight,
                  size: 18, color: CF.faint(context)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sections ───────────────────────────────────────────────────────────────

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

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: CF.surface(context),
          borderRadius: BorderRadius.circular(CFRadius.xl),
          border: Border.all(color: CF.border(context), width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: CF.border(context),
      indent: 0,
      endIndent: 0,
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _MenuRow({
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            child: Icon(icon, size: 19, color: CF.muted(context)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: CFType.subtitle,
                fontWeight: FontWeight.w500,
                color: CF.text(context),
                letterSpacing: -0.1,
              ),
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 8),
          ],
          Icon(LucideIcons.chevronRight,
              size: 18, color: CF.faint(context)),
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

// ─── Pro badge ──────────────────────────────────────────────────────────────

class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CF.accentB.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Pro',
        style: GoogleFonts.inter(
          color: CF.accentB,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
