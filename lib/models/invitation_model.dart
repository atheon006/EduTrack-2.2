/// Modèle de jeton d'invitation crypté pour Directeur / Préfet d'école
/// Jeton à usage unique qui expire dès l'inscription ou après une durée définie

class InvitationDirecteur {
  final String id;
  final String ecoleId;
  final String ecoleNom;
  final String emailDirecteur;
  final String token; // Jeton unique crypté
  final bool estUtilise;
  final DateTime createdAt;
  final DateTime expiresAt;

  InvitationDirecteur({
    required this.id,
    required this.ecoleId,
    required this.ecoleNom,
    required this.emailDirecteur,
    required this.token,
    this.estUtilise = false,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get estValide => !estUtilise && DateTime.now().isBefore(expiresAt);

  factory InvitationDirecteur.fromMap(Map<String, dynamic> map, String docId) {
    return InvitationDirecteur(
      id: docId,
      ecoleId: map['ecoleId'] ?? '',
      ecoleNom: map['ecoleNom'] ?? '',
      emailDirecteur: map['emailDirecteur'] ?? '',
      token: map['token'] ?? '',
      estUtilise: map['estUtilise'] as bool? ?? false,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      expiresAt: (map['expiresAt'] as dynamic)?.toDate() ??
          DateTime.now().add(const Duration(days: 7)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ecoleId': ecoleId,
      'ecoleNom': ecoleNom,
      'emailDirecteur': emailDirecteur,
      'token': token,
      'estUtilise': estUtilise,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
    };
  }
}
