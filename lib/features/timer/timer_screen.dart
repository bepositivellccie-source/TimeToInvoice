import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/models/project.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/session_bar_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/theme/cf_palette.dart';
import 'timer_notifier.dart';

/// Écran Chrono — refonte design ChronoFacture v2.
///
/// 2 états visuels :
///   • Repos  : sélecteur de projet (dashed si vide), grand "00:00:00",
///              bouton play (88px, accentB) + halo, projets récents.
///   • Actif  : sélecteur de projet (solid), point pulsant rouge, timer live,
///              boutons Pause/Resume + Stop bordeaux, footer total + montant.
class TimerScreen extends ConsumerWidget {
  const TimerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);
    final entriesAsync = ref.watch(timerProjectsProvider);

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        child: entriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Erreur : $e',
                  style: TextStyle(color: CF.text(context))),
            ),
          ),
          data: (entries) => _ChronoBody(
            timerState: timerState,
            entries: entries,
          ),
        ),
      ),
    );
  }
}

// ─── Layout principal ────────────────────────────────────────────────────────

class _ChronoBody extends ConsumerWidget {
  final TimerState timerState;
  final List<TimerEntry> entries;

  const _ChronoBody({required this.timerState, required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = timerState.isActive;
    final selected =
        entries.where((e) => e.project.id == timerState.selectedProjectId).firstOrNull;

    return Column(
      children: [
        // ── Sélecteur projet ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _ProjectSelectorCard(
            selected: selected,
            entries: entries,
            enabled: !isActive,
          ),
        ),

        // ── Statut session ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: _StatusLine(
            isActive: isActive,
            isPaused: timerState.isPaused,
            selected: selected,
          ),
        ),

        // ── Bloc central : timer + boutons ──────────────────────────────
        Expanded(
          child: _ChronoCenter(
            timerState: timerState,
            hasProject: timerState.selectedProjectId != null,
          ),
        ),

        // ── Footer : projets récents (idle) ou total/montant (actif) ───
        if (isActive && selected != null)
          _SessionTotalFooter(
            durationStr: _formatHms(timerState.totalWorked),
            amount: _amountFor(timerState.totalWorked, selected.project),
          )
        else
          _RecentProjects(entries: entries),
      ],
    );
  }

  static String _formatHms(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String _amountFor(Duration worked, Project project) {
    final amount = (worked.inSeconds / 3600.0) * project.hourlyRate;
    final symbol = const {
          'EUR': '€',
          'USD': '\$',
          'GBP': '£',
          'CHF': 'CHF',
        }[project.currency] ??
        project.currency;
    return '${amount.toStringAsFixed(2).replaceAll('.', ',')} $symbol';
  }
}

// ─── Sélecteur projet ────────────────────────────────────────────────────────

class _ProjectSelectorCard extends ConsumerWidget {
  final TimerEntry? selected;
  final List<TimerEntry> entries;
  final bool enabled;

  const _ProjectSelectorCard({
    required this.selected,
    required this.entries,
    required this.enabled,
  });

