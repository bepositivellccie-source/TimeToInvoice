import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

    Future<void> onTap() async {
      final id = await context.push<String>('/projects/select');
      if (id != null) {
        final entry =
            entries.where((e) => e.project.id == id).firstOrNull;
        final notifName = entry != null
            ? '${entry.project.name} · ${entry.clientName}'
            : null;
        ref.read(timerProvider.notifier).selectProject(
              id,
              projectName: notifName,
            );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Card tappable (Ink pour ripple visible sur fond décoré) ──────
        Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled
                  ? Theme.of(context).colorScheme.outline.withAlpha(80)
                  : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(14),
            color: enabled ? Colors.white : const Color(0xFFF9FAFB),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_outlined,
                    color: selected != null
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF9CA3AF),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: selected != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nom du projet — hiérarchie principale
                              Text(
                                selected.project.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              // Nom du client — secondaire
                              Text(
                                selected.clientName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF6B7280),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )
                        : const Text(
                            'Sélectionner un projet',
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 15),
                          ),
                  ),
                  if (enabled) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right,
                        size: 24, color: Color(0xFF6B7280)),
                  ],
                ],
              ),
            ),
          ),
        ),

        // ── Hint — visible uniquement quand le sélecteur est actif ──────
        if (enabled)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Appuyer pour changer de chantier',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withAlpha(60),
              ),
            ),
          ),
      ],
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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

        // Durée HH:MM:SS
        final h = (secs ~/ 3600).toString().padLeft(2, '0');
        final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
        final s = (secs % 60).toString().padLeft(2, '0');
        final durationStr = '$h:$m:$s';

        // Ligne 1 — "Ven. 11 avr. · 18:17 → 18:17"
        final startStr =
            DateFormat('HH:mm').format(session.startedAt.toLocal());
        final endStr = session.endedAt != null
            ? DateFormat('HH:mm').format(session.endedAt!.toLocal())
            : '—';
        final dateStr =
            DateFormat('d MMM', 'fr_FR').format(session.startedAt.toLocal());
        final dayRaw =
            DateFormat('EEE', 'fr_FR').format(session.startedAt.toLocal());
        // Capitalize first letter: "ven." → "Ven."
        final dayStr = dayRaw.isNotEmpty
            ? '${dayRaw[0].toUpperCase()}${dayRaw.substring(1)}'
            : dayRaw;
        final line1 = '$dayStr $dateStr · $startStr → $endStr';

        // Montant
        final amount = (secs / 3600.0) * (project?.hourlyRate ?? 0);
        final currency = project?.currency ?? 'EUR';
        final symbol = const {
          'EUR': '€',
          'USD': '\$',
          'GBP': '£',
          'CHF': 'CHF',
        }[currency] ??
            currency;
        final amountStr = amount.toStringAsFixed(2).replaceAll('.', ',');

        final sessionId = session.id;

        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(days: 365),
              dismissDirection: DismissDirection.horizontal,
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF16A34A),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              content: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  if (clientId != null && projectId != null) {
                    router.push(
                      '/clients/$clientId/projects/$projectId/sessions',
                      extra: sessionId,
                    );
                  }
                },
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ligne 1 — "Ven. 11 avr. · 18:17 → 18:17"
                              Text(
                                line1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              // Ligne 2 — durée (gauche) · montant (droite)
                              Row(
                                children: [
                                  Text(
                                    durationStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white,
                                      height: 1.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$amountStr $symbol',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withAlpha(178),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Chevron — zone avec fond semi-opaque, coins droits arrondis
                      if (clientId != null)
                        Container(
                          width: 40,
                          decoration: const BoxDecoration(
                            color: Color(0x26FFFFFF), // blanc 15 %
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
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
