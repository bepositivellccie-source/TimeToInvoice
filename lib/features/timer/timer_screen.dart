import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/project.dart';
import '../../core/providers/projects_provider.dart';
import 'timer_notifier.dart';

class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final projectsAsync = ref.watch(projectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('TimeToInvoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
              // Section : sélection projet
              Text(
                'Projet',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFF6B7280),
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              projectsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Erreur: $e'),
                data: (projects) => _ProjectSelector(
                  projects: projects,
                  selectedId: timerState.selectedProjectId,
                  enabled: !timerState.isRunning,
                ),
              ),
              const SizedBox(height: 40),

              // Chrono
              Center(
                child: _ChronoDisplay(elapsed: timerState.elapsed),
              ),
              const SizedBox(height: 40),

              // Bouton Start / Stop
              _TimerButton(
                isRunning: timerState.isRunning,
                hasProject: timerState.selectedProjectId != null,
              ),
              const SizedBox(height: 16),

              // Bouton Créer facture (visible uniquement si timer arrêté et session existait)
              if (!timerState.isRunning &&
                  timerState.selectedProjectId != null) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: naviguer vers création facture
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Création de facture — Semaine 2 !'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Créer une facture'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Project selector ─────────────────────────────────────────────────────────

class _ProjectSelector extends ConsumerWidget {
  final List<Project> projects;
  final String? selectedId;
  final bool enabled;

  const _ProjectSelector({
    required this.projects,
    required this.selectedId,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (projects.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.folder_open, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Aucun projet — créez-en un d\'abord'),
              ),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: selectedId,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.folder_outlined),
        hintText: 'Sélectionner un projet',
      ),
      items: projects
          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
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
        await notifier.stop();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session enregistrée ✓')),
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
        ? const Color(0xFFDC2626) // rouge quand actif
        : Theme.of(context).colorScheme.primary;

    return FilledButton.icon(
      onPressed: (canStart && !_loading) ? () => _toggle(context) : null,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Icon(widget.isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 28),
      label: Text(
        widget.isRunning ? 'Arrêter' : 'Démarrer',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}
