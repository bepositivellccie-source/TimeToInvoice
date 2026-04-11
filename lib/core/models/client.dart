class Client {
  final String id;
  final String userId;
  final String name;
  final String? siret;
  final String? address;
  final String? email;
  final DateTime createdAt;

  const Client({
    required this.id,
    required this.userId,
    required this.name,
    this.siret,
    this.address,
    this.email,
    required this.createdAt,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        siret: json['siret'] as String?,
        address: json['address'] as String?,
        email: json['email'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        if (siret != null) 'siret': siret,
        if (address != null) 'address': address,
        if (email != null) 'email': email,
        'created_at': createdAt.toIso8601String(),
      };
}
