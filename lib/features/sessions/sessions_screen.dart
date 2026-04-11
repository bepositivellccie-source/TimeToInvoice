import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/session.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/supabase_provider.dart';

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
  String? _highlightedId;
  bool _highlightScheduled = false;

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
    await ref
        .read(supabaseClientProvider)
        .from('sessions')
        .delete()
        .eq('id', sessionId);
    ref.invalidate(sessionsByProjectProvider(widget.projectId));
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
          if (sessions.isEmpty) return const _EmptySessions();

          // Lance le scroll + minuterie de surbrillance une seule fois
          _scheduleHighlightClear();

          return Column(
            children: [
              _SessionSummary(sessions: sessions),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: sessions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final session = sessions[i];
                    return _SessionTile(
                      session: session,
                      index: i + 1, // #1 = la plus récente
                      isHighlighted: _highlightedId == session.id,
                      onDelete: () => _deleteSession(session.id),
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

class _SessionSummary extends StatelessWidget {
  final List<WorkSession> sessions;
  const _SessionSummary({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final totalSecs =
        sessions.fold<int>(0, (sum, s) => sum + s.workedSeconds);
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;
    final timeStr = h > 0
        ? '${h}h ${m.toString().padLeft(2, '0')}min'
        : m > 0
            ? '${m}min ${s.toString().padLeft(2, '0')}s'
            : '${s}s';

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
              const Text('Total tracké',
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

// ─── Session tile — Dismissible + highlight ───────────────────────────────────

class _SessionTile extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final startStr = _fmtTime(session.startedAt);
    final endStr =
        session.endedAt != null ? _fmtTime(session.endedAt!) : '—';
    final dateStr = _fmtDate(session.startedAt);
    final durationStr = _fmtHHMMSS(session.workedSeconds);

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.startToEnd,
      // Fond rouge + icône visible pendant le swipe
      background: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Supprimer',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      // Dialog de confirmation AVANT la suppression
      confirmDismiss: (_) => showDialog<bool>(
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
                  backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete(),
      // Card avec AnimatedContainer pour la surbrillance
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: isHighlighted ? const Color(0xFFFEF9C3) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFFF59E0B)
                : const Color(0xFFE5E7EB),
            width: isHighlighted ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // ── Badge #N ─────────────────────────────────────────────
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '#$index',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isHighlighted
                          ? const Color(0xFFD97706)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Horaires + date ───────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$startStr → $endStr',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    if (session.notes != null &&
                        session.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        session.notes!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
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
              // ── Badge durée HH:MM:SS ──────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  durationStr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
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