  Future<void> _pickProject(BuildContext context, WidgetRef ref) async {
    if (entries.isEmpty) return;
    final id = await context.push<String>('/projects/select');
    if (id == null) return;
    final entry = entries.where((e) => e.project.id == id).firstOrNull;
    final notifName = entry != null
        ? '${entry.project.name} · ${entry.clientName}'
        : null;
    ref.read(timerProvider.notifier).selectProject(id, projectName: notifName);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSelection = selected != null;
    final emptyState = entries.isEmpty;

    final border = hasSelection || emptyState
        ? CF.border(context)
        : CF.border(context);

    return Material(
      color: CF.surface(context),
      borderRadius: BorderRadius.circular(CFRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(CFRadius.lg),
        onTap: enabled ? () => _pickProject(context, ref) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CFRadius.lg),
            border: hasSelection
                ? Border.all(color: border, width: 0.5)
                : Border.all(
                    color: CF.border(context),
                    width: 1,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: CF.surfaceAlt(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  hasSelection ? LucideIcons.user : LucideIcons.plus,
                  size: 18,
                  color: hasSelection ? CF.chrono : CF.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROJET',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: CF.faint(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (hasSelection)
                      Text(
                        '${selected!.project.name} — ${selected!.clientName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: CFType.subtitle,
                          fontWeight: FontWeight.w600,
                          color: CF.text(context),
                        ),
                      )
                    else
                      Text(
                        emptyState
                            ? 'Aucun projet — créez-en un'
                            : 'Choisir un projet',
                        style: GoogleFonts.inter(
                          fontSize: CFType.subtitle,
                          fontWeight: FontWeight.w600,
                          color: emptyState ? CF.muted(context) : CF.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: CF.faint(context)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Ligne statut session ────────────────────────────────────────────────────

class _StatusLine extends StatelessWidget {
  final bool isActive;
  final bool isPaused;
  final TimerEntry? selected;

  const _StatusLine({
    required this.isActive,
    required this.isPaused,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final String label;
    final bool pulse;

    if (!isActive) {
      dotColor = CF.faint(context);
      label = selected == null
          ? 'En attente d\'un projet'
          : 'Prêt à démarrer';
      pulse = false;
    } else if (isPaused) {
      dotColor = CF.orange;
      label = 'Session en pause · ${selected?.clientName ?? ''}';
      pulse = false;
    } else {
      dotColor = CF.bordeaux;
      label = 'Session en cours · ${selected?.clientName ?? ''}';
      pulse = true;
    }

    return Row(
      children: [
        _PulsingDot(color: dotColor, animate: pulse),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isActive ? CF.muted(context) : CF.faint(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  final bool animate;
  const _PulsingDot({required this.color, required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_PulsingDot old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final progress = _ctrl.value;
        final ringSize = widget.animate ? 6 + 12 * progress : 6.0;
        final ringOpacity =
            widget.animate ? (1 - progress).clamp(0.0, 1.0) * 0.35 : 0.0;
        return SizedBox(
          width: 18,
          height: 18,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.animate)
                Container(
                  width: ringSize,
                  height: ringSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: ringOpacity),
                  ),
                ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Bloc central : timer + boutons ─────────────────────────────────────────

class _ChronoCenter extends ConsumerWidget {
  final TimerState timerState;
  final bool hasProject;

  const _ChronoCenter({required this.timerState, required this.hasProject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = timerState.isActive;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
      child: Column(
        children: [
          // ── Timer mega ────────────────────────────────────────────────
          _TimerMega(
            elapsed: timerState.totalWorked,
            isRunning: timerState.isRunning,
            faded: !isActive,
          ),
          const SizedBox(height: 18),
          _SubLabel(timerState: timerState),

          const SizedBox(height: 52),

          // ── Boutons ──────────────────────────────────────────────────
          _ChronoControls(
            timerState: timerState,
            hasProject: hasProject,
          ),

          const SizedBox(height: 18),
          _CtaCaption(timerState: timerState, hasProject: hasProject),
        ],
      ),
    );
  }
}

// ─── Timer affichage ────────────────────────────────────────────────────────

class _TimerMega extends StatefulWidget {
  final Duration elapsed;
  final bool isRunning;
  final bool faded;

  const _TimerMega({
    required this.elapsed,
    required this.isRunning,
    required this.faded,
  });

  @override
  State<_TimerMega> createState() => _TimerMegaState();
}

class _TimerMegaState extends State<_TimerMega> {
  Timer? _ticker;
  // Force rebuild every second so the displayed elapsed time advances
  // smoothly even between provider state updates.
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isRunning) _start();
  }

  @override
  void didUpdateWidget(_TimerMega old) {
    super.didUpdateWidget(old);
    if (widget.isRunning && !old.isRunning) {
      _start();
    } else if (!widget.isRunning && old.isRunning) {
      _stop();
    }
  }

  void _start() {
    _stop();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.elapsed;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');

    final mainColor = widget.faded ? CF.faint(context) : CF.text(context);
    final colonColor = CF.faint(context);

    final digitStyle = GoogleFonts.jetBrainsMono(
      fontSize: 64,
      fontWeight: FontWeight.w300,
      color: mainColor,
      height: 1,
      letterSpacing: -2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final colonStyle = digitStyle.copyWith(
      color: colonColor,
      fontWeight: FontWeight.w200,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(h, style: digitStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(':', style: colonStyle),
        ),
        Text(m, style: digitStyle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(':', style: colonStyle),
        ),
        Text(s, style: digitStyle),
      ],
    );
  }
}

// ─── Sous-label timer (Démarré à / Aucune session) ──────────────────────────

class _SubLabel extends StatelessWidget {
  final TimerState timerState;
  const _SubLabel({required this.timerState});

  @override
  Widget build(BuildContext context) {
    String label;
    if (!timerState.isActive) {
      label = 'Aucune session en cours';
    } else if (timerState.isPaused) {
      label = 'En pause · Facturable';
    } else {
      final start = timerState.segmentStartedAt;
      if (start != null) {
        final hms = DateFormat('HH:mm:ss').format(start.toLocal());
        label = 'Démarré à $hms · Facturable';
      } else {
        label = 'Session en cours · Facturable';
      }
    }
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12.5,
        color: CF.muted(context),
        letterSpacing: 0.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ─── Boutons (idle = play seul, actif = pause/resume + stop) ───────────────

class _ChronoControls extends ConsumerStatefulWidget {
  final TimerState timerState;
  final bool hasProject;

  const _ChronoControls({
    required this.timerState,
    required this.hasProject,
  });

  @override
  ConsumerState<_ChronoControls> createState() => _ChronoControlsState();
}

class _ChronoControlsState extends ConsumerState<_ChronoControls> {
  bool _starting = false;

  Future<void> _start() async {
    ref.read(sessionBarProvider.notifier).state = null;
    setState(() => _starting = true);
    try {
      await ref.read(timerProvider.notifier).start();
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _pause() => ref.read(timerProvider.notifier).pause();
  void _resume() => ref.read(timerProvider.notifier).resume();

  void _stop() {
    final projectId = ref.read(timerProvider).selectedProjectId;
    final result = ref.read(timerProvider.notifier).stop();
    if (result == null) return;

    if (projectId != null) {
      ref.invalidate(sessionsByProjectProvider(projectId));
    }
    ref.invalidate(projectsTotalSecondsProvider);

    final secs = result.totalSecs;
    final project = ref.read(projectsProvider).valueOrNull
        ?.where((p) => p.id == projectId)
        .firstOrNull;
    final clientId = project?.clientId;

    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    final durationStr = '$h:$m:$s';

    final startStr = DateFormat('HH:mm').format(result.startedAt.toLocal());
    final endStr = DateFormat('HH:mm').format(result.endedAt.toLocal());
    final dayRaw =
        DateFormat('EEEE d MMMM', 'fr_FR').format(result.startedAt.toLocal());
    final dayStr = dayRaw.isNotEmpty
        ? '${dayRaw[0].toUpperCase()}${dayRaw.substring(1)}'
        : dayRaw;
    final timeRangeStr = 'de $startStr à $endStr';

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
    final isActive = widget.timerState.isActive;

    if (!isActive) {
      // Repos : un seul gros bouton play (88px, accentB) avec halo
      return _PlayBigButton(
        enabled: widget.hasProject && !_starting,
        loading: _starting,
        onTap: _start,
      );
    }

    // Actif : 3 slots — pause/resume (gauche), stop (centre), spacer (droite)
    final leftIsResume = widget.timerState.isPaused;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SecondaryCircle(
          icon: leftIsResume ? LucideIcons.play : LucideIcons.pause,
          onTap: leftIsResume ? _resume : _pause,
        ),
        const SizedBox(width: 18),
        _StopBigButton(onTap: _stop),
        const SizedBox(width: 18),
        const SizedBox(width: 64, height: 64), // spacer pour aligner
      ],
    );
  }
}

class _PlayBigButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;
  const _PlayBigButton({
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? CF.accentB : CF.accentB.withValues(alpha: 0.5);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Halo discret
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          ),
        ),
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: enabled ? 8 : 0,
          shadowColor: CF.accentB.withValues(alpha: 0.4),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: SizedBox(
              width: 88,
              height: 88,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.play, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StopBigButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StopBigButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CF.bordeaux,
      shape: const CircleBorder(),
      elevation: 8,
      shadowColor: CF.bordeaux.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 88,
          height: 88,
          child: Center(
            child: Icon(LucideIcons.square,
                color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _SecondaryCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SecondaryCircle({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: CircleBorder(
        side: BorderSide(color: CF.border(context), width: 1.5),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Center(
            child: Icon(icon, color: CF.muted(context), size: 22),
          ),
        ),
      ),
    );
  }
}

// ─── Caption sous boutons ───────────────────────────────────────────────────

class _CtaCaption extends StatelessWidget {
  final TimerState timerState;
  final bool hasProject;
  const _CtaCaption({required this.timerState, required this.hasProject});

  @override
  Widget build(BuildContext context) {
    if (timerState.isActive) {
      return Text(
        'Arrêter la session',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: CF.muted(context),
        ),
      );
    }
    return Column(
      children: [
        Text(
          hasProject ? 'Démarrer la session' : 'Choisis d\'abord un projet',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CF.text(context),
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Chaque seconde compte',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: CF.faint(context),
          ),
        ),
      ],
    );
  }
}

// ─── Footer "Cette session" / "À facturer" ──────────────────────────────────

class _SessionTotalFooter extends StatelessWidget {
  final String durationStr;
  final String amount;
  const _SessionTotalFooter({required this.durationStr, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: CF.surface(context),
          borderRadius: BorderRadius.circular(CFRadius.lg),
          border: Border.all(color: CF.border(context), width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _miniLabel(context, 'CETTE SESSION'),
                const SizedBox(height: 2),
                Text(
                  durationStr,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: CF.text(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _miniLabel(context, 'À FACTURER'),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CF.muted(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniLabel(BuildContext context, String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: CF.faint(context),
        ),
      );
}

// ─── Projets récents (idle) ─────────────────────────────────────────────────

class _RecentProjects extends ConsumerWidget {
  final List<TimerEntry> entries;
  const _RecentProjects({required this.entries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final shown = entries.take(2).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'PROJETS RÉCENTS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: CF.faint(context),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: CF.surface(context),
              borderRadius: BorderRadius.circular(CFRadius.lg),
              border: Border.all(color: CF.border(context), width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: CF.border(context),
                    ),
                  _RecentRow(
                    entry: shown[i],
                    onTap: () {
                      ref.read(timerProvider.notifier).selectProject(
                            shown[i].project.id,
                            projectName:
                                '${shown[i].project.name} · ${shown[i].clientName}',
                          );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final TimerEntry entry;
  final VoidCallback onTap;
  const _RecentRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: CF.surfaceAlt(context),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.user, size: 15, color: CF.chrono),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.project.name} — ${entry.clientName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: CF.text(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${entry.project.hourlyRate.toStringAsFixed(0)} ${_symbol(entry.project.currency)} / h',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CF.faint(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: CF.faint(context)),
          ],
        ),
      ),
    );
  }

  static String _symbol(String currency) =>
      const {'EUR': '€', 'USD': '\$', 'GBP': '£', 'CHF': 'CHF'}[currency] ??
      currency;
}
