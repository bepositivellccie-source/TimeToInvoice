class Project {
  final String id;
  final String userId;
  final String clientId;
  final String name;
  final double hourlyRate;
  final String currency;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.userId,
    required this.clientId,
    required this.name,
    required this.hourlyRate,
    this.currency = 'EUR',
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        clientId: json['client_id'] as String,
        name: json['name'] as String,
        hourlyRate: (json['hourly_rate'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'EUR',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'client_id': clientId,
        'name': name,
        'hourly_rate': hourlyRate,
        'currency': currency,
        'created_at': createdAt.toIso8601String(),
      };
}
