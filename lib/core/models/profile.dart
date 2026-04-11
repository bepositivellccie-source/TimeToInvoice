class Profile {
  final String? displayName;
  final String? address;
  final String? siret;

  const Profile({this.displayName, this.address, this.siret});

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        displayName: json['display_name'] as String?,
        address: json['address'] as String?,
        siret: json['siret'] as String?,
      );

  Profile copyWith({
    String? displayName,
    String? address,
    String? siret,
  }) =>
      Profile(
        displayName: displayName ?? this.displayName,
        address: address ?? this.address,
        siret: siret ?? this.siret,
      );
}
