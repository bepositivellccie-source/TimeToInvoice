class Profile {
  final String? displayName;
  final String? street;
  final String? zipCode;
  final String? city;
  final String? siret;
  final String? tvaNumber;
  final String? email;
  final String? phone;
  final String? iban;

  const Profile({
    this.displayName,
    this.street,
    this.zipCode,
    this.city,
    this.siret,
    this.tvaNumber,
    this.email,
    this.phone,
    this.iban,
  });

  /// Adresse concaténée : "rue, code postal ville"
  String? get fullAddress {
    final s = street ?? '';
    final cityPart = '${zipCode ?? ''} ${city ?? ''}'.trim();
    final parts = [if (s.isNotEmpty) s, if (cityPart.isNotEmpty) cityPart];
    return parts.isEmpty ? null : parts.join(', ');
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        displayName: json['display_name'] as String?,
        street: json['street'] as String?,
        zipCode: json['zip_code'] as String?,
        city: json['city'] as String?,
        siret: json['siret'] as String?,
        tvaNumber: json['tva_number'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        iban: json['iban'] as String?,
      );

  Profile copyWith({
    String? displayName,
    String? street,
    String? zipCode,
    String? city,
    String? siret,
    String? tvaNumber,
    String? email,
    String? phone,
    String? iban,
  }) =>
      Profile(
        displayName: displayName ?? this.displayName,
        street: street ?? this.street,
        zipCode: zipCode ?? this.zipCode,
        city: city ?? this.city,
        siret: siret ?? this.siret,
        tvaNumber: tvaNumber ?? this.tvaNumber,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        iban: iban ?? this.iban,
      );
}
