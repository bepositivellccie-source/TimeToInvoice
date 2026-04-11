import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/models/session.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/projects_provider.dart';

class SessionsScreen extends ConsumerWidget {
  final String projectId;

  const SessionsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(sessionsByProjectProvider(projectId));
    // Retrouve le projet pour afficher son nom
    final project = ref.watch(projectsProvider).valueOrNull
        ?.where((p) => p.id == projectId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.name ?? 'Sessions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/clients/${project?.clientId}'),
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (sessions) => sessions.isEmpty
            ? const _EmptySessions()
            : Column(
                children: [
                  // Résumé total
                  _SessionSummary(sessions: sessions),
                  // Liste
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: sessions.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _SessionTile(session: sessions[i]),
                    ),
                  ),
                ],
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
    final totalMin =
        sessions.fold<int>(0, (sum, s) => sum + (s.durationMinutes ?? 0));
    final h = totalMin ~/ 60;
    final m = totalMin % 60;

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
                '${h}h ${m.toString().padLeft(2, '0')}min',
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

// ─── Session tile ─────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final WorkSession session;

  const _SessionTile({required this.session});

  String _formatDate(DateTime dt) =>
      DateFormat('dd/MM/yyyy', 'fr_FR').format(dt.toLocal());

  String _formatDuration(int? minutes) {
    if (minutes == null) return '—';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}min';
    return '${h}h ${m.toString().padLeft(2, '0')}min';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icône date
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.calendar_today_outlined,
                  size: 20,
                  color:
                      Theme.of(context).colorScheme.onSecondaryContainer),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(session.startedAt),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  if (session.notes != null && session.notes!.isNotEmpty)
                    Text(session.notes!,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF6B7280)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Durée
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(session.durationMinutes),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
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
