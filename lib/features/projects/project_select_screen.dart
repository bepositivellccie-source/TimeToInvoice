import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/providers/clients_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/theme/cf_palette.dart';
import '../clients/client_detail_screen.dart';

/// Choisir un projet — push depuis Chrono. Retourne `String?` (project id)
/// via `context.pop(id)`. Sections "En cours" + "Terminés", recherche
/// instantanée, CTA sticky pour créer un nouveau projet.
class ProjectSelectScreen extends ConsumerStatefulWidget {
  const ProjectSelectScreen({super.key});

  @override
  ConsumerState<ProjectSelectScreen> createState() =>
      _ProjectSelectScreenState();
}

class _ProjectSelectScreenState extends ConsumerState<ProjectSelectScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(timerProjectsProvider);
    final totalsAsync = ref.watch(projectsTotalSecondsProvider);

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(title: 'Choisir un projet'),
            _SearchBar(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
            Expanded(
              child: entriesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(message: e.toString()),
                data: (entries) =>
                    _ProjectList(
                  entries: entries,
                  totals: totalsAsync.valueOrNull ?? const {},
                  query: _query,
                ),
              ),
            ),
            _StickyCreateCta(onTap: () => _createProject(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _createProject(BuildContext context) async {
    final clients = ref.read(clientsProvider).valueOrNull ?? [];
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Créez d\'abord un client.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ProjectFormSheet(clientId: clients.first.id, existing: null),
    );
    if (mounted) ref.invalidate(timerProjectsProvider);
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.arrowLeft,
                size: 22, color: CF.text(context)),
            onPressed: () => context.pop(),
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

// ─── Search bar ─────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: CF.surfaceAlt(context),
          borderRadius: BorderRadius.circular(CFRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 18, color: CF.faint(context)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un projet…',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: CF.faint(context),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 11),
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: CF.text(context),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: Icon(LucideIcons.x,
                      size: 16, color: CF.faint(context)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Project list (sections en cours / terminés) ───────────────────────────

class _ProjectList extends StatelessWidget {
  final List<TimerEntry> entries;
  final Map<String, int> totals;
  final String query;

  const _ProjectList({
    required this.entries,
    required this.totals,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = entries.where((e) {
      if (query.isEmpty) return true;
      return e.project.name.toLowerCase().contains(query) ||
          e.clientName.toLowerCase().contains(query);
    }).toList();

    final active = filtered
        .where((e) => e.project.status != 'termine')
        .toList();
    final done = filtered
        .where((e) => e.project.status == 'termine')
        .toList();

    if (entries.isEmpty) {
      return _EmptyState(
        icon: LucideIcons.folderOpen,
        title: 'Aucun projet',
        subtitle:
            'Créez votre premier projet via le bouton ci-dessous.',
      );
    }

    if (filtered.isEmpty) {
      return _EmptyState(
        icon: LucideIcons.search,
        title: 'Aucun résultat',
        subtitle: 'Essayez un autre nom de projet ou de client.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (active.isNotEmpty)
          _SectionHeader(label: 'En cours', count: active.length),
        if (active.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (var i = 0; i < active.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ProjectRow(
                    entry: active[i],
                    totalSeconds: totals[active[i].project.id] ?? 0,
                  ),
                ],
              ],
            ),
          ),
        if (done.isNotEmpty)
          _SectionHeader(label: 'Terminés', count: done.length),
        if (done.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                for (var i = 0; i < done.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ProjectRow(
                    entry: done[i],
                    totalSeconds: totals[done[i].project.id] ?? 0,
                    dim: true,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Section header ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;

  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 10),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: CFType.caption,
              fontWeight: FontWeight.w600,
              color: CF.faint(context),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: CF.surfaceAlt(context),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: CF.faint(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Project row ────────────────────────────────────────────────────────────

class _ProjectRow extends StatelessWidget {
  final TimerEntry entry;
  final int totalSeconds;
  final bool dim;

  const _ProjectRow({
    required this.entry,
    required this.totalSeconds,
    this.dim = false,
  });

  static String _fmtHHMMSS(int secs) {
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  ({Color bg, Color fg}) _avatarPalette(BuildContext context) {
    final palettes = [
      (bg: const Color(0xFFE8F0FE), fg: CF.chrono),
      (bg: const Color(0xFFFEF3E8), fg: const Color(0xFFC2630A)),
      (bg: const Color(0xFFE7F6F0), fg: CF.accentB),
      (bg: const Color(0xFFF3E8FE), fg: const Color(0xFF6B4F9E)),
      (bg: const Color(0xFFFEE7E7), fg: CF.bordeaux),
    ];
    if (entry.project.status == 'termine') {
      return (bg: CF.surfaceAlt(context), fg: CF.muted(context));
    }
    final idx = entry.project.name.hashCode.abs() % palettes.length;
    return palettes[idx];
  }

  String _initials(String label) {
    final clean = label.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  String _projectAvatarLabel() {
    final raw = entry.clientName.split('·').first.trim();
    return _initials(raw.isEmpty ? entry.project.name : raw);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _avatarPalette(context);
    final isFolder = entry.project.status == 'termine';
    final hourly = entry.project.hourlyRate;
    final rateLabel = hourly % 1 == 0
        ? hourly.toInt().toString()
        : hourly.toStringAsFixed(0);
    final clientLabel =
        '${entry.clientName} · $rateLabel €/h';

    return Opacity(
      opacity: dim ? 0.75 : 1.0,
      child: Material(
        color: CF.surface(context),
        borderRadius: BorderRadius.circular(CFRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(CFRadius.md),
          onTap: () => context.pop(entry.project.id),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: CF.border(context), width: 0.5),
              borderRadius: BorderRadius.circular(CFRadius.md),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: isFolder
                      ? Icon(LucideIcons.folder,
                          size: 18, color: palette.fg)
                      : Text(
                          _projectAvatarLabel(),
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: palette.fg,
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
                        entry.project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CF.text(context),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clientLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: CF.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _fmtHHMMSS(totalSeconds),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CF.muted(context),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.chevronRight,
                    size: 16, color: CF.faint(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sticky CTA bottom ──────────────────────────────────────────────────────

class _StickyCreateCta extends StatelessWidget {
  final VoidCallback onTap;
  const _StickyCreateCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: CF.bg(context),
        border: Border(
          top: BorderSide(color: CF.border(context), width: 0.5),
        ),
      ),
      child: SizedBox(
        height: 50,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(LucideIcons.plus, size: 18, color: CF.primary),
          label: Text(
            'Créer un nouveau projet',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: CF.primary,
              letterSpacing: -0.1,
            ),
          ),
          style: OutlinedButton.styleFrom(
            backgroundColor: CF.surface(context),
            side: BorderSide(color: CF.border(context), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Empty / Error states ──────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: CF.surfaceAlt(context),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 24, color: CF.muted(context)),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CF.text(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: CF.muted(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Erreur : $message',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: CF.bordeaux,
          ),
        ),
      ),
    );
  }
}

