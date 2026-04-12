import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ─── Entry point (isolate séparé) ────────────────────────────────────────────

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}

// ─── TaskHandler ──────────────────────────────────────────────────────────────

class TimerTaskHandler extends TaskHandler {
  bool _isPaused = false;
  int _totalSecs = 0;
  String _projectName = '';

  // ── Cycle de vie ────────────────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // L'état initial arrive via sendDataToTask juste après startService
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    if (!_isPaused) _totalSecs++;
    _updateNotification();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  // ── Données envoyées depuis l'isolate principal ──────────────────────────────

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    switch (map['type'] as String?) {
      case 'init':
        _totalSecs = (map['secs'] as num?)?.toInt() ?? 0;
        _projectName = map['name'] as String? ?? '';
        _isPaused = map['paused'] as bool? ?? false;
        _updateNotification();
      case 'pause':
        _isPaused = true;
        _updateNotification();
      case 'resume':
        _isPaused = false;
        _updateNotification();
      case 'sync':
        _totalSecs = (map['secs'] as num?)?.toInt() ?? _totalSecs;
    }
  }

  // ── Actions boutons notification ─────────────────────────────────────────────

  @override
  void onNotificationButtonPressed(String id) {
    switch (id) {
      case 'btn_pause':
        // On envoie l'action sémantique (pause OU resume selon état courant)
        FlutterForegroundTask.sendDataToMain(
          _isPaused ? 'btn_resume' : 'btn_pause',
        );
      case 'btn_stop':
        FlutterForegroundTask.sendDataToMain('btn_stop');
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/timer');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _updateNotification() {
    final h = (_totalSecs ~/ 3600).toString().padLeft(2, '0');
    final m = ((_totalSecs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_totalSecs % 60).toString().padLeft(2, '0');

    FlutterForegroundTask.updateService(
      notificationTitle: _projectName.isEmpty ? 'Timer' : _projectName,
      notificationText: '$h:$m:$s',
      notificationButtons: [
        NotificationButton(
          id: 'btn_pause',
          text: _isPaused ? '▶ Reprendre' : '⏸ Pause',
        ),
        const NotificationButton(id: 'btn_stop', text: '⏹ Terminer'),
      ],
    );
  }
}
