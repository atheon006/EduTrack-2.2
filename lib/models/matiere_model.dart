/// Matières scolaires du système éducatif de la RDC
/// Organisées par cycle et avec coefficients standards

enum CycleMatiere { primaire, secondaire, tousLesNiveaux }

class Matiere {
  final String id;
  final String nom;
  final String code;
  final CycleMatiere cycle;
  final int coefficientParDefaut;
  final String? schoolId; // null = matière commune à toutes les écoles

  Matiere({
    required this.id,
    required this.nom,
    required this.code,
    required this.cycle,
    this.coefficientParDefaut = 2,
    this.schoolId,
  });

  factory Matiere.fromMap(Map<String, dynamic> map, String docId) {
    return Matiere(
      id: docId,
      nom: map['nom'] ?? '',
      code: map['code'] ?? '',
      cycle: CycleMatiere.values.firstWhere(
        (e) => e.name == (map['cycle'] as String? ?? 'tousLesNiveaux'),
        orElse: () => CycleMatiere.tousLesNiveaux,
      ),
      coefficientParDefaut: (map['coefficientParDefaut'] as num?)?.toInt() ?? 2,
      schoolId: map['schoolId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'code': code,
      'cycle': cycle.name,
      'coefficientParDefaut': coefficientParDefaut,
      'schoolId': schoolId,
    };
  }
}

/// Matières pré-définies pour le système RDC
class MatieresRDC {
  /// Matières du cycle Primaire
  static final List<Map<String, dynamic>> primaire = [
    {'nom': 'Français', 'code': 'FR', 'coefficient': 4},
    {'nom': 'Mathématiques', 'code': 'MATH', 'coefficient': 4},
    {'nom': 'Éveil scientifique', 'code': 'EVS', 'coefficient': 2},
    {'nom': 'Histoire & Géographie', 'code': 'HG', 'coefficient': 2},
    {'nom': 'Éducation civique & morale', 'code': 'ECM', 'coefficient': 1},
    {'nom': 'Religion / Morale', 'code': 'REL', 'coefficient': 1},
    {'nom': 'Dessin & Travaux manuels', 'code': 'DTM', 'coefficient': 1},
    {'nom': 'Éducation physique', 'code': 'EPS', 'coefficient': 1},
    {'nom': 'Musique', 'code': 'MUS', 'coefficient': 1},
    {'nom': 'Langue nationale (Lingala/Swahili/Kikongo/Tshiluba)', 'code': 'LN', 'coefficient': 2},
  ];

  /// Matières du cycle Secondaire — Tronc commun
  static final List<Map<String, dynamic>> secondaireTroncCommun = [
    {'nom': 'Français', 'code': 'FR', 'coefficient': 4},
    {'nom': 'Mathématiques', 'code': 'MATH', 'coefficient': 4},
    {'nom': 'Histoire', 'code': 'HIST', 'coefficient': 2},
    {'nom': 'Géographie', 'code': 'GEO', 'coefficient': 2},
    {'nom': 'Éducation civique', 'code': 'EC', 'coefficient': 1},
    {'nom': 'Religion / Morale', 'code': 'REL', 'coefficient': 1},
    {'nom': 'Éducation physique', 'code': 'EPS', 'coefficient': 1},
    {'nom': 'Anglais', 'code': 'ANG', 'coefficient': 2},
    {'nom': 'Informatique', 'code': 'INFO', 'coefficient': 2},
    {'nom': 'Langue nationale', 'code': 'LN', 'coefficient': 1},
  ];

  /// Matières supplémentaires section Scientifique
  static final List<Map<String, dynamic>> sectionScientifique = [
    {'nom': 'Physique', 'code': 'PHY', 'coefficient': 4},
    {'nom': 'Chimie', 'code': 'CHIM', 'coefficient': 4},
    {'nom': 'Biologie', 'code': 'BIO', 'coefficient': 3},
    {'nom': 'Sciences naturelles', 'code': 'SN', 'coefficient': 2},
    {'nom': 'Mathématiques avancées', 'code': 'MATHA', 'coefficient': 5},
  ];

  /// Matières supplémentaires section Littéraire
  static final List<Map<String, dynamic>> sectionLitteraire = [
    {'nom': 'Littérature française', 'code': 'LITFR', 'coefficient': 3},
    {'nom': 'Latin', 'code': 'LAT', 'coefficient': 2},
    {'nom': 'Philosophie', 'code': 'PHILO', 'coefficient': 3},
    {'nom': 'Langues modernes', 'code': 'LM', 'coefficient': 2},
  ];

  /// Matières supplémentaires section Commerciale & Gestion
  static final List<Map<String, dynamic>> sectionCommerciale = [
    {'nom': 'Comptabilité', 'code': 'COMPTA', 'coefficient': 4},
    {'nom': 'Économie', 'code': 'ECO', 'coefficient': 3},
    {'nom': 'Droit commercial', 'code': 'DC', 'coefficient': 2},
    {'nom': 'Gestion des entreprises', 'code': 'GE', 'coefficient': 3},
    {'nom': 'Secrétariat', 'code': 'SEC', 'coefficient': 2},
  ];

  /// Matières supplémentaires section Pédagogique
  static final List<Map<String, dynamic>> sectionPedagogique = [
    {'nom': 'Psychologie', 'code': 'PSY', 'coefficient': 3},
    {'nom': 'Pédagogie générale', 'code': 'PED', 'coefficient': 3},
    {'nom': 'Didactique', 'code': 'DID', 'coefficient': 2},
    {'nom': 'Pratique professionnelle', 'code': 'PP', 'coefficient': 3},
  ];
}
