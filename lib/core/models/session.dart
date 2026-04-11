class WorkSession {
  final String id;
  final String userId;
  final String projectId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final String? notes;
  final DateTime createdAt;

  const WorkSession({
    required this.id,
    required this.userId,
    required this.projectId,
    required this.startedAt,
    this.endedAt,
    this.durationMinutes,
    this.notes,
    required this.createdAt,
  });

  bool get isRunning => endedAt == null;

  factory WorkSession.fromJson(Map<String, dynamic> json) => WorkSession(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        projectId: json['project_id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'] as String)
            : null,
        durationMinutes: json['duration_minutes'] as int?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'project_id': projectId,
        'started_at': startedAt.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        if (notes != null) 'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };
}
