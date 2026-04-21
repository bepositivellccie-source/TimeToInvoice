import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/session_bar_provider.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(
            children: [
              // ── Top bar : paramètres ──────────────────────────────────
              SizedBox(
                height: 32,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.settings,
                          color: AppColors.textSecondary(context), size: 22),
                      tooltip: 'Paramètres',
                      onPressed: () => context.push('/settings'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),

              // ── Logo centré ───────────────────────────────────────────
              Image.asset('assets/ChronoFacture_Officiel_bleu_512px_NoMarge.png', height: 60),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Chrono',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(
                      text: 'Facture',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CHAQUE SECONDE COMPTE',
                style: GoogleFonts.montserrat(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary(context),
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 20),

              // ── Sélecteur de projet ────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Projet',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary(context),
                        fontWeight: FontWeight.w600,
                      ),
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

              const Spacer(flex: 2),

              // ── Chrono ─────────────────────────────────────────────────
              _ChronoDisplay(
                elapsed: timerState.totalWorked,
                isRunning: timerState.isRunning,
              ),
              const SizedBox(height: 8),
              if (timerState.isPaused)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF78350F)
                        : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '⏸ En pause',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFFBBF24)
                            : const Color(0xFFD97706),
                        fontWeight: FontWeight.w600),
                  ),
                ),

              const SizedBox(height: 24),

              // ── Boutons timer ──────────────────────────────────────────
              _TimerControls(
                isRunning: timerState.isRunning,
                isPaused: timerState.isPaused,
                hasProject: timerState.selectedProjectId != null,
              ),

              const Spacer(flex: 3),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: hasSelection
          ? primary.withAlpha(18)
          : isDark ? const Color(0xFF1E293B) : Colors.white,
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
                  : AppColors.border(context),
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
                      : AppColors.surfaceFill(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    hasSelection
                        ? 'assets/icons/folder-actif.svg'
                        : 'assets/icons/folder-inactif.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      hasSelection
                          ? const Color(0xFF305DA8)
                          : const Color(0xFF9CA3AF),
                      BlendMode.srcIn,
                    ),
                  ),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Text(
                          'Choisir un projet',
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

class _ChronoDisplay extends StatefulWidget {
  final Duration elapsed;
  final bool isRunning;

  const _ChronoDisplay({required this.elapsed, required this.isRunning});

  @override
  State<_ChronoDisplay> createState() => _ChronoDisplayState();
}

class _ChronoDisplayState extends State<_ChronoDisplay> {
  Timer? _ticker;
  int _centiseconds = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isRunning) _startTicker();
  }

  @override
  void didUpdateWidget(_ChronoDisplay old) {
    super.didUpdateWidget(old);
    if (widget.isRunning && !old.isRunning) {
      _centiseconds = 0;
      _startTicker();
    } else if (!widget.isRunning && old.isRunning) {
      _stopTicker();
    }
  }

  void _startTicker() {
    _stopTicker();
    _centiseconds = 0;
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      setState(() {
        _centiseconds = (_centiseconds + 5) % 100;
      });
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final base = _format(widget.elapsed);
    final cs = _centiseconds.toString().padLeft(2, '0');

    return Column(
      children: [
        Text.rich(
          TextSpan(
            text: base,
            children: widget.isRunning
                ? [
                    TextSpan(
                      text: '.$cs',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.color
                            ?.withAlpha(150),
                      ),
                    ),
                  ]
                : null,
          ),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 44,
                letterSpacing: -1.5,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.isRunning ? 'hh : mm : ss . cc' : 'hh : mm : ss',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary(context),
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
    ref.read(sessionBarProvider.notifier).state = null;
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

    // Date + heures pour la barre session
    final startStr =
        DateFormat('HH:mm').format(result.startedAt.toLocal());
    final endStr =
        DateFormat('HH:mm').format(result.endedAt.toLocal());
    final dayRaw =
        DateFormat('EEEE d MMMM', 'fr_FR').format(result.startedAt.toLocal());
    final dayStr = dayRaw.isNotEmpty
        ? '${dayRaw[0].toUpperCase()}${dayRaw.substring(1)}'
        : dayRaw;
    final timeRangeStr = 'de $startStr à $endStr';

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
    final amountStr =
        '${amount.toStringAsFixed(2).replaceAll('.', ',')} $symbol';

    // Afficher la barre persistante dans AppShell
    ref.read(sessionBarProvider.notifier).state = SessionBarData(
      dayStr: dayStr,
      timeRangeStr: timeRangeStr,
      durationStr: durationStr,
      amountStr: amountStr,
      clientId: clientId,
      projectId: projectId,
      sessionId: result.sessionId,
    );
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
