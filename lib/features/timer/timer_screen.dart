import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';
import 'timer_notifier.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final entriesAsync = ref.watch(timerProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TimeToInvoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mon profil',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async =>
                Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Sélecteur de projet (BottomSheet) ───────────────────────
              Text(
                'Projet',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              entriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur: $e'),
                data: (entries) => _ProjectSelectorButton(
                  entries: entries,
                  selectedId: timerState.selectedProjectId,
                  enabled: !timerState.isActive,
                ),
              ),
              const SizedBox(height: 40),

              // ── Chrono — affiche le temps total travaillé ────────────────
              Center(
                  child: _ChronoDisplay(elapsed: timerState.totalWorked)),
              const SizedBox(height: 8),
              if (timerState.isPaused)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '⏸ En pause',
                      style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 32),

              // ── Boutons timer ────────────────────────────────────────────
              _TimerControls(
                isRunning: timerState.isRunning,
                isPaused: timerState.isPaused,
                hasProject: timerState.selectedProjectId != null,
              ),
              // BUG 3 : bouton "Créer une facture" supprimé de cet écran
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sélecteur projet — tappable card → route /projects/select ───────────────

class _ProjectSelectorButton extends ConsumerWidget {
  final List<TimerEntry> entries;
  final String? selectedId;
  final bool enabled;

  const _ProjectSelectorButton({
    required this.entries,
    required this.selectedId,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                    "Aucun projet — créez un client puis un projet dans l'onglet Clients"),
              ),
            ],
          ),
        ),
      );
    }

    final selected =
        entries.where((e) => e.project.id == selectedId).firstOrNull;

    return InkWell(
      onTap: enabled
          ? () async {
              final id =
                  await context.push<String>('/projects/select');
              if (id != null) {
                ref.read(timerProvider.notifier).selectProject(id);
              }
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled
                ? Theme.of(context).colorScheme.outline.withAlpha(80)
                : const Color(0xFFE5E7EB),
          ),
          borderRadius: BorderRadius.circular(14),
          color: enabled ? null : const Color(0xFFF9FAFB),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_outlined,
              color: selected != null
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFF9CA3AF),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: selected != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected.project.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          selected.clientName,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      ],
                    )
                  : const Text(
                      'Sélectionner un projet',
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 15),
                    ),
            ),
            if (enabled)
              const Icon(Icons.chevron_right,
                  size: 20, color: Color(0xFF6B7280)),
          ],
        ),
      ),
    );
  }
}

// ─── Chrono display ───────────────────────────────────────────────────────────

class _ChronoDisplay extends StatelessWidget {
  final Duration elapsed;

  const _ChronoDisplay({required this.elapsed});

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _format(elapsed),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 64,
                letterSpacing: -2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'hh : mm : ss',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF9CA3AF),
                letterSpacing: 2,
              ),
        ),
      ],
    );
  }
}

// ─── Contrôles timer (idle / running / paused) ────────────────────────────────

class _TimerControls extends ConsumerStatefulWidget {
  final bool isRunning;
  final bool isPaused;
  final bool hasProject;

  const _TimerControls({
    required this.isRunning,
    required this.isPaused,
    required this.hasProject,
  });

  @override
  ConsumerState<_TimerControls> createState() => _TimerControlsState();
}

class _TimerControlsState extends ConsumerState<_TimerControls> {
  bool _loading = false;

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      await ref.read(timerProvider.notifier).start();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pause() => ref.read(timerProvider.notifier).pause();
  void _resume() => ref.read(timerProvider.notifier).resume();

  Future<void> _stop(BuildContext context) async {
    setState(() => _loading = true);

    // Capturer les refs avant l'opération async (FIX 6)
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    try {
      // Capture avant le stop
      final projectId = ref.read(timerProvider).selectedProjectId;
      final totalSecs = ref.read(timerProvider).totalWorked.inSeconds;

      final (session, workedSecs) =
          await ref.read(timerProvider.notifier).stop();

      // Invalidation cache sessions
      if (projectId != null) {
        ref.invalidate(sessionsByProjectProvider(projectId));
      }

      if (session != null) {
        final project = ref.read(projectsProvider).valueOrNull
            ?.where((p) => p.id == projectId)
            .firstOrNull;
        final clientId = project?.clientId;

        final secs = workedSecs > 0 ? workedSecs : totalSecs;
        final h = (secs ~/ 3600).toString().padLeft(2, '0');
        final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
        final s = (secs % 60).toString().padLeft(2, '0');
        final durationStr = '$h:$m:$s';

        final amount = (secs / 3600.0) * (project?.hourlyRate ?? 0);
        final currency = project?.currency ?? 'EUR';
        // Symbole lisible (€ au lieu de EUR)
        final symbol = const {
          'EUR': '€',
          'USD': '\$',
          'GBP': '£',
          'CHF': 'CHF',
        }[currency] ?? currency;
        final amountStr =
            amount.toStringAsFixed(2).replaceAll('.', ',');
        final projectName = project?.name ?? '';
        final sessionId = session.id;

        // FIX 5 — Snackbar 3 lignes avec hiérarchie visuelle
        // FIX 6 — Tappable → SessionsScreen + surbrillance
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(days: 365),
              dismissDirection: DismissDirection.horizontal,
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF16A34A),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              content: GestureDetector(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  if (clientId != null && projectId != null) {
                    router.push(
                      '/clients/$clientId/projects/$projectId/sessions',
                      extra: sessionId,
                    );
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ligne 1 — montant (grand, gras)
                          Text(
                            '$amountStr $symbol',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Ligne 2 — durée HH:MM:SS
                          Text(
                            durationStr,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          // Ligne 3 — nom projet (semi-transparent)
                          Text(
                            projectName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withAlpha(180),
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Chevron — indique que la snackbar est tappable
                    if (clientId != null)
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white.withAlpha(180),
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Idle ────────────────────────────────────────────────────────────
    if (!widget.isRunning && !widget.isPaused) {
      return FilledButton.icon(
        onPressed: (widget.hasProject && !_loading) ? _start : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        icon: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.play_arrow_rounded, size: 30),
        label: const Text('Démarrer',
            style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      );
    }

    // ── Running ou Paused — deux boutons ────────────────────────────────
    return Row(
      children: [
        // Pause / Reprendre
        Expanded(
          child: FilledButton.icon(
            onPressed: _loading
                ? null
                : (widget.isRunning ? _pause : _resume),
            style: FilledButton.styleFrom(
              backgroundColor: widget.isRunning
                  ? const Color(0xFFF59E0B) // orange = pause
                  : const Color(0xFF16A34A), // vert = reprendre
              minimumSize: const Size(0, 60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(
              widget.isRunning
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              size: 26,
            ),
            label: Text(
              widget.isRunning ? 'Pause' : 'Reprendre',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Terminer
        Expanded(
          child: FilledButton.icon(
            onPressed: (widget.hasProject && !_loading)
                ? () => _stop(context)
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              minimumSize: const Size(0, 60),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.stop_rounded, size: 26),
            label: const Text('Terminer',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
