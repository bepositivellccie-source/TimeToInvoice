import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/project.dart';
import '../../core/providers/client_display_mode_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/sessions_provider.dart';
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
  Timer? _tabSwitchTimer;
  int? _hoveredTabIndex;
  bool _isDragging = false;

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
    _tabSwitchTimer?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onDragStarted() => setState(() => _isDragging = true);

  void _onDragEnd() {
    _tabSwitchTimer?.cancel();
    setState(() {
      _isDragging = false;
      _hoveredTabIndex = null;
    });
  }

  void _scheduleTabSwitch(int index) {
    if (_hoveredTabIndex == index) return;
    _tabSwitchTimer?.cancel();
    setState(() => _hoveredTabIndex = index);
    if (_tabCtrl.index != index) {
      _tabSwitchTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _tabCtrl.animateTo(index);
          HapticFeedback.selectionClick();
        }
      });
    }
  }

  void _cancelTabSwitch() {
    _tabSwitchTimer?.cancel();
    if (mounted) setState(() => _hoveredTabIndex = null);
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
          preferredSize: const Size.fromHeight(48),
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
              final isHovered = _hoveredTabIndex == i && _isDragging;

              return Expanded(
                child: DragTarget<Project>(
                  onWillAcceptWithDetails: (details) {
                    _scheduleTabSwitch(i);
                    return details.data.status != status;
                  },
                  onAcceptWithDetails: (details) {
                    HapticFeedback.mediumImpact();
                    final colLen = entriesAsync.valueOrNull
                            ?.where((e) => e.project.status == status)
                            .length ??
                        0;
                    ref.read(projectsProvider.notifier).updateStatus(
                          id: details.data.id,
                          clientId: details.data.clientId,
                          newStatus: status,
                          sortOrder: colLen,
                        );
                  },
                  onLeave: (_) => _cancelTabSwitch(),
                  builder: (context, candidates, rejected) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _tabCtrl.animateTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isHovered
                              ? color.withAlpha(25)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: isSelected
                                  ? primary
                                  : isHovered
                                      ? color
                                      : const Color(0xFFE5E7EB),
                              width: isSelected || isHovered ? 2.5 : 1,
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    : const Color(0xFF374151),
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
                    );
                  },
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
                    const Text(
                      'Appuyez sur + pour créer votre premier projet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
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
                onDragStarted: _onDragStarted,
                onDragEnd: _onDragEnd,
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
                      ? 'Glissez un projet ici pour le mettre en pause.'
                      : 'Créez un projet pour commencer.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
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
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  const _ProjectColumn({
    required this.status,
    required this.projects,
    required this.clientNames,
    required this.color,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Zone globale DragTarget pour drops dans l'espace vide sous les cartes
    return DragTarget<Project>(
      onWillAcceptWithDetails: (details) => details.data.status != status,
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        ref.read(projectsProvider.notifier).updateStatus(
              id: details.data.id,
              clientId: details.data.clientId,
              newStatus: status,
              sortOrder: projects.length,
            );
      },
      builder: (context, candidates, rejected) {
        final isHoveringColumn = candidates.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          color: isHoveringColumn ? color.withAlpha(8) : Colors.transparent,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: projects.length + 1, // +1 pour la zone d'insertion finale
            itemBuilder: (context, i) {
              // ── Zone d'insertion en fin de liste ──
              if (i == projects.length) {
                return _TailDropZone(
                  status: status,
                  color: color,
                  insertIndex: projects.length,
                );
              }
              return _DraggableProjectCard(
                project: projects[i],
                clientName: clientNames[projects[i].id] ?? '',
                canDelete: status == 'termine',
                columnStatus: status,
                columnColor: color,
                columnProjects: projects,
                indexInColumn: i,
                onDragStarted: onDragStarted,
                onDragEnd: onDragEnd,
              );
            },
          ),
        );
      },
    );
  }
}

// ─── Zone d'insertion en fin de colonne ─────────────────────────────────────

class _TailDropZone extends ConsumerWidget {
  final String status;
  final Color color;
  final int insertIndex;

  const _TailDropZone({
    required this.status,
    required this.color,
    required this.insertIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<Project>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        HapticFeedback.mediumImpact();
        final droppedProject = details.data;

        if (droppedProject.status == status) {
          // Même colonne : on le met à la fin
          // On a besoin de la liste complète pour recalculer l'ordre
          final entries = ref.read(timerProjectsProvider).valueOrNull ?? [];
          final columnProjects = entries
              .where((e) => e.project.status == status)
              .map((e) => e.project)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

          final reordered = List<Project>.from(columnProjects);
          final oldIndex =
              reordered.indexWhere((p) => p.id == droppedProject.id);
          if (oldIndex == -1) return;
          reordered.removeAt(oldIndex);
          reordered.add(droppedProject);
          for (int i = 0; i < reordered.length; i++) {
            reordered[i] = reordered[i].copyWith(sortOrder: i);
          }
          ref.read(projectsProvider.notifier).reorderColumn(
                clientId: droppedProject.clientId,
                columnProjects: reordered,
              );
        } else {
          // Colonne différente : changement de statut, en fin de liste
          ref.read(projectsProvider.notifier).updateStatus(
                id: droppedProject.id,
                clientId: droppedProject.clientId,
                newStatus: status,
                sortOrder: insertIndex,
              );
        }
      },
      builder: (context, candidates, rejected) {
        final isHovering = candidates.isNotEmpty;

        return Column(
          children: [
            // ── Trait d'insertion visible au survol ──
            if (isHovering)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withAlpha(80),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: -2.5,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: -2.5,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Zone invisible de réception (hauteur suffisante pour être ciblée)
            SizedBox(height: isHovering ? 60 : 80),
          ],
        );
      },
    );
  }
}

