/// Modèle Utilisateur étendu pour la gestion multi-rôles RDC
/// Rôles: superAdmin, directeur/admin, enseignant, élève, parent

enum RoleUtilisateur {
  superAdmin,    // Gère toutes les écoles
  directeur,     // Directeur + Admin scolaire d'une école
  enseignant,    // Enseigne des matières dans des classes
  eleve,         // Élève inscrit dans une classe
  parent,        // Parent/Tuteur d'un ou plusieurs élèves
}

extension RoleUtilisateurLabel on RoleUtilisateur {
  String get label {
    switch (this) {
      case RoleUtilisateur.superAdmin:
        return 'Super Administrateur';
      case RoleUtilisateur.directeur:
        return 'Directeur / Préfet';
      case RoleUtilisateur.enseignant:
        return 'Enseignant';
      case RoleUtilisateur.eleve:
        return 'Élève';
      case RoleUtilisateur.parent:
        return 'Parent / Tuteur';
    }
  }

  String get labelCourt {
    switch (this) {
      case RoleUtilisateur.superAdmin:
        return 'Super Admin';
      case RoleUtilisateur.directeur:
        return 'Directeur';
      case RoleUtilisateur.enseignant:
        return 'Enseignant';
      case RoleUtilisateur.eleve:
        return 'Élève';
      case RoleUtilisateur.parent:
        return 'Parent';
    }
  }

  /// Rôle dans la base (pour Firestore)
  String get firestoreValue {
    return name;
  }
}

class ProfilUtilisateur {
  final String prenom;
  final String nom;
  final String telephone;
  final String adresse;
  final String photoProfil;
  final String? genre; // 'M' ou 'F'
  final DateTime? dateNaissance;

  ProfilUtilisateur({
    required this.prenom,
    required this.nom,
    this.telephone = '',
    this.adresse = '',
    this.photoProfil = '',
    this.genre,
    this.dateNaissance,
  });

  String get nomComplet => '$prenom $nom'.trim();

  factory ProfilUtilisateur.fromMap(Map<String, dynamic> map) {
    return ProfilUtilisateur(
      prenom: map['prenom'] ?? '',
      nom: map['nom'] ?? '',
      telephone: map['telephone'] ?? '',
      adresse: map['adresse'] ?? '',
      photoProfil: map['photoProfil'] ?? '',
      genre: map['genre'],
      dateNaissance: map['dateNaissance'] != null
          ? (map['dateNaissance'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'prenom': prenom,
      'nom': nom,
      'telephone': telephone,
      'adresse': adresse,
      'photoProfil': photoProfil,
      'genre': genre,
      'dateNaissance': dateNaissance,
    };
  }
}

class UtilisateurEduTrack {
  final String id;
  final String email;
  final RoleUtilisateur role;
  final ProfilUtilisateur profil;

  /// ID de l'école principale (directeur, enseignant, élève, parent)
  final String? schoolId;

  /// Pour les enseignants : liste des matières qu'ils enseignent
  final List<String> matiereIds;

  /// Pour les enseignants : liste des classes où ils enseignent
  final List<String> classeIds;

  /// Pour les parents : liste des élèves dont ils sont tuteurs
  final List<String> eleveIds;

  /// Pour le Super Admin : toutes les écoles sous sa gestion
  final List<String> ecoleIds;

  final bool estActif;
  final DateTime createdAt;

  UtilisateurEduTrack({
    required this.id,
    required this.email,
    required this.role,
    required this.profil,
    this.schoolId,
    this.matiereIds = const [],
    this.classeIds = const [],
    this.eleveIds = const [],
    this.ecoleIds = const [],
    this.estActif = true,
    required this.createdAt,
  });

  factory UtilisateurEduTrack.fromMap(Map<String, dynamic> map, String docId) {
    return UtilisateurEduTrack(
      id: docId,
      email: map['email'] ?? '',
      role: RoleUtilisateur.values.firstWhere(
        (e) => e.name == (map['role'] as String? ?? 'eleve'),
        orElse: () => RoleUtilisateur.eleve,
      ),
      profil: ProfilUtilisateur.fromMap(
          map['profil'] as Map<String, dynamic>? ?? {}),
      schoolId: map['schoolId'],
      matiereIds: List<String>.from(map['matiereIds'] ?? []),
      classeIds: List<String>.from(map['classeIds'] ?? []),
      eleveIds: List<String>.from(map['eleveIds'] ?? []),
      ecoleIds: List<String>.from(map['ecoleIds'] ?? []),
      estActif: map['estActif'] as bool? ?? true,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role.name,
      'profil': profil.toMap(),
      'schoolId': schoolId,
      'matiereIds': matiereIds,
      'classeIds': classeIds,
      'eleveIds': eleveIds,
      'ecoleIds': ecoleIds,
      'estActif': estActif,
      'createdAt': createdAt,
    };
  }
}
