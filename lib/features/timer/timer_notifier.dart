import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/session.dart' as models;

class TimerState {
  final bool isRunning;
  final String? activeSessionId;
  final DateTime? startedAt;
  final Duration elapsed;
  final String? selectedProjectId;

  const TimerState({
    this.isRunning = false,
    this.activeSessionId,
    this.startedAt,
    this.elapsed = Duration.zero,
    this.selectedProjectId,
  });

  TimerState copyWith({
    bool? isRunning,
    String? activeSessionId,
    DateTime? startedAt,
    Duration? elapsed,
    String? selectedProjectId,
  }) =>
      TimerState(
        isRunning: isRunning ?? this.isRunning,
        activeSessionId: activeSessionId ?? this.activeSessionId,
        startedAt: startedAt ?? this.startedAt,
        elapsed: elapsed ?? this.elapsed,
        selectedProjectId: selectedProjectId ?? this.selectedProjectId,
      );
}

class TimerNotifier extends StateNotifier<TimerState> {
  Timer? _ticker;
  final SupabaseClient _supabase;

  TimerNotifier(this._supabase) : super(const TimerState());

  void selectProject(String projectId) {
    state = state.copyWith(selectedProjectId: projectId);
  }

  Future<void> start() async {
    if (state.isRunning || state.selectedProjectId == null) return;

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

    state = state.copyWith(
      isRunning: true,
      activeSessionId: sessionId,
      startedAt: now,
      elapsed: Duration.zero,
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final elapsed = DateTime.now().toUtc().difference(state.startedAt!);
      state = state.copyWith(elapsed: elapsed);
    });
  }

  Future<models.WorkSession?> stop() async {
    if (!state.isRunning || state.activeSessionId == null) return null;

    _ticker?.cancel();
    _ticker = null;

    final now = DateTime.now().toUtc();
    final durationMinutes = state.elapsed.inMinutes;

    final data = await _supabase
        .from('sessions')
        .update({
          'ended_at': now.toIso8601String(),
          'duration_minutes': durationMinutes,
        })
        .eq('id', state.activeSessionId!)
        .select()
        .single();

    state = state.copyWith(
      isRunning: false,
      activeSessionId: null,
      startedAt: null,
      elapsed: Duration.zero,
    );

    return models.WorkSession.fromJson(data);
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
