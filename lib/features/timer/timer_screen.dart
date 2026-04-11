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
          // Accès au profil vendeur
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mon profil',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                'Projet',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              // Sélecteur Client · Projet
              entriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur: $e'),
                data: (entries) => _ProjectSelector(
                  entries: entries,
                  selectedId: timerState.selectedProjectId,
                  enabled: !timerState.isRunning,
                ),
              ),
              const SizedBox(height: 40),

              // Chrono
              Center(child: _ChronoDisplay(elapsed: timerState.elapsed)),
              const SizedBox(height: 40),

              // Start / Stop
              _TimerButton(
                isRunning: timerState.isRunning,
                hasProject: timerState.selectedProjectId != null,
              ),
              const SizedBox(height: 16),

              // Bouton Créer facture → InvoiceScreen
              if (!timerState.isRunning &&
                  timerState.selectedProjectId != null)
                FilledButton.icon(
                  onPressed: () => context.push(
                    '/invoices/new/${timerState.selectedProjectId}',
                  ),
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Créer une facture'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor:
                        Theme.of(context).colorScheme.secondary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Formatage durée lisible ──────────────────────────────────────────────────

String _fmtDuration(int totalSeconds) {
  if (totalSeconds < 60) return '${totalSeconds}s';
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return m > 0 ? '${h}h ${m}min' : '${h}h';
  }
  return s > 0 ? '${m}min ${s}s' : '${m}min';
}

// ─── Project selector ─────────────────────────────────────────────────────────

class _ProjectSelector extends ConsumerWidget {
  final List<TimerEntry> entries;
  final String? selectedId;
  final bool enabled;

  const _ProjectSelector({
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

    final validId = entries.any((e) => e.project.id == selectedId)
        ? selectedId
        : null;

    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: validId,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.folder_outlined),
        hintText: 'Sélectionner un projet',
      ),
      isExpanded: true,
      items: entries
          .map((e) => DropdownMenuItem(
                value: e.project.id,
                child: Text(
                  '${e.clientName} · ${e.project.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: enabled
          ? (id) {
              if (id != null) {
                ref.read(timerProvider.notifier).selectProject(id);
              }
            }
          : null,
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

// ─── Timer button ─────────────────────────────────────────────────────────────

class _TimerButton extends ConsumerStatefulWidget {
  final bool isRunning;
  final bool hasProject;

  const _TimerButton({required this.isRunning, required this.hasProject});

  @override
  ConsumerState<_TimerButton> createState() => _TimerButtonState();
}

class _TimerButtonState extends ConsumerState<_TimerButton> {
  bool _loading = false;

  Future<void> _toggle(BuildContext context) async {
    setState(() => _loading = true);
    try {
      final notifier = ref.read(timerProvider.notifier);

      if (widget.isRunning) {
        // Capture projectId avant le stop (le state change ensuite)
        final projectId = ref.read(timerProvider).selectedProjectId;
        final session = await notifier.stop();

        // FIX 2 — Invalide le cache sessions pour ce projet
        if (projectId != null) {
          ref.invalidate(sessionsByProjectProvider(projectId));
        }

        // FIX 4 — Snackbar verte enrichie
        if (context.mounted && session != null) {
          final project = ref.read(projectsProvider).valueOrNull
              ?.where((p) => p.id == projectId)
              .firstOrNull;
          final totalSecs = session.endedAt != null
              ? session.endedAt!
                  .difference(session.startedAt)
                  .inSeconds
              : (session.durationMinutes ?? 0) * 60;
          final durationStr = _fmtDuration(totalSecs);
          final amount =
              (totalSecs / 3600.0) * (project?.hourlyRate ?? 0);
          final currency = project?.currency ?? 'EUR';
          final amountStr =
              '${amount.toStringAsFixed(0)} $currency';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Session enregistrée · $durationStr · ~$amountStr'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        await notifier.start();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canStart = widget.hasProject || widget.isRunning;
    final color = widget.isRunning
        ? const Color(0xFFDC2626)
        : Theme.of(context).colorScheme.primary;

    return FilledButton.icon(
      onPressed: (canStart && !_loading) ? () => _toggle(context) : null,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 64),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(
              widget.isRunning
                  ? Icons.stop_rounded
                  : Icons.play_arrow_rounded,
              size: 28),
      label: Text(
        widget.isRunning ? 'Arrêter' : 'Démarrer',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}
