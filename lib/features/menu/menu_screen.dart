import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/cf_palette.dart';

/// Placeholder pour le 4e onglet Menu — sera enrichi au chantier 4.
/// Pour l'instant on expose juste les liens vers les écrans déplacés
/// hors du shell (Clients, Projets, PDFs, Paramètres, Profil).
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName =
        user?.userMetadata?['full_name'] as String? ?? user?.email ?? '';
    final initials = _initials(fullName);

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // ── Title ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
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
            _AccountCard(
              fullName: fullName.isEmpty ? 'Mon compte' : fullName,
              initials: initials,
              email: user?.email ?? '',
              onTap: () => context.push('/profile'),
            ),

            const _SectionLabel('Mes données'),
            _MenuCard(children: [
              _MenuRow(
                icon: LucideIcons.users,
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
                label: 'Mes PDFs',
                onTap: () => context.push('/pdfs'),
              ),
            ]),

            const _SectionLabel('Compte'),
            _MenuCard(children: [
              _MenuRow(
                icon: LucideIcons.settings,
                label: 'Paramètres',
                onTap: () => context.push('/settings'),
              ),
            ]),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(8, 22, 8, 10),
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
    return Container(
      decoration: BoxDecoration(
        color: CF.surface(context),
        borderRadius: BorderRadius.circular(CFRadius.xl),
        border: Border.all(color: CF.border(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
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
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
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
            Icon(LucideIcons.chevronRight,
                size: 18, color: CF.faint(context)),
          ],
        ),
      ),
    );
  }
}
