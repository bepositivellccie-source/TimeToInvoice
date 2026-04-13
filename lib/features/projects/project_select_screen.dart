import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';

class ProjectSelectScreen extends ConsumerStatefulWidget {
  const ProjectSelectScreen({super.key});

  @override
  ConsumerState<ProjectSelectScreen> createState() =>
      _ProjectSelectScreenState();
}

class _ProjectSelectScreenState extends ConsumerState<ProjectSelectScreen> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all'; // 'all' | 'active' | 'completed'
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(timerProjectsProvider);
    final totalsAsync = ref.watch(projectsTotalSecondsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un chantier'),
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Barre de recherche (sans autofocus) ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Rechercher un chantier ou un client…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),

          // ── Chips statut ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _StatusChip(
                  label: 'Tous',
                  selected: _statusFilter == 'all',
                  onTap: () => setState(() => _statusFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'En cours',
                  selected: _statusFilter == 'active',
                  activeColor: const Color(0xFF16A34A),
                  onTap: () => setState(() => _statusFilter = 'active'),
                ),
                const SizedBox(width: 8),
                _StatusChip(
                  label: 'Terminé',
                  selected: _statusFilter == 'completed',
                  activeColor: const Color(0xFF6B7280),
                  onTap: () => setState(() => _statusFilter = 'completed'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Liste ────────────────────────────────────────────────────────
          Expanded(
            child: entriesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Erreur : $e',
                  style: const TextStyle(color: Color(0xFFDC2626)),
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucun projet — créez un client puis un projet dans l\'onglet Clients',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  );
                }

                final filtered = entries.where((e) {
                  if (_statusFilter == 'active' && !e.project.isActive) {
                    return false;
                  }
                  if (_statusFilter == 'completed' && e.project.isActive) {
                    return false;
                  }
                  if (_query.isNotEmpty) {
                    return e.project.name
                            .toLowerCase()
                            .contains(_query) ||
                        e.clientName.toLowerCase().contains(_query);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucun résultat',
                      style: TextStyle(color: Color(0xFF9CA3AF)),
                    ),
                  );
                }

                // totals peut être null pendant le chargement — on affiche 0
                final totals = totalsAsync.valueOrNull ?? {};

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final entry = filtered[i];
                    return _ProjectCard(
                      entry: entry,
                      totalSeconds: totals[entry.project.id] ?? 0,
                      onTap: () => context.pop(entry.project.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chip filtre statut ───────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? activeColor;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        activeColor ?? Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(25) : Colors.transparent,
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Card projet ──────────────────────────────────────────────────────────────

class _ProjectCard extends StatelessWidget {
  final TimerEntry entry;
  final int totalSeconds;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.entry,
    required this.totalSeconds,
    required this.onTap,
  });

  static String _fmtHHMMSS(int secs) {
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final project = entry.project;
    final isActive = project.isActive;
    final statusColor = project.status == 'en_attente'
        ? const Color(0xFFF59E0B)
        : isActive
            ? const Color(0xFF16A34A)
            : const Color(0xFF9CA3AF);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // ── Icône dossier ─────────────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  size: 22,
                  color: isActive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 14),

              // ── Nom + client ──────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.clientName,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ── Temps travaillé + statut ──────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withAlpha(15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _fmtHHMMSS(totalSeconds),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        project.status == 'en_attente'
                            ? 'En attente'
                            : isActive
                                ? 'En cours'
                                : 'Terminé',
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
