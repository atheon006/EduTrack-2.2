/// Modèles de jetons d'invitation cryptés à usage unique
/// Couvre: Directeur / Préfet et Enseignant

class InvitationDirecteur {
  final String id;
  final String ecoleId;
  final String ecoleNom;
  final String emailDirecteur;
  final String token;
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
  bool get estExpire => DateTime.now().isAfter(expiresAt);

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

/// Invitation générique pour Directeur ou Enseignant
class InvitationPersonnel {
  final String id;
  final String ecoleId;
  final String ecoleNom;
  final String emailPersonnel;
  final String token;
  final String typeRole; // 'directeur' ou 'enseignant'
  final String nomRole;  // 'Directeur' ou 'Enseignant'
  final bool estUtilise;
  final DateTime createdAt;
  final DateTime expiresAt;

  InvitationPersonnel({
    required this.id,
    required this.ecoleId,
    required this.ecoleNom,
    required this.emailPersonnel,
    required this.token,
    required this.typeRole,
    required this.nomRole,
    this.estUtilise = false,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get estValide => !estUtilise && DateTime.now().isBefore(expiresAt);
  bool get estExpire => DateTime.now().isAfter(expiresAt);

  factory InvitationPersonnel.fromMap(Map<String, dynamic> map, String docId) {
    return InvitationPersonnel(
      id: docId,
      ecoleId: map['ecoleId'] ?? '',
      ecoleNom: map['ecoleNom'] ?? '',
      emailPersonnel: map['emailPersonnel'] ?? '',
      token: map['token'] ?? '',
      typeRole: map['typeRole'] ?? 'enseignant',
      nomRole: map['nomRole'] ?? 'Enseignant',
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
      'emailPersonnel': emailPersonnel,
      'token': token,
      'typeRole': typeRole,
      'nomRole': nomRole,
      'estUtilise': estUtilise,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
    };
  }
}
