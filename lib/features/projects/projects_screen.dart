import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/project.dart';
import '../../core/providers/client_display_mode_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/theme/app_colors.dart';
import '../clients/client_detail_screen.dart';

// ─── Kanban config ───────────────────────────────────────────────────────────

const _kanbanStatuses = ['en_cours', 'en_attente', 'termine'];

const _kanbanLabels = {
  'en_cours': 'En cours',
  'en_attente': 'En attente',
  'termine': 'Terminé',
};

const _kanbanColors = {
  'en_cours': Color(0xFF659711),   // FigmaSuccess.c700
  'en_attente': Color(0xFFFFC73A), // FigmaWarning.c500
  'termine': Color(0xFF8E92BC),    // FigmaSecondary.c300
};

// ─── Screen ──────────────────────────────────────────────────────────────────

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _openNewProject() async {
    final clients = ref.read(clientsProvider).valueOrNull ?? [];
    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Créez d\'abord un client dans l\'onglet Clients'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (clients.length == 1) {
      _openForm(clients.first.id);
      return;
    }
    final clientId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClientPickerSheet(clients: clients),
    );
    if (clientId != null && mounted) _openForm(clientId);
  }

  void _openForm(String clientId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProjectFormSheet(clientId: clientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(timerProjectsProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau projet',
            onPressed: _openNewProject,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Row(
            children: List.generate(3, (i) {
              final status = _kanbanStatuses[i];
              final color = _kanbanColors[status]!;
              final label = _kanbanLabels[status]!;
              final count = entriesAsync.valueOrNull
                      ?.where((e) => e.project.status == status)
                      .length ??
                  0;
              final isSelected = _tabCtrl.index == i;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _tabCtrl.animateTo(i),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? color
                              : AppColors.border(context),
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 14,
                            color: isSelected
                                ? primary
                                : AppColors.textBody(context),
                          ),
                        ),
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text('Erreur: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(timerProjectsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('Aucun projet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      'Appuyez sur + pour créer votre premier projet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary(context)),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _openNewProject,
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau projet'),
                    ),
                  ],
                ),
              ),
            );
          }

          final clientNames = {
            for (final e in entries) e.project.id: e.clientName,
          };

          return TabBarView(
            controller: _tabCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: _kanbanStatuses.map((status) {
              final statusProjects = entries
                  .where((e) => e.project.status == status)
                  .map((e) => e.project)
                  .toList()
                ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

              final color = _kanbanColors[status]!;

              if (statusProjects.isEmpty) {
                return _EmptyColumn(
                  status: status,
                  color: color,
                  onAdd: _openNewProject,
                );
              }

              return _ProjectColumn(
                status: status,
                projects: statusProjects,
                clientNames: clientNames,
                color: color,
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

// ─── Colonne vide ────────────────────────────────────────────────────────────

class _EmptyColumn extends StatelessWidget {
  final String status;
  final Color color;
  final VoidCallback onAdd;

  const _EmptyColumn({
    required this.status,
    required this.color,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isEnCours = status == 'en_cours';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == 'termine'
                  ? Icons.check_circle_outline
                  : status == 'en_attente'
                      ? Icons.pause_circle_outline
                      : Icons.folder_open,
              size: 56,
              color: color.withAlpha(120),
            ),
            const SizedBox(height: 16),
            Text(
              status == 'termine'
                  ? 'Aucun projet terminé'
                  : status == 'en_attente'
                      ? 'Aucun projet en attente'
                      : 'Aucun projet en cours',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              status == 'termine'
                  ? 'Les projets terminés apparaîtront ici.'
                  : status == 'en_attente'
                      ? 'Les projets en attente apparaîtront ici.'
                      : 'Créez un projet pour commencer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
            ),
            if (isEnCours) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Nouveau projet'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Colonne avec projets ────────────────────────────────────────────────────

class _ProjectColumn extends ConsumerWidget {
  final String status;
  final List<Project> projects;
  final Map<String, String> clientNames;
  final Color color;

  const _ProjectColumn({
    required this.status,
    required this.projects,
    required this.clientNames,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            child: child,
          ),
          child: child,
        );
      },
      itemCount: projects.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final reordered = List<Project>.from(projects);
        final moved = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, moved);
        for (int i = 0; i < reordered.length; i++) {
          reordered[i] = reordered[i].copyWith(sortOrder: i);
        }
        HapticFeedback.mediumImpact();
        ref.read(projectsProvider.notifier).reorderColumn(
              clientId: moved.clientId,
              columnProjects: reordered,
            );
      },
      itemBuilder: (context, i) {
        return _ProjectCard(
          key: ValueKey(projects[i].id),
          index: i,
          project: projects[i],
          clientName: clientNames[projects[i].id] ?? '',
          canDelete: status == 'termine',
          statusColor: color,
        );
      },
    );
  }
}

// ─── Project Card — long press → status menu, swipe delete ───────────────────

class _ProjectCard extends ConsumerStatefulWidget {
  final int index;
  final Project project;
  final String clientName;
  final bool canDelete;
  final Color statusColor;

  const _ProjectCard({
    super.key,
    required this.index,
    required this.project,
    required this.clientName,
    required this.canDelete,
    required this.statusColor,
  });

  @override
  ConsumerState<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends ConsumerState<_ProjectCard> {
  double _swipeOffset = 0;
  bool _dialogShown = false;

  static String _fmtHHMMSS(int secs) {
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _confirmDelete() async {
    if (_dialogShown) return;
    _dialogShown = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce projet ?'),
        content: Text(
            '${widget.project.name} et toutes ses sessions seront supprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _dialogShown = false;
    if (confirmed == true) {
      await ref.read(projectsProvider.notifier).delete(
          id: widget.project.id, clientId: widget.project.clientId);
    } else {
      setState(() => _swipeOffset = 0);
    }
  }

  void _showStatusSheet() {
    HapticFeedback.mediumImpact();
    final entries = ref.read(timerProjectsProvider).valueOrNull ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            0, 12, 0, MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.project.name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final status in _kanbanStatuses)
              ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _kanbanColors[status],
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  _kanbanLabels[status]!,
                  style: TextStyle(
                    fontWeight: widget.project.status == status
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                trailing: widget.project.status == status
                    ? const Icon(Icons.check,
                        color: Color(0xFF16A34A), size: 20)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  if (widget.project.status != status) {
                    HapticFeedback.selectionClick();
                    final colLen = entries
                        .where((e) => e.project.status == status)
                        .length;
                    ref.read(projectsProvider.notifier).updateStatus(
                          id: widget.project.id,
                          clientId: widget.project.clientId,
                          newStatus: status,
                          sortOrder: colLen,
                        );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totals = ref.watch(projectsTotalSecondsProvider).valueOrNull ?? {};
    final totalSecs = totals[widget.project.id] ?? 0;
    final primary = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final cardContent = Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.border(context), width: 1),
      ),
      child: Row(
        children: [
          // ── Poignée drag ⠿ ────────────────────────────────
          ReorderableDragStartListener(
            index: widget.index,
            child: Container(
              width: 40,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Icon(Icons.drag_indicator,
                  size: 20, color: AppColors.borderStrong(context)),
            ),
          ),
          // ── Zone tappable (contenu) ───────────────────────
          Expanded(
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(16)),
              onTap: () => context.push(
                  '/clients/${widget.project.clientId}'
                  '/projects/${widget.project.id}/sessions'),
              onLongPress: _showStatusSheet,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ligne 1 : nom projet + capsule durée ──
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.project.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primary.withAlpha(15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _fmtHHMMSS(totalSecs),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                              color: primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ── Ligne 2 : nom client gris ─────────────
                    const SizedBox(height: 3),
                    Text(
                      widget.clientName,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // ── Swipe delete (colonne Terminé uniquement) ────────────────
    Widget child;
    if (widget.canDelete) {
      final deleteOpacity = (_swipeOffset.abs() / 80).clamp(0.0, 1.0);
      child = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (_swipeOffset < 0)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: Opacity(
                    opacity: deleteOpacity,
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white, size: 26),
                  ),
                ),
              ),
            AnimatedContainer(
              duration: Duration(milliseconds: _swipeOffset == 0 ? 200 : 0),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_swipeOffset, 0, 0),
              child: GestureDetector(
                onHorizontalDragUpdate: (d) {
                  setState(() {
                    _swipeOffset = (_swipeOffset + d.delta.dx)
                        .clamp(-screenWidth, 0.0);
                  });
                },
                onHorizontalDragEnd: (d) {
                  final velocity = d.primaryVelocity ?? 0;
                  if (_swipeOffset < -screenWidth * 0.30 || velocity < -800) {
                    _confirmDelete();
                  } else {
                    setState(() => _swipeOffset = 0);
                  }
                },
                child: cardContent,
              ),
            ),
          ],
        ),
      );
    } else {
      child = cardContent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}

// ─── Sélecteur de client (multi-client) ──────────────────────────────────────

class _ClientPickerSheet extends ConsumerWidget {
  final List clients;

  const _ClientPickerSheet({required this.clients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(clientDisplayModeProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 16, 0, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.border(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choisir un client',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (context, i) {
                final c = clients[i];
                final label = c.labelWith(mode);
                final subtitle = c.subtitleWith(mode);
                final initials = label
                    .trim()
                    .split(' ')
                    .take(2)
                    .map((w) =>
                        (w as String).isEmpty ? '' : w[0].toUpperCase())
                    .join();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: subtitle.isNotEmpty
                      ? Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary(context)))
                      : null,
                  trailing: Icon(Icons.chevron_right,
                      color: AppColors.textTertiary(context)),
                  onTap: () => Navigator.pop(context, c.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
