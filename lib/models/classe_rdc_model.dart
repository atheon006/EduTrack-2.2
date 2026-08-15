/// Modèles de données adaptés au système scolaire de la RDC
/// Cycles : Primaire (1ère-6ème) et Secondaire (1ère-4ème humanités)

enum CycleEnseignement { primaire, secondaire }

enum SectionSecondaire {
  generale,
  scientifique,
  litteraire,
  commerciale,
  pedagogique,
  technique,
}

enum TypeEnseignement { public, prive, congregationnel }

/// Extension pour l'affichage en français
extension CycleEnseignementLabel on CycleEnseignement {
  String get label {
    switch (this) {
      case CycleEnseignement.primaire:
        return 'Primaire';
      case CycleEnseignement.secondaire:
        return 'Secondaire';
    }
  }

  /// Niveaux/années disponibles pour ce cycle
  List<String> get niveaux {
    switch (this) {
      case CycleEnseignement.primaire:
        return ['1ère', '2ème', '3ème', '4ème', '5ème', '6ème'];
      case CycleEnseignement.secondaire:
        return ['1ère', '2ème', '3ème', '4ème'];
    }
  }
}

extension SectionSecondaireLabel on SectionSecondaire {
  String get label {
    switch (this) {
      case SectionSecondaire.generale:
        return 'Générale';
      case SectionSecondaire.scientifique:
        return 'Scientifique';
      case SectionSecondaire.litteraire:
        return 'Littéraire';
      case SectionSecondaire.commerciale:
        return 'Commerciale & Gestion';
      case SectionSecondaire.pedagogique:
        return 'Pédagogique';
      case SectionSecondaire.technique:
        return 'Technique';
    }
  }

  String get abreviation {
    switch (this) {
      case SectionSecondaire.generale:
        return 'Gén';
      case SectionSecondaire.scientifique:
        return 'Sc';
      case SectionSecondaire.litteraire:
        return 'Lit';
      case SectionSecondaire.commerciale:
        return 'CG';
      case SectionSecondaire.pedagogique:
        return 'Péd';
      case SectionSecondaire.technique:
        return 'Tech';
    }
  }
}

/// Attribution d'une matière à un enseignant dans une classe
class AttributionMatiere {
  final String matiereId;
  final String matiereNom;
  final String enseignantId;
  final String enseignantNom;
  final int heuresParSemaine;
  final int coefficient;

  AttributionMatiere({
    required this.matiereId,
    required this.matiereNom,
    required this.enseignantId,
    required this.enseignantNom,
    required this.heuresParSemaine,
    required this.coefficient,
  });

  factory AttributionMatiere.fromMap(Map<String, dynamic> map) {
    return AttributionMatiere(
      matiereId: map['matiereId'] ?? '',
      matiereNom: map['matiereNom'] ?? '',
      enseignantId: map['enseignantId'] ?? '',
      enseignantNom: map['enseignantNom'] ?? '',
      heuresParSemaine: (map['heuresParSemaine'] as num?)?.toInt() ?? 2,
      coefficient: (map['coefficient'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matiereId': matiereId,
      'matiereNom': matiereNom,
      'enseignantId': enseignantId,
      'enseignantNom': enseignantNom,
      'heuresParSemaine': heuresParSemaine,
      'coefficient': coefficient,
    };
  }
}

/// Modèle principal d'une Classe adaptée à la RDC
class ClasseRDC {
  final String id;
  final String schoolId;
  final String nom; // Nom affiché ex: "4ème Sc-A"
  final String niveau; // "1ère", "2ème", etc.
  final CycleEnseignement cycle;
  final SectionSecondaire? section; // null pour le primaire
  final String? sousTitre; // ex: "A", "B" pour différencier deux classes du même niveau
  final List<String> eleveIds;
  final List<AttributionMatiere> attributions; // Multi-enseignants pour le secondaire
  final String? titulaireid; // Maître/maîtresse principal (surtout pour le primaire)
  final int capaciteMax;
  final String anneeAcademique; // ex: "2024-2025"
  final DateTime createdAt;
  final DateTime updatedAt;

  ClasseRDC({
    required this.id,
    required this.schoolId,
    required this.nom,
    required this.niveau,
    required this.cycle,
    this.section,
    this.sousTitre,
    required this.eleveIds,
    required this.attributions,
    this.titulaireid,
    this.capaciteMax = 40,
    required this.anneeAcademique,
    required this.createdAt,
    required this.updatedAt,
  });

  int get nombreEleves => eleveIds.length;

  /// Génère le nom complet de la classe
  static String genererNom({
    required String niveau,
    required CycleEnseignement cycle,
    SectionSecondaire? section,
    String? sousTitre,
  }) {
    if (cycle == CycleEnseignement.primaire) {
      return sousTitre != null ? '$niveau Prim-$sousTitre' : '$niveau Primaire';
    } else {
      final sec = section?.abreviation ?? 'Gén';
      return sousTitre != null ? '$niveau $sec-$sousTitre' : '$niveau $sec';
    }
  }

  factory ClasseRDC.fromMap(Map<String, dynamic> map, String docId) {
    return ClasseRDC(
      id: docId,
      schoolId: map['schoolId'] ?? '',
      nom: map['nom'] ?? '',
      niveau: map['niveau'] ?? '1ère',
      cycle: CycleEnseignement.values.firstWhere(
        (e) => e.name == (map['cycle'] as String? ?? 'primaire'),
        orElse: () => CycleEnseignement.primaire,
      ),
      section: map['section'] != null
          ? SectionSecondaire.values.firstWhere(
              (e) => e.name == map['section'],
              orElse: () => SectionSecondaire.generale,
            )
          : null,
      sousTitre: map['sousTitre'],
      eleveIds: List<String>.from(map['eleveIds'] ?? []),
      attributions: (map['attributions'] as List<dynamic>? ?? [])
          .map((a) => AttributionMatiere.fromMap(a as Map<String, dynamic>))
          .toList(),
      titulaireid: map['titulaireId'],
      capaciteMax: (map['capaciteMax'] as num?)?.toInt() ?? 40,
      anneeAcademique: map['anneeAcademique'] ?? '2024-2025',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'schoolId': schoolId,
      'nom': nom,
      'niveau': niveau,
      'cycle': cycle.name,
      'section': section?.name,
      'sousTitre': sousTitre,
      'eleveIds': eleveIds,
      'attributions': attributions.map((a) => a.toMap()).toList(),
      'titulaireId': titulaireid,
      'capaciteMax': capaciteMax,
      'anneeAcademique': anneeAcademique,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

/// Modèle d'emploi du temps (hérite et complète l'ancien Schedule)
class PeriodeCours {
  final String matiereId;
  final String matiereNom;
  final String enseignantId;
  final String heureDebut; // "08:00"
  final String heureFin;   // "09:00"

  PeriodeCours({
    required this.matiereId,
    required this.matiereNom,
    required this.enseignantId,
    required this.heureDebut,
    required this.heureFin,
  });

  factory PeriodeCours.fromMap(Map<String, dynamic> map) {
    return PeriodeCours(
      matiereId: map['matiereId'] ?? '',
      matiereNom: map['matiereNom'] ?? '',
      enseignantId: map['enseignantId'] ?? '',
      heureDebut: map['heureDebut'] ?? '08:00',
      heureFin: map['heureFin'] ?? '09:00',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matiereId': matiereId,
      'matiereNom': matiereNom,
      'enseignantId': enseignantId,
      'heureDebut': heureDebut,
      'heureFin': heureFin,
    };
  }
}
