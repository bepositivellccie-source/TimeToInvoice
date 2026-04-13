import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/session.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String? highlightSessionId;

  const SessionsScreen({
    super.key,
    required this.projectId,
    this.highlightSessionId,
  });

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  final _scrollController = ScrollController();
  // IDs supprimés de façon optimiste — filtre les tiles avant que le provider
  // ne revienne avec les nouvelles données, évite le bug "dismissed Dismissible
  // still in tree" causé par un rebuild intermédiaire.
  final _pendingDeletes = <String>{};
  String? _highlightedId;
  bool _highlightScheduled = false;
  String _timeFilter = 'all'; // 'all' | 'today' | 'week' | 'month'

  @override
  void initState() {
    super.initState();
    _highlightedId = widget.highlightSessionId;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Appelé une seule fois quand les données sont disponibles — scroll en haut
  /// puis efface la surbrillance après 2 secondes.
  void _scheduleHighlightClear() {
    if (_highlightScheduled || _highlightedId == null) return;
    _highlightScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _highlightedId = null);
      });
    });
  }

  Future<void> _deleteSession(String sessionId) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('sessions')
          .delete()
          .eq('id', sessionId);
      // DELETE réussi — invalide le cache puis affiche le succès
      if (!mounted) return;
      ref.invalidate(sessionsByProjectProvider(widget.projectId));
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Session supprimée'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
    } catch (_) {
      // Échec réseau — annule la suppression optimiste et resync
      if (mounted) {
        setState(() => _pendingDeletes.remove(sessionId));
        ref.invalidate(sessionsByProjectProvider(widget.projectId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync =
        ref.watch(sessionsByProjectProvider(widget.projectId));
    final project = ref
        .watch(projectsProvider)
        .valueOrNull
        ?.where((p) => p.id == widget.projectId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.name ?? 'Sessions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/clients/${project?.clientId}');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Créer une facture',
            onPressed: () =>
                context.push('/invoices/new/${widget.projectId}'),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (sessions) {
          // Filtre optimiste — exclut les sessions en cours de suppression
          final all = sessions
              .where((s) => !_pendingDeletes.contains(s.id))
              .toList();

          if (all.isEmpty) return const _EmptySessions();

          // Filtre temporel
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekStart = today.subtract(Duration(days: today.weekday - 1));
          final monthStart = DateTime(now.year, now.month);

          final displayed = _timeFilter == 'all'
              ? all
              : all.where((s) {
                  final d = s.startedAt.toLocal();
                  switch (_timeFilter) {
                    case 'today':
                      return !d.isBefore(today);
                    case 'week':
                      return !d.isBefore(weekStart);
                    case 'month':
                      return !d.isBefore(monthStart);
                    default:
                      return true;
                  }
                }).toList();

          // Lance le scroll + minuterie de surbrillance une seule fois
          _scheduleHighlightClear();

          return Column(
            children: [
              _SessionSummary(sessions: displayed),
              // ── Chips filtre temporel ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tout',
                      selected: _timeFilter == 'all',
                      onTap: () => setState(() => _timeFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: "Aujourd'hui",
                      selected: _timeFilter == 'today',
                      onTap: () => setState(() => _timeFilter = 'today'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Semaine',
                      selected: _timeFilter == 'week',
                      onTap: () => setState(() => _timeFilter = 'week'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Mois',
                      selected: _timeFilter == 'month',
                      onTap: () => setState(() => _timeFilter = 'month'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: displayed.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Aucune session sur cette période',
                            style: TextStyle(
                                color: const Color(0xFF9CA3AF),
                                fontSize: 14),
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: displayed.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final session = displayed[i];
                          return _SessionTile(
                            session: session,
                            index: i + 1,
                            isHighlighted: _highlightedId == session.id,
                            onDelete: () {
                              setState(() => _pendingDeletes.add(session.id));
                              _deleteSession(session.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Summary ──────────────────────────────────────────────────────────────────

// ─── Filter chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Summary ──────────────────────────────────────────────────────────────────

class _SessionSummary extends StatelessWidget {
  final List<WorkSession> sessions;
  const _SessionSummary({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final totalSecs =
        sessions.fold<int>(0, (sum, s) => sum + s.workedSeconds);
    final hh = (totalSecs ~/ 3600).toString().padLeft(2, '0');
    final mm = ((totalSecs % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (totalSecs % 60).toString().padLeft(2, '0');
    final timeStr = '$hh:$mm:$ss';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withAlpha(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Temps travaillé',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              Text(
                timeStr,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Sessions',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              Text(
                '${sessions.length}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Session tile — Swipe gauche → fond rouge + icône poubelle → dialog ─────

class _SessionTile extends StatefulWidget {
  final WorkSession session;
  final int index;
  final bool isHighlighted;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.index,
    required this.isHighlighted,
    required this.onDelete,
  });

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  /// Offset horizontal continu (négatif = swipe gauche).
  double _dragOffset = 0;
  bool _dialogShown = false;

  static String _fmtTime(DateTime dt) =>
      DateFormat('HH:mm').format(dt.toLocal());

  static String _fmtDate(DateTime dt) =>
      DateFormat('d MMM', 'fr_FR').format(dt.toLocal());

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
        title: const Text('Supprimer cette session ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _dialogShown = false;
    if (confirmed == true) {
      widget.onDelete();
    } else {
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final startStr = _fmtTime(session.startedAt);
    final endStr =
        session.endedAt != null ? _fmtTime(session.endedAt!) : '—';
    final dateStr = _fmtDate(session.startedAt);
    final durationStr = _fmtHHMMSS(session.workedSeconds);
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Opacité progressive de l'icône poubelle (apparaît après 30px de swipe)
    final deleteOpacity = (_dragOffset.abs() / 80).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          // ── Fond rouge continu ──────────────────────────────────────
          if (_dragOffset < 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(14),
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
          // ── Card glissante — geste continu fluide ───────────────────
          AnimatedContainer(
            duration: Duration(milliseconds: _dragOffset == 0 ? 200 : 0),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragOffset = (_dragOffset + details.delta.dx)
                      .clamp(-screenWidth, 0.0);
                });
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                // Seuil : 30% de l'écran ou vélocité rapide → confirmation
                if (_dragOffset < -screenWidth * 0.30 || velocity < -800) {
                  _confirmDelete();
                } else {
                  setState(() => _dragOffset = 0);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: widget.isHighlighted
                      ? const Color(0xFFFEF9C3)
                      : AppColors.primarySurf,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.isHighlighted
                        ? const Color(0xFFF59E0B)
                        : AppColors.primary.withAlpha(50),
                    width: widget.isHighlighted ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // ── Horaires + date ───────────────────────────
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$startStr → $endStr  ·  $dateStr',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: AppColors.textDark,
                              ),
                            ),
                            if (session.notes != null &&
                                session.notes!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                session.notes!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // ── Durée ─────────────────────────────────────
                      Text(
                        durationStr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          color: AppColors.textMuted, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty ────────────────────────────────────────────────────────────────────

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text('Aucune session',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'Démarrez le timer depuis l\'onglet Timer pour créer des sessions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
