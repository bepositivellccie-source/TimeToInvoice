class Client {
  final String id;
  final String userId;
  final String name;       // Nom de famille (requis)
  final String? firstName; // Prénom
  final String? company;   // Entreprise
  final String? siret;
  final String? address;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final DateTime createdAt;

  const Client({
    required this.id,
    required this.userId,
    required this.name,
    this.firstName,
    this.company,
    this.siret,
    this.address,
    this.phone,
    this.whatsapp,
    this.email,
    required this.createdAt,
  });

  /// Nom d'affichage : "Prénom Nom" ou juste "Nom"
  String get displayName =>
      (firstName != null && firstName!.isNotEmpty) ? '$firstName $name' : name;

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        firstName: json['first_name'] as String?,
        company: json['company'] as String?,
        siret: json['siret'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        whatsapp: json['whatsapp'] as String?,
        email: json['email'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        if (firstName != null) 'first_name': firstName,
        if (company != null) 'company': company,
        if (siret != null) 'siret': siret,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (whatsapp != null) 'whatsapp': whatsapp,
        if (email != null) 'email': email,
        'created_at': createdAt.toIso8601String(),
      };
}
