import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  final _pendingDeletes = <String>{};
  String? _highlightedId;
  bool _highlightScheduled = false;
  String _timeFilter = 'all';

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
      if (mounted) {
        setState(() => _pendingDeletes.remove(sessionId));
        ref.invalidate(sessionsByProjectProvider(widget.projectId));
      }
    }
  }

  /// Regroupe les sessions par clé "mois-année".
  /// Trié du plus récent au plus ancien.
  Map<String, List<WorkSession>> _groupByMonth(List<WorkSession> sessions) {
    final map = <String, List<WorkSession>>{};
    for (final s in sessions) {
      final local = s.startedAt.toLocal();
      final key = '${local.year}-${local.month.toString().padLeft(2, '0')}';
      (map[key] ??= []).add(s);
    }
    // Tri des clés descendant (plus récent d'abord)
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
    return sorted;
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final dt = DateTime(year, month);
    // "Avril 2026" — capitalize first letter
    final raw = DateFormat('MMMM yyyy', 'fr_FR').format(dt);
    return raw[0].toUpperCase() + raw.substring(1);
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

    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
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
                icon: const Icon(LucideIcons.fileText),
                tooltip: 'Créer une facture',
                onPressed: () =>
                    context.push('/invoices/new/${widget.projectId}'),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                project?.name ?? 'Sessions',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              titlePadding:
                  const EdgeInsets.only(left: 56, bottom: 16, right: 56),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withAlpha(30),
                      primary.withAlpha(12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (sessions) {
          final all = sessions
              .where((s) => !_pendingDeletes.contains(s.id))
              .toList();

          if (all.isEmpty) return const _EmptySessions();

          // Filtre temporel
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final weekStart =
              today.subtract(Duration(days: today.weekday - 1));
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

          _scheduleHighlightClear();

          final grouped = _groupByMonth(displayed);

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
              const SizedBox(height: 4),
              Expanded(
                child: displayed.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Aucune session sur cette période',
                            style: TextStyle(
                                color: AppColors.textTertiary(context),
                                fontSize: 14),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(0, 4, 0, 32),
                        itemCount: grouped.length,
                        itemBuilder: (context, gi) {
                          final key = grouped.keys.elementAt(gi);
                          final monthSessions = grouped[key]!;
                          final label = _monthLabel(key);
                          final totalSecs = monthSessions.fold<int>(
                              0, (sum, s) => sum + s.workedSeconds);

                          return _MonthSection(
                            label: label,
                            sessionCount: monthSessions.length,
                            totalSeconds: totalSecs,
                            initiallyExpanded: gi == 0,
                            children: [
                              for (int i = 0;
                                  i < monthSessions.length;
                                  i++) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: _SessionTile(
                                    session: monthSessions[i],
                                    isHighlighted:
                                        _highlightedId == monthSessions[i].id,
                                    hourlyRate: project?.hourlyRate ?? 0,
                                    currency: project?.currency ?? 'EUR',
                                    onDelete: () {
                                      setState(() => _pendingDeletes
                                          .add(monthSessions[i].id));
                                      _deleteSession(monthSessions[i].id);
                                    },
                                  ),
                                ),
                                if (i < monthSessions.length - 1)
                                  const SizedBox(height: 8),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}

// ─── Month section (pliable/dépliable) ─────────────────────────────────────

class _MonthSection extends StatelessWidget {
  final String label;
  final int sessionCount;
  final int totalSeconds;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _MonthSection({
    required this.label,
    required this.sessionCount,
    required this.totalSeconds,
    required this.initiallyExpanded,
    required this.children,
  });

  static String _fmtHM(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    return '${m}min';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        title: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary(context),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$sessionCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            Text(
              _fmtHM(totalSeconds),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary(context),
              ),
            ),
          ],
        ),
        children: children,
      ),
    );
  }
}

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
            color: selected ? color : AppColors.border(context),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : AppColors.textSecondary(context),
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
              Text('Temps travaillé',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context))),
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
              Text('Sessions',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context))),
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

// ─── Session tile ────────────────────────────────────────────────────────────

class _SessionTile extends StatefulWidget {
  final WorkSession session;
  final bool isHighlighted;
  final VoidCallback onDelete;
  final double hourlyRate;
  final String currency;

  const _SessionTile({
    required this.session,
    required this.isHighlighted,
    required this.onDelete,
    required this.hourlyRate,
    this.currency = 'EUR',
  });

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  double _dragOffset = 0;
  bool _dialogShown = false;

  static String _fmtTime(DateTime dt) =>
      DateFormat('HH:mm').format(dt.toLocal());

  /// "Lundi 14 avril" — ajoute l'année si différente de l'année en cours
  static String _fmtDayFull(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    // "lundi 14 avril"
    final raw = DateFormat('EEEE d MMMM', 'fr_FR').format(local);
    final capitalized = raw[0].toUpperCase() + raw.substring(1);
    if (local.year != now.year) {
      return '$capitalized ${local.year}';
    }
    return capitalized;
  }

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
    final dayStr = _fmtDayFull(session.startedAt);
    final durationStr = _fmtHHMMSS(session.workedSeconds);
    final amount = (session.workedSeconds / 3600.0) * widget.hourlyRate;
    final symbol = const {
          'EUR': '€',
          'USD': '\$',
          'GBP': '£',
          'CHF': 'CHF',
        }[widget.currency] ??
        widget.currency;
    final amountStr =
        '${amount.toStringAsFixed(2).replaceAll('.', ',')} $symbol';
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Swipe droite → gauche : offset négatif
    final deleteOpacity = (_dragOffset.abs() / 80).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          // ── Fond rouge (visible quand swipe vers la droite) ─────────
          if (_dragOffset > 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 24),
                child: Opacity(
                  opacity: deleteOpacity,
                  child: const Icon(LucideIcons.trash2,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          // ── Card glissante ─────────────────────────────────────────
          AnimatedContainer(
            duration: Duration(milliseconds: _dragOffset == 0 ? 200 : 0),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  // Uniquement vers la droite (positif)
                  _dragOffset = (_dragOffset + details.delta.dx)
                      .clamp(0.0, screenWidth);
                });
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (_dragOffset > screenWidth * 0.30 || velocity > 800) {
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
                      ? (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF422006)
                          : const Color(0xFFFEF9C3))
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withAlpha(20)
                          : AppColors.primarySurf),
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
                      // ── Contenu 2 lignes ────────────────────────
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Ligne 1 — date gras + capsule durée
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dayStr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(18),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    durationStr,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Ligne 2 — horaires + montant
                            Row(
                              children: [
                                Text(
                                  'de $startStr à $endStr',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppColors.textSecondary(context),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  amountStr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                            if (session.notes != null &&
                                session.notes!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  session.notes!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        AppColors.textTertiary(context),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(LucideIcons.chevronRight,
                          color: Color(0xFF9CA3AF), size: 16),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.clock,
                size: 64, color: AppColors.textTertiary(context)),
            const SizedBox(height: 16),
            const Text('Aucune session',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Démarrez le chrono depuis l\'onglet Chrono pour créer des sessions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}
