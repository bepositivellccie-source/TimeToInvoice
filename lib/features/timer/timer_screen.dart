import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/theme/app_colors.dart';
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

    final primary = Theme.of(context).colorScheme.primary;
    final hasSelection = selected != null;

    return Material(
      color: hasSelection
          ? primary.withAlpha(18)
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasSelection
                  ? primary.withAlpha(60)
                  : const Color(0xFFE5E7EB),
              width: hasSelection ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // ── Icône projet ──────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: hasSelection
                      ? primary.withAlpha(30)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: hasSelection ? primary : const Color(0xFF9CA3AF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              // ── Label ─────────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: hasSelection
                      ? Column(
                          key: ValueKey(selected.project.id),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected.project.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selected.clientName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Text(
                          'Choisir un chantier',
                          key: const ValueKey('no-project'),
                          style: TextStyle(
                              color: primary.withAlpha(120),
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: hasSelection
                        ? primary.withAlpha(20)
                        : primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chevron_right,
                      size: 18,
                      color: hasSelection
                          ? primary
                          : primary.withAlpha(150)),
                ),
              ],
            ],
          ),
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

  void _stop(BuildContext context) {
    // Capture les refs synchrones avant le stop
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final projectId = ref.read(timerProvider).selectedProjectId;

    // Stop synchrone — état local réinitialisé immédiatement
    final result = ref.read(timerProvider.notifier).stop();
    if (result == null) return;

    // Invalidation cache sessions + totaux
    if (projectId != null) {
      ref.invalidate(sessionsByProjectProvider(projectId));
    }
    ref.invalidate(projectsTotalSecondsProvider);

    final secs = result.totalSecs;
    final project = ref.read(projectsProvider).valueOrNull
        ?.where((p) => p.id == projectId)
        .firstOrNull;
    final clientId = project?.clientId;

    // Durée HH:MM:SS
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    final durationStr = '$h:$m:$s';

    // Ligne 1 — "Ven. 11 avr. · 18:17 → 18:17"
    final startStr =
        DateFormat('HH:mm').format(result.startedAt.toLocal());
    final endStr =
        DateFormat('HH:mm').format(result.endedAt.toLocal());
    final dateStr =
        DateFormat('d MMM', 'fr_FR').format(result.startedAt.toLocal());
    final dayRaw =
        DateFormat('EEE', 'fr_FR').format(result.startedAt.toLocal());
    // "ven." → "Ven" — capitalize + retire le point final
    final dayTrimmed = dayRaw.endsWith('.') ? dayRaw.substring(0, dayRaw.length - 1) : dayRaw;
    final dayStr = dayTrimmed.isNotEmpty
        ? '${dayTrimmed[0].toUpperCase()}${dayTrimmed.substring(1)}'
        : dayTrimmed;
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

    final sessionId = result.sessionId;

    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
        SnackBar(
          duration: const Duration(days: 365),
          dismissDirection: DismissDirection.horizontal,
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
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
                          // Ligne 2 — "00:00:16  ·  0,14 €"
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
                                  color: Colors.white.withAlpha(200),
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
    // Après dismiss (swipe ou tap chevron), confirmer l'ajout
    controller.closed.then((reason) {
      if (reason == SnackBarClosedReason.swipe ||
          reason == SnackBarClosedReason.dismiss) {
        messenger.showSnackBar(
          SnackBar(
            content: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                messenger.hideCurrentSnackBar();
                if (clientId != null && projectId != null) {
                  router.push(
                    '/clients/$clientId/projects/$projectId/sessions',
                  );
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward,
                      size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'Session ajoutée au projet ✓',
                    style: TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ── Idle — un seul bouton ElevatedButton plein ──────────────────────
    if (!widget.isRunning && !widget.isPaused) {
      return ElevatedButton.icon(
        onPressed: (widget.hasProject && !_loading) ? _start : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(80),
          disabledForegroundColor: Colors.white60,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        icon: _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.play_arrow, size: 26),
        label: const Text('Démarrer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
    }

    // ── Running — Pause (primary) + Terminer (outlined danger) ─────────
    if (widget.isRunning) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _pause,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.pause, size: 22),
              label: const Text('Pause',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _stop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.stop, size: 22),
              label: const Text('Terminer',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );
    }

    // ── Paused — Reprendre (primary) + Terminer (outlined danger) ──────
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _resume,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.play_arrow, size: 22),
            label: const Text('Reprendre',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _stop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.stop, size: 22),
            label: const Text('Terminer',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}
