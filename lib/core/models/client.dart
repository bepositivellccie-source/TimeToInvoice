class Client {
  final String id;
  final String userId;
  final String name;       // Nom de famille (requis)
  final String? firstName; // Prénom
  final String? company;   // Entreprise
  final String? siret;
  final String? street;
  final String? zipCode;
  final String? city;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final DateTime createdAt;
  final String billingStatus; // 'overdue' | 'pending' | 'clear' | 'new'

  const Client({
    required this.id,
    required this.userId,
    required this.name,
    this.firstName,
    this.company,
    this.siret,
    this.street,
    this.zipCode,
    this.city,
    this.phone,
    this.whatsapp,
    this.email,
    required this.createdAt,
    this.billingStatus = 'new',
  });

  /// Label court selon le mode d'affichage utilisateur.
  /// [mode] : 'company' | 'firstname_lastname' | 'lastname'
  String labelWith(String mode) {
    switch (mode) {
      case 'company':
        if (company != null && company!.isNotEmpty) return company!;
        return fullPersonName.isNotEmpty ? fullPersonName : 'Client sans nom';
      case 'firstname_lastname':
        if (fullPersonName.isNotEmpty) return fullPersonName;
        return company ?? 'Client sans nom';
      case 'lastname':
        if (name.isNotEmpty) return name;
        return company ?? 'Client sans nom';
      default:
        return displayName;
    }
  }

  /// Sous-titre adapté au mode — complète visuellement le label.
  String subtitleWith(String mode) {
    switch (mode) {
      case 'company':
        // Entreprise en titre → prénom+nom en sous-titre, sinon contact
        if (company != null && company!.isNotEmpty) return fullPersonName;
        return phone ?? email ?? (siret != null ? 'SIRET: $siret' : '');
      case 'firstname_lastname':
      case 'lastname':
        // Nom en titre → entreprise en sous-titre, sinon contact
        if (company != null && company!.isNotEmpty) return company!;
        return phone ?? email ?? (siret != null ? 'SIRET: $siret' : '');
      default:
        if (company != null && company!.isNotEmpty) return fullPersonName;
        return phone ?? email ?? (siret != null ? 'SIRET: $siret' : '');
    }
  }

  /// Fallback company-first — utilisé pour les messages système (suppressions…)
  String get displayName {
    if (company != null && company!.isNotEmpty) return company!;
    return fullPersonName;
  }

  /// Adresse concaténée : "rue, code postal ville"
  String? get fullAddress {
    final s = street ?? '';
    final cityPart = '${zipCode ?? ''} ${city ?? ''}'.trim();
    final parts = [if (s.isNotEmpty) s, if (cityPart.isNotEmpty) cityPart];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Nom civil — "Prénom Nom" ou juste "Nom"
  String get fullPersonName =>
      (firstName != null && firstName!.isNotEmpty) ? '$firstName $name' : name;

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        name: json['name'] as String,
        firstName: json['first_name'] as String?,
        company: json['company'] as String?,
        siret: json['siret'] as String?,
        street: json['street'] as String?,
        zipCode: json['zip_code'] as String?,
        city: json['city'] as String?,
        phone: json['phone'] as String?,
        whatsapp: json['whatsapp'] as String?,
        email: json['email'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        billingStatus: (json['billing_status'] as String?) ?? 'new',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        if (firstName != null) 'first_name': firstName,
        if (company != null) 'company': company,
        if (siret != null) 'siret': siret,
        if (street != null) 'street': street,
        if (zipCode != null) 'zip_code': zipCode,
        if (city != null) 'city': city,
        if (phone != null) 'phone': phone,
        if (whatsapp != null) 'whatsapp': whatsapp,
        if (email != null) 'email': email,
        'created_at': createdAt.toIso8601String(),
      };
}
