import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/session.dart' as models;

class TimerState {
  final bool isRunning;
  final bool isPaused;
  final String? activeSessionId;
  final DateTime? segmentStartedAt; // début du segment actif courant
  final Duration elapsed;           // temps du segment courant
  final Duration accumulated;       // temps travaillé avant le segment courant
  final String? selectedProjectId;

  const TimerState({
    this.isRunning = false,
    this.isPaused = false,
    this.activeSessionId,
    this.segmentStartedAt,
    this.elapsed = Duration.zero,
    this.accumulated = Duration.zero,
    this.selectedProjectId,
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
    // nullable fields handled below
  }) =>
      TimerState(
        isRunning: isRunning ?? this.isRunning,
        isPaused: isPaused ?? this.isPaused,
        activeSessionId: activeSessionId,
        segmentStartedAt: segmentStartedAt,
        elapsed: elapsed ?? this.elapsed,
        accumulated: accumulated ?? this.accumulated,
        selectedProjectId: selectedProjectId ?? this.selectedProjectId,
      );
}

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _ticker;
  final SupabaseClient _supabase;

  TimerNotifier(this._supabase) : super(const TimerState());

  void selectProject(String projectId) {
    if (state.isActive) return; // pas de changement en cours de session
    state = TimerState(selectedProjectId: projectId);
  }

  Future<void> start() async {
    if (state.isActive || state.selectedProjectId == null) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final now = DateTime.now().toUtc();
    final sessionId = const Uuid().v4();

    await _supabase.from('sessions').insert({
      'id': sessionId,
      'user_id': user.id,
      'project_id': state.selectedProjectId,
      'started_at': now.toIso8601String(),
    });

    state = TimerState(
      isRunning: true,
      activeSessionId: sessionId,
      segmentStartedAt: now,
      selectedProjectId: state.selectedProjectId,
    );

    _startTicker();
  }

  void pause() {
    if (!state.isRunning) return;
    _ticker?.cancel();
    _ticker = null;
    state = TimerState(
      isPaused: true,
      activeSessionId: state.activeSessionId,
      accumulated: state.accumulated + state.elapsed,
      selectedProjectId: state.selectedProjectId,
    );
  }

  void resume() {
    if (!state.isPaused) return;
    final now = DateTime.now().toUtc();
    state = TimerState(
      isRunning: true,
      activeSessionId: state.activeSessionId,
      segmentStartedAt: now,
      accumulated: state.accumulated,
      selectedProjectId: state.selectedProjectId,
    );
    _startTicker();
  }

  /// Retourne la session enregistrée + le nombre de secondes travaillées.
  Future<(models.WorkSession?, int)> stop() async {
    if (!state.isActive || state.activeSessionId == null) return (null, 0);

    _ticker?.cancel();
    _ticker = null;

    final now = DateTime.now().toUtc();
    final totalWorked = state.accumulated + state.elapsed;
    final totalSecs = totalWorked.inSeconds;
    final durationMinutes = (totalSecs / 60.0).round();

    final data = await _supabase
        .from('sessions')
        .update({
          'ended_at': now.toIso8601String(),
          'duration_minutes': durationMinutes,
          'duration_seconds': totalSecs,
        })
        .eq('id', state.activeSessionId!)
        .select()
        .single();

    final projectId = state.selectedProjectId;
    state = TimerState(selectedProjectId: projectId);

    return (models.WorkSession.fromJson(data), totalSecs);
  }

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
    _ticker?.cancel();
    super.dispose();
  }
}

final timerProvider =
    StateNotifierProvider<TimerNotifier, TimerState>((ref) {
  return TimerNotifier(Supabase.instance.client);
});
