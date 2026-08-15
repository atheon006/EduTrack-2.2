import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ecole_rdc_model.dart';
import '../models/classe_rdc_model.dart';
import '../models/matiere_model.dart';
import '../models/utilisateur_model.dart';

/// Service Firestore central adapté au système EduTrack RDC
/// Gère : Super Admin, Directeurs, Enseignants, Élèves, Parents
class FirestoreServiceRDC {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FirestoreServiceRDC({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ══════════════════════════════════════════════════
  // AUTHENTIFICATION
  // ══════════════════════════════════════════════════

  Future<UserCredential> seConnecter(String email, String motDePasse) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: motDePasse.trim(),
    );
  }

  Future<void> seDeconnecter() async {
    await _auth.signOut();
  }

  // ══════════════════════════════════════════════════
  // PROFIL UTILISATEUR
  // ══════════════════════════════════════════════════

  Future<UtilisateurEduTrack?> getUtilisateur(String userId) async {
    final doc = await _db.collection('utilisateurs').doc(userId).get();
    if (!doc.exists) return null;
    return UtilisateurEduTrack.fromMap(doc.data()!, doc.id);
  }

  Stream<UtilisateurEduTrack?> streamUtilisateur(String userId) {
    return _db.collection('utilisateurs').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UtilisateurEduTrack.fromMap(doc.data()!, doc.id);
    });
  }

  Future<void> sauvegarderUtilisateur(UtilisateurEduTrack utilisateur) async {
    await _db
        .collection('utilisateurs')
        .doc(utilisateur.id)
        .set(utilisateur.toMap(), SetOptions(merge: true));
  }

  // ══════════════════════════════════════════════════
  // SUPER ADMIN — GESTION DES ÉCOLES
  // ══════════════════════════════════════════════════

  /// Créer une nouvelle école
  Future<String> creerEcole(EcoleRDC ecole) async {
    final data = ecole.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _db.collection('ecoles').add(data);
    return ref.id;
  }

  /// Lister toutes les écoles (Super Admin)
  Stream<List<EcoleRDC>> streamToutesLesEcoles() {
    return _db
        .collection('ecoles')
        .orderBy('nom')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => EcoleRDC.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Nommer un directeur (directeur = aussi admin scolaire)
  Future<void> nommerDirecteur({
    required String ecoleId,
    required String userId,
    required String nomDirecteur,
  }) async {
    final batch = _db.batch();

    // Mise à jour de l'école
    batch.update(_db.collection('ecoles').doc(ecoleId), {
      'directeurId': userId,
      'directeurNom': nomDirecteur,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Mise à jour du profil utilisateur
    batch.update(_db.collection('utilisateurs').doc(userId), {
      'role': RoleUtilisateur.directeur.name,
      'schoolId': ecoleId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Mettre à jour les infos d'une école
  Future<void> mettreAJourEcole(String ecoleId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('ecoles').doc(ecoleId).update(data);
  }

  /// Statistiques globales (Super Admin)
  Future<Map<String, int>> getStatistiquesGlobales() async {
    final ecoles = await _db.collection('ecoles').count().get();
    final utilisateurs = await _db.collection('utilisateurs').count().get();
    final eleves = await _db
        .collection('utilisateurs')
        .where('role', isEqualTo: 'eleve')
        .count()
        .get();
    final enseignants = await _db
        .collection('utilisateurs')
        .where('role', isEqualTo: 'enseignant')
        .count()
        .get();

    return {
      'ecoles': ecoles.count ?? 0,
      'utilisateurs': utilisateurs.count ?? 0,
      'eleves': eleves.count ?? 0,
      'enseignants': enseignants.count ?? 0,
    };
  }

  // ══════════════════════════════════════════════════
  // GESTION DES CLASSES (Primaire & Secondaire)
  // ══════════════════════════════════════════════════

  /// Créer une classe
  Future<String> creerClasse(ClasseRDC classe) async {
    final data = classe.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _db
        .collection('ecoles')
        .doc(classe.schoolId)
        .collection('classes')
        .add(data);
    return ref.id;
  }

  /// Stream de toutes les classes d'une école
  Stream<List<ClasseRDC>> streamClassesEcole(String schoolId,
      {CycleEnseignement? cycle}) {
    Query<Map<String, dynamic>> query = _db
        .collection('ecoles')
        .doc(schoolId)
        .collection('classes')
        .orderBy('niveau');

    if (cycle != null) {
      query = query.where('cycle', isEqualTo: cycle.name);
    }

    return query.snapshots().map((snap) =>
        snap.docs.map((doc) => ClasseRDC.fromMap(doc.data(), doc.id)).toList());
  }

  /// Stream des classes d'un enseignant (par ses attributions)
  Stream<List<ClasseRDC>> streamClassesEnseignant(
      String schoolId, String enseignantId) {
    return _db
        .collection('ecoles')
        .doc(schoolId)
        .collection('classes')
        .where('attributions', arrayContains: {'enseignantId': enseignantId})
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ClasseRDC.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Ajouter un enseignant à une classe (attribution matière)
  Future<void> ajouterAttributionMatiere(
      String schoolId, String classeId, AttributionMatiere attribution) async {
    await _db
        .collection('ecoles')
        .doc(schoolId)
        .collection('classes')
        .doc(classeId)
        .update({
      'attributions': FieldValue.arrayUnion([attribution.toMap()]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Mettre à jour une classe
  Future<void> mettreAJourClasse(
      String schoolId, String classeId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db
        .collection('ecoles')
        .doc(schoolId)
        .collection('classes')
        .doc(classeId)
        .update(data);
  }

  // ══════════════════════════════════════════════════
  // NOTES (RÉSULTATS SCOLAIRES)
  // ══════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> streamNotesEleve(String eleveId) {
    return _db
        .collection('notes')
        .where('eleveId', isEqualTo: eleveId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Stream<List<Map<String, dynamic>>> streamNotesClasse(
      String classeId, String matiereId) {
    return _db
        .collection('notes')
        .where('classeId', isEqualTo: classeId)
        .where('matiereId', isEqualTo: matiereId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> enregistrerNote(Map<String, dynamic> noteData) async {
    noteData['createdAt'] = FieldValue.serverTimestamp();
    noteData['updatedAt'] = FieldValue.serverTimestamp();
    if (noteData['id'] != null) {
      final id = noteData.remove('id') as String;
      await _db.collection('notes').doc(id).set(noteData, SetOptions(merge: true));
    } else {
      await _db.collection('notes').add(noteData);
    }
  }

  // ══════════════════════════════════════════════════
  // ABSENCES
  // ══════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> streamAbsencesEleve(String eleveId) {
    return _db
        .collection('absences')
        .where('eleveId', isEqualTo: eleveId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> enregistrerAbsence(Map<String, dynamic> absenceData) async {
    absenceData['timestamp'] = FieldValue.serverTimestamp();
    await _db.collection('absences').add(absenceData);
  }

  // ══════════════════════════════════════════════════
  // ANNONCES
  // ══════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> streamAnnonces(String schoolId) {
    return _db
        .collection('annonces')
        .where('schoolId', isEqualTo: schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> publierAnnonce(Map<String, dynamic> annonceData) async {
    annonceData['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('annonces').add(annonceData);
  }

  // ══════════════════════════════════════════════════
  // RECHERCHE UTILISATEURS (pour nommer un directeur)
  // ══════════════════════════════════════════════════

  Future<List<UtilisateurEduTrack>> rechercherUtilisateurs(String email) async {
    final snap = await _db
        .collection('utilisateurs')
        .where('email', isGreaterThanOrEqualTo: email)
        .where('email', isLessThanOrEqualTo: '$email\uf8ff')
        .limit(10)
        .get();
    return snap.docs
        .map((doc) => UtilisateurEduTrack.fromMap(doc.data(), doc.id))
        .toList();
  }
}
