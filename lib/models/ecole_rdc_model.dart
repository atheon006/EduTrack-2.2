import 'classe_rdc_model.dart';

/// Modèle d'École adapté au contexte de la RDC
/// Supporte la gestion multi-écoles par le Super Administrateur

enum TypeEcole { public, prive, congregationnel }

extension TypeEcoleLabel on TypeEcole {
  String get label {
    switch (this) {
      case TypeEcole.public:
        return 'École Publique';
      case TypeEcole.prive:
        return 'École Privée';
      case TypeEcole.congregationnel:
        return 'École de Congrégation';
    }
  }
}

/// Provinces de la République Démocratique du Congo
enum ProvinceRDC {
  kinshasa,
  kasaiCentral,
  kasaiOriental,
  kasai,
  lomami,
  sankuru,
  maniBema,
  tanganika,
  hautLomami,
  hautKatanga,
  lualaba,
  kwango,
  kwilu,
  maiNdombe,
  nordUbangi,
  sudUbangi,
  equateur,
  mongala,
  tshuapa,
  tshopo,
  ituri,
  hautUele,
  basUele,
  nordKivu,
  sudKivu,
  maniema,
  basKongo,
}

extension ProvinceRDCLabel on ProvinceRDC {
  String get label {
    switch (this) {
      case ProvinceRDC.kinshasa:
        return 'Kinshasa';
      case ProvinceRDC.kasaiCentral:
        return 'Kasaï Central';
      case ProvinceRDC.kasaiOriental:
        return 'Kasaï Oriental';
      case ProvinceRDC.kasai:
        return 'Kasaï';
      case ProvinceRDC.lomami:
        return 'Lomami';
      case ProvinceRDC.sankuru:
        return 'Sankuru';
      case ProvinceRDC.maniBema:
        return 'Maniema';
      case ProvinceRDC.tanganika:
        return 'Tanganyika';
      case ProvinceRDC.hautLomami:
        return 'Haut-Lomami';
      case ProvinceRDC.hautKatanga:
        return 'Haut-Katanga';
      case ProvinceRDC.lualaba:
        return 'Lualaba';
      case ProvinceRDC.kwango:
        return 'Kwango';
      case ProvinceRDC.kwilu:
        return 'Kwilu';
      case ProvinceRDC.maiNdombe:
        return 'Maï-Ndombe';
      case ProvinceRDC.nordUbangi:
        return 'Nord-Ubangi';
      case ProvinceRDC.sudUbangi:
        return 'Sud-Ubangi';
      case ProvinceRDC.equateur:
        return 'Équateur';
      case ProvinceRDC.mongala:
        return 'Mongala';
      case ProvinceRDC.tshuapa:
        return 'Tshuapa';
      case ProvinceRDC.tshopo:
        return 'Tshopo';
      case ProvinceRDC.ituri:
        return 'Ituri';
      case ProvinceRDC.hautUele:
        return 'Haut-Uélé';
      case ProvinceRDC.basUele:
        return 'Bas-Uélé';
      case ProvinceRDC.nordKivu:
        return 'Nord-Kivu';
      case ProvinceRDC.sudKivu:
        return 'Sud-Kivu';
      case ProvinceRDC.maniema:
        return 'Maniema';
      case ProvinceRDC.basKongo:
        return 'Bas-Congo';
    }
  }
}

class EcoleRDC {
  final String id;
  final String nom;
  final String adresse;
  final String ville;
  final ProvinceRDC province;
  final TypeEcole typeEcole;
  final String emailContact;
  final String telephoneContact;
  final String logo;

  /// directeurId = aussi l'admin scolaire de cette école
  final String? directeurId;
  final String? directeurNom;

  /// Cycles disponibles dans cette école
  final List<CycleEnseignement> cyclesDisponibles;

  /// ID du Super Admin créateur
  final String creePar;

  final String anneeAcademique; // "2024-2025"
  final bool estActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EcoleRDC({
    required this.id,
    required this.nom,
    required this.adresse,
    required this.ville,
    required this.province,
    required this.typeEcole,
    required this.emailContact,
    required this.telephoneContact,
    this.logo = '',
    this.directeurId,
    this.directeurNom,
    required this.cyclesDisponibles,
    required this.creePar,
    required this.anneeAcademique,
    this.estActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EcoleRDC.fromMap(Map<String, dynamic> map, String docId) {
    return EcoleRDC(
      id: docId,
      nom: map['nom'] ?? '',
      adresse: map['adresse'] ?? '',
      ville: map['ville'] ?? '',
      province: ProvinceRDC.values.firstWhere(
        (e) => e.name == (map['province'] as String? ?? 'kinshasa'),
        orElse: () => ProvinceRDC.kinshasa,
      ),
      typeEcole: TypeEcole.values.firstWhere(
        (e) => e.name == (map['typeEcole'] as String? ?? 'prive'),
        orElse: () => TypeEcole.prive,
      ),
      emailContact: map['emailContact'] ?? '',
      telephoneContact: map['telephoneContact'] ?? '',
      logo: map['logo'] ?? '',
      directeurId: map['directeurId'],
      directeurNom: map['directeurNom'],
      cyclesDisponibles: (map['cyclesDisponibles'] as List<dynamic>? ?? ['primaire', 'secondaire'])
          .map((c) => CycleEnseignement.values.firstWhere(
                (e) => e.name == c.toString(),
                orElse: () => CycleEnseignement.primaire,
              ))
          .toList(),
      creePar: map['creePar'] ?? '',
      anneeAcademique: map['anneeAcademique'] ?? '2024-2025',
      estActive: map['estActive'] as bool? ?? true,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': nom,
      'adresse': adresse,
      'ville': ville,
      'province': province.name,
      'typeEcole': typeEcole.name,
      'emailContact': emailContact,
      'telephoneContact': telephoneContact,
      'logo': logo,
      'directeurId': directeurId,
      'directeurNom': directeurNom,
      'cyclesDisponibles': cyclesDisponibles.map((c) => c.name).toList(),
      'creePar': creePar,
      'anneeAcademique': anneeAcademique,
      'estActive': estActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
