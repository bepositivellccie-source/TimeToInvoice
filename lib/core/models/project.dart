class Project {
  final String id;
  final String userId;
  final String clientId;
  final String name;
  final double hourlyRate;
  final String currency;
  final String status; // 'en_cours' | 'en_attente' | 'termine'
  final int sortOrder;
  final DateTime createdAt;

  /// Backward compat — un projet "en_cours" est actif
  bool get isActive => status == 'en_cours' || status == 'active';

  const Project({
    required this.id,
    required this.userId,
    required this.clientId,
    required this.name,
    required this.hourlyRate,
    this.currency = 'EUR',
    this.status = 'en_cours',
    this.sortOrder = 0,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    // Migration transparente des anciens statuts
    var rawStatus = json['status'] as String? ?? 'en_cours';
    if (rawStatus == 'active') rawStatus = 'en_cours';
    if (rawStatus == 'completed') rawStatus = 'termine';

    return Project(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      clientId: json['client_id'] as String,
      name: json['name'] as String,
      hourlyRate: (json['hourly_rate'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      status: rawStatus,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'client_id': clientId,
        'name': name,
        'hourly_rate': hourlyRate,
        'currency': currency,
        'status': status,
        'sort_order': sortOrder,
        'created_at': createdAt.toIso8601String(),
      };

  Project copyWith({
    String? name,
    double? hourlyRate,
    String? currency,
    String? status,
    int? sortOrder,
  }) =>
      Project(
        id: id,
        userId: userId,
        clientId: clientId,
        name: name ?? this.name,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        currency: currency ?? this.currency,
        status: status ?? this.status,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
      );
}
