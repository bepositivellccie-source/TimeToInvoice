class Profile {
  final String? displayName; // Nom de famille
  final String? firstName;
  final String? company;
  final String? street;
  final String? zipCode;
  final String? city;
  final String? siret;
  final String? tvaNumber;
  final String? email;
  final String? phone;
  final String? iban;
  final double? defaultHourlyRate;
  final String tvaRegime; // 'franchise' ou 'assujetti'
  final double? tvaRate;  // null si franchise, 20.0 si assujetti

  const Profile({
    this.displayName,
    this.firstName,
    this.company,
    this.street,
    this.zipCode,
    this.city,
    this.siret,
    this.tvaNumber,
    this.email,
    this.phone,
    this.iban,
    this.defaultHourlyRate,
    this.tvaRegime = 'franchise',
    this.tvaRate,
  });

  /// Adresse concaténée : "rue, code postal ville"
  String? get fullAddress {
    final s = street ?? '';
    final cityPart = '${zipCode ?? ''} ${city ?? ''}'.trim();
    final parts = [if (s.isNotEmpty) s, if (cityPart.isNotEmpty) cityPart];
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Nom civil — "Prénom Nom" ou juste "Nom"
  String get fullPersonName => (firstName != null && firstName!.isNotEmpty)
      ? '$firstName ${displayName ?? ''}'.trim()
      : (displayName ?? '');

  /// Label affiché prioritaire : raison sociale sinon nom civil
  String get headerName {
    if (company != null && company!.isNotEmpty) return company!;
    final person = fullPersonName;
    return person.isNotEmpty ? person : '';
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        displayName: json['display_name'] as String?,
        firstName: json['first_name'] as String?,
        company: json['company'] as String?,
        street: json['street'] as String?,
        zipCode: json['zip_code'] as String?,
        city: json['city'] as String?,
        siret: json['siret'] as String?,
        tvaNumber: json['tva_number'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        iban: json['iban'] as String?,
        defaultHourlyRate: (json['default_hourly_rate'] as num?)?.toDouble(),
        tvaRegime: json['tva_regime'] as String? ?? 'franchise',
        tvaRate: (json['tva_rate'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'first_name': firstName,
        'company': company,
        'street': street,
        'zip_code': zipCode,
        'city': city,
        'siret': siret,
        'tva_number': tvaNumber,
        'email': email,
        'phone': phone,
        'iban': iban,
        'default_hourly_rate': defaultHourlyRate,
        'tva_regime': tvaRegime,
        'tva_rate': tvaRate,
      };

  Profile copyWith({
    String? displayName,
    String? firstName,
    String? company,
    String? street,
    String? zipCode,
    String? city,
    String? siret,
    String? tvaNumber,
    String? email,
    String? phone,
    String? iban,
    double? defaultHourlyRate,
    String? tvaRegime,
    double? tvaRate,
  }) =>
      Profile(
        displayName: displayName ?? this.displayName,
        firstName: firstName ?? this.firstName,
        company: company ?? this.company,
        street: street ?? this.street,
        zipCode: zipCode ?? this.zipCode,
        city: city ?? this.city,
        siret: siret ?? this.siret,
        tvaNumber: tvaNumber ?? this.tvaNumber,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        iban: iban ?? this.iban,
        defaultHourlyRate: defaultHourlyRate ?? this.defaultHourlyRate,
        tvaRegime: tvaRegime ?? this.tvaRegime,
        tvaRate: tvaRate ?? this.tvaRate,
      );
}
