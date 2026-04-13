import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/services/timer_task_handler.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class TimerState {
  final bool isRunning;
  final bool isPaused;
  final String? activeSessionId;
  final DateTime? segmentStartedAt; // début du segment actif courant
  final Duration elapsed;           // temps du segment courant
  final Duration accumulated;       // temps travaillé avant le segment courant
  final String? selectedProjectId;
  final String? selectedProjectName; // "Projet · Client" — affiché dans la notif

  const TimerState({
    this.isRunning = false,
    this.isPaused = false,
    this.activeSessionId,
    this.segmentStartedAt,
    this.elapsed = Duration.zero,
    this.accumulated = Duration.zero,
    this.selectedProjectId,
    this.selectedProjectName,
  });

  /// Temps total travaillé (cumulé + segment courant)
  Duration get totalWorked => accumulated + elapsed;

  /// Actif = en cours ou en pause (session ouverte)
  bool get isActive => isRunning || isPaused;

  TimerState copyWith({
    bool? isRunning,
    bool? isPaused,
    Duration? elapsed,
    Duration? accumulated,
    String? selectedProjectId,
    String? selectedProjectName,
  }) =>
      TimerState(
        isRunning: isRunning ?? this.isRunning,
        isPaused: isPaused ?? this.isPaused,
        activeSessionId: activeSessionId,
        segmentStartedAt: segmentStartedAt,
        elapsed: elapsed ?? this.elapsed,
        accumulated: accumulated ?? this.accumulated,
        selectedProjectId: selectedProjectId ?? this.selectedProjectId,
        selectedProjectName: selectedProjectName ?? this.selectedProjectName,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _ticker;
  Future<void>? _pendingInsert; // insert optimiste en cours
  final SupabaseClient _supabase;
  final Ref _ref;

  TimerNotifier(this._supabase, this._ref) : super(const TimerState()) {
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  // ── Sélection projet ─────────────────────────────────────────────────────────

  void selectProject(String projectId, {String? projectName}) {
    if (state.isActive) return;
    state = TimerState(
      selectedProjectId: projectId,
      selectedProjectName: projectName,
    );
  }

  // ── Démarrer ─────────────────────────────────────────────────────────────────

  Future<void> start() async {
    if (state.isActive || state.selectedProjectId == null) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now().toUtc();
    final sessionId = const Uuid().v4();
    final projectId = state.selectedProjectId!;
    final projectName = state.selectedProjectName;

    // Optimiste — UI répond immédiatement, avant l'insert DB
    state = TimerState(
      isRunning: true,
      activeSessionId: sessionId,
      segmentStartedAt: now,
      selectedProjectId: projectId,
      selectedProjectName: projectName,
    );
    _startTicker();
    await _startForegroundService();

    // Insert en arrière-plan — stop() l'attend avant de mettre à jour la ligne
    _pendingInsert = () async {
      try {
        await _supabase.from('sessions').insert({
          'id': sessionId,
          'user_id': user.id,
          'project_id': projectId,
          'started_at': now.toIso8601String(),
        });
      } catch (_) {
        // Rollback si l'insert échoue
        _ticker?.cancel();
        _ticker = null;
        await FlutterForegroundTask.stopService();
        state = TimerState(
          selectedProjectId: projectId,
          selectedProjectName: projectName,
        );
        rethrow;
      } finally {
        _pendingInsert = null;
      }
    }();
  }

  // ── Pause ────────────────────────────────────────────────────────────────────

  void pause() {
    if (!state.isRunning) return;
    _ticker?.cancel();
    _ticker = null;
    state = TimerState(
      isPaused: true,
      activeSessionId: state.activeSessionId,
      accumulated: state.accumulated + state.elapsed,
      selectedProjectId: state.selectedProjectId,
      selectedProjectName: state.selectedProjectName,
    );
    FlutterForegroundTask.sendDataToTask({'type': 'pause'});
  }

  // ── Reprendre ────────────────────────────────────────────────────────────────

  void resume() {
    if (!state.isPaused) return;
    final now = DateTime.now().toUtc();
    state = TimerState(
      isRunning: true,
      activeSessionId: state.activeSessionId,
      segmentStartedAt: now,
      accumulated: state.accumulated,
      selectedProjectId: state.selectedProjectId,
      selectedProjectName: state.selectedProjectName,
    );
    _startTicker();
    FlutterForegroundTask.sendDataToTask({'type': 'resume'});
  }

  // ── Terminer ─────────────────────────────────────────────────────────────────

  /// Données renvoyées immédiatement par [stop] pour l'UI (snackbar).
  /// L'UPDATE Supabase se fait en arrière-plan.
  ({String sessionId, DateTime startedAt, DateTime endedAt, int totalSecs, String? projectId})? stop() {
    if (!state.isActive || state.activeSessionId == null) return null;

    _ticker?.cancel();
    _ticker = null;

    final now = DateTime.now().toUtc();
    final totalWorked = state.accumulated + state.elapsed;
    final totalSecs = totalWorked.inSeconds;
    final sessionId = state.activeSessionId!;
    final projectId = state.selectedProjectId;
    final startedAt = state.segmentStartedAt ?? now;

    // Reset immédiat de l'état local — UI réactive instantanément
    state = TimerState(
      selectedProjectId: projectId,
      selectedProjectName: state.selectedProjectName,
    );

    FlutterForegroundTask.stopService();

    // UPDATE Supabase en arrière-plan
    _updateSessionInBackground(sessionId, now, totalSecs);

    return (
      sessionId: sessionId,
      startedAt: startedAt,
      endedAt: now,
      totalSecs: totalSecs,
      projectId: projectId,
    );
  }

  /// Attend l'insert optimiste puis met à jour la session dans Supabase.
  /// En cas d'échec, affiche une erreur via un callback.
  Future<void> _updateSessionInBackground(
      String sessionId, DateTime endedAt, int totalSecs) async {
    try {
      await _pendingInsert;
    } catch (_) {
      // L'insert initial a échoué — session inexistante, rien à mettre à jour
      return;
    }

    final durationMinutes = (totalSecs / 60.0).round();
    try {
      await _supabase
          .from('sessions')
          .update({
            'ended_at': endedAt.toIso8601String(),
            'duration_minutes': durationMinutes,
            'duration_seconds': totalSecs,
          })
          .eq('id', sessionId);
    } catch (_) {
      // L'erreur sera visible au prochain refresh des sessions
    }
  }

  // ── Callback depuis le TaskHandler (actions boutons notification) ─────────────

  void _onTaskData(Object data) {
    if (data is! String) return;
    switch (data) {
      case 'btn_pause':
        pause();
      case 'btn_resume':
        resume();
      case 'btn_stop':
        final projectId = state.selectedProjectId;
        stop();
        if (projectId != null) {
          _ref.invalidate(sessionsByProjectProvider(projectId));
        }
        _ref.invalidate(projectsTotalSecondsProvider);
    }
  }

  // ── Foreground service ───────────────────────────────────────────────────────

  Future<void> _startForegroundService() async {
    final notifPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final projectName = state.selectedProjectName ?? 'Timer';

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: projectName,
      notificationText: '00:00:00',
      notificationButtons: const [
        NotificationButton(id: 'btn_pause', text: '⏸ Pause'),
        NotificationButton(id: 'btn_stop', text: '⏹ Terminer'),
      ],
      callback: startCallback,
    );

    // Synchronise l'état initial avec le TaskHandler
    FlutterForegroundTask.sendDataToTask({
      'type': 'init',
      'secs': 0,
      'name': projectName,
      'paused': false,
    });
  }

  // ── Ticker principal (main isolate) ──────────────────────────────────────────

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.segmentStartedAt == null) return;
      final elapsed =
          DateTime.now().toUtc().difference(state.segmentStartedAt!);
      state = state.copyWith(elapsed: elapsed);
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _ticker?.cancel();
    super.dispose();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final timerProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier(Supabase.instance.client, ref);
});