// ─── Project Card — draggable + insert indicator + swipe delete ─────────────

class _DraggableProjectCard extends ConsumerStatefulWidget {
  final Project project;
  final String clientName;
  final bool canDelete;
  final String columnStatus;
  final Color columnColor;
  final List<Project> columnProjects;
  final int indexInColumn;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;

  const _DraggableProjectCard({
    required this.project,
    required this.clientName,
    required this.canDelete,
    required this.columnStatus,
    required this.columnColor,
    required this.columnProjects,
    required this.indexInColumn,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  @override
  ConsumerState<_DraggableProjectCard> createState() =>
      _DraggableProjectCardState();
}

class _DraggableProjectCardState
    extends ConsumerState<_DraggableProjectCard> {
  double _swipeOffset = 0;
  bool _dialogShown = false;
  bool _insertAbove = true;

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

  void _handleDrop(Project droppedProject) {
    HapticFeedback.mediumImpact();
    final insertIndex =
        _insertAbove ? widget.indexInColumn : widget.indexInColumn + 1;

    if (droppedProject.status == widget.columnStatus) {
      // ── Même colonne : réordonnancement ──
      final reordered = List<Project>.from(widget.columnProjects);
      final oldIndex =
          reordered.indexWhere((p) => p.id == droppedProject.id);
      if (oldIndex == -1) return;
      reordered.removeAt(oldIndex);
      final adjusted =
          (insertIndex > oldIndex ? insertIndex - 1 : insertIndex)
              .clamp(0, reordered.length);
      reordered.insert(adjusted, droppedProject);
      for (int i = 0; i < reordered.length; i++) {
        reordered[i] = reordered[i].copyWith(sortOrder: i);
      }
      ref.read(projectsProvider.notifier).reorderColumn(
            clientId: droppedProject.clientId,
            columnProjects: reordered,
          );
    } else {
      // ── Colonne différente : changement de statut ──
      ref.read(projectsProvider.notifier).updateStatus(
            id: droppedProject.id,
            clientId: droppedProject.clientId,
            newStatus: widget.columnStatus,
            sortOrder: insertIndex,
          );
    }
  }

  Widget _buildCardContent(Color primary, int totalSecs, Color statusColor) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(
            '/clients/${widget.project.clientId}'
            '/projects/${widget.project.id}/sessions'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // ── Poignée drag ⠿ ────────────────────────────────
              const Icon(Icons.drag_indicator,
                  size: 20, color: Color(0xFFD1D5DB)),
              const SizedBox(width: 12),
              // ── Pastille statut ────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // ── Infos projet ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.project.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.clientName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Badge temps ───────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _fmtHHMMSS(totalSecs),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF9CA3AF), size: 20),
            ],
          ),
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
    final statusColor =
        _kanbanColors[widget.project.status] ?? const Color(0xFF6B7280);

    final cardContent = _buildCardContent(primary, totalSecs, statusColor);

    // ── Swipe delete (colonne Terminé uniquement) ────────────────
    Widget swipeableCard;
    if (widget.canDelete) {
      final deleteOpacity = (_swipeOffset.abs() / 80).clamp(0.0, 1.0);
      swipeableCard = ClipRRect(
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
      swipeableCard = cardContent;
    }

    // ── DragTarget autour de la carte (détecte insertion haut/bas) ───
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DragTarget<Project>(
        onWillAcceptWithDetails: (details) =>
            details.data.id != widget.project.id,
        onMove: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) {
            final localY = box.globalToLocal(details.offset).dy;
            final above = localY < box.size.height / 2;
            if (above != _insertAbove) setState(() => _insertAbove = above);
          }
        },
        onAcceptWithDetails: (details) => _handleDrop(details.data),
        builder: (context, candidates, rejected) {
          final isHovering = candidates.isNotEmpty;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // ── La carte (draggable) ──
              LongPressDraggable<Project>(
                data: widget.project,
                delay: const Duration(milliseconds: 300),
                hapticFeedbackOnStart: true,
                onDragStarted: widget.onDragStarted,
                onDragEnd: (_) => widget.onDragEnd(),
                onDraggableCanceled: (velocity, offset) =>
                    widget.onDragEnd(),
                feedback: Material(
                  color: Colors.transparent,
                  elevation: 12,
                  borderRadius: BorderRadius.circular(16),
                  child: Opacity(
                    opacity: 0.85,
                    child: SizedBox(
                      width: screenWidth - 64,
                      child: Transform.scale(
                        scale: 0.95,
                        child: cardContent,
                      ),
                    ),
                  ),
                ),
                childWhenDragging:
                    Opacity(opacity: 0.15, child: swipeableCard),
                child: swipeableCard,
              ),

              // ── Trait d'insertion ──────────────────────────────
              if (isHovering)
                Positioned(
                  left: 4,
                  right: 4,
                  top: _insertAbove ? -5 : null,
                  bottom: _insertAbove ? null : -5,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: widget.columnColor,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: widget.columnColor.withAlpha(80),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Points aux extrémités du trait ────────────────
              if (isHovering) ...[
                Positioned(
                  left: 0,
                  top: _insertAbove ? -7 : null,
                  bottom: _insertAbove ? null : -7,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.columnColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: _insertAbove ? -7 : null,
                  bottom: _insertAbove ? null : -7,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.columnColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
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
              color: const Color(0xFFE5E7EB),
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
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)))
                      : null,
                  trailing: const Icon(Icons.chevron_right,
                      color: Color(0xFF9CA3AF)),
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
