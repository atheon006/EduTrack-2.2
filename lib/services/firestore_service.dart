import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/ecole_rdc_model.dart';
import '../models/classe_rdc_model.dart';
import '../models/utilisateur_model.dart';
import '../models/invitation_model.dart';

/// Email unique du Super Administrateur
const String kSuperAdminEmail = 'readykalonda38@gmail.com';

/// Service Firestore central adapté au système EduTrack RDC
/// Gère : Super Admin (readykalonda38@gmail.com), Directeurs (par liens d'invitation), Enseignants, Élèves, Parents (avec ID élève)
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
  // AUTHENTIFICATION SÉCURISÉE
  // ══════════════════════════════════════════════════

  Future<UserCredential> seConnecter(String email, String motDePasse, String roleSouhaite) async {
    final emailClean = email.trim().toLowerCase();

    // Verrouillage Super Admin
    if (roleSouhaite == 'super_admin' || roleSouhaite == 'superAdmin') {
      if (emailClean != kSuperAdminEmail.toLowerCase()) {
        throw Exception('Accès refusé : Seul l\'administrateur principal autorisé peut se connecter comme Super Administrateur.');
      }
    }

    return await _auth.signInWithEmailAndPassword(
      email: emailClean,
      password: motDePasse.trim(),
    );
  }

  /// Connexion avec Google Auth (Seule méthode d'authentification recommandée)
  /// Reconnaît automatiquement l'adresse du Super Admin principal
  Future<UserCredential> connnecterAvecGoogle({String? roleSouhaite}) async {
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithPopup(googleProvider);
    } catch (e) {
      userCredential = await _auth.signInWithProvider(googleProvider);
    }

    final user = userCredential.user;
    if (user != null) {
      final emailClean = user.email?.toLowerCase().trim() ?? '';

      // Auto-reconnaissance du Super Admin
      if (emailClean == kSuperAdminEmail.toLowerCase()) {
        final displayName = user.displayName ?? 'Super Admin';
        final utilisateurAdmin = UtilisateurEduTrack(
          id: user.uid,
          email: emailClean,
          role: RoleUtilisateur.superAdmin,
          profil: ProfilUtilisateur(
            prenom: displayName.split(' ').first,
            nom: displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : 'Admin',
          ),
          estActif: true,
          createdAt: DateTime.now(),
        );
        await sauvegarderUtilisateur(utilisateurAdmin);
      } else {
        // Pour les autres utilisateurs
        final doc = await _db.collection('utilisateurs').doc(user.uid).get();
        if (!doc.exists) {
          final displayName = user.displayName ?? emailClean.split('@').first;
          final nouveau = UtilisateurEduTrack(
            id: user.uid,
            email: emailClean,
            role: RoleUtilisateur.parent,
            profil: ProfilUtilisateur(
              prenom: displayName.split(' ').first,
              nom: displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : '',
            ),
            estActif: true,
            createdAt: DateTime.now(),
          );
          await sauvegarderUtilisateur(nouveau);
        }
      }
    }
    return userCredential;
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
  // LIENS D'INVITATION UNIQUE DIRECTEUR / PRÉFET
  // ══════════════════════════════════════════════════

  /// Génère un lien unique d'invitation crypté à usage unique pour un Directeur
  Future<String> genererLienInvitationDirecteur({
    required String ecoleId,
    required String ecoleNom,
    required String emailDirecteur,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final rawString = '$ecoleId-$emailDirecteur-$timestamp-edutrack-secret-key';
    final token = sha256.convert(utf8.encode(rawString)).toString();

    final invitation = InvitationDirecteur(
      id: '',
      ecoleId: ecoleId,
      ecoleNom: ecoleNom,
      emailDirecteur: emailDirecteur.trim().toLowerCase(),
      token: token,
      estUtilise: false,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    await _db.collection('invitations').add(invitation.toMap());

    // Génère l'URL complète d'invitation
    return 'https://copa-ecole.web.app/#/invite?token=$token';
  }

  /// Récupère une invitation par son token
  Future<InvitationDirecteur?> getInvitationParToken(String token) async {
    final snap = await _db
        .collection('invitations')
        .where('token', isEqualTo: token)
        .where('estUtilise', isEqualTo: false)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final inv = InvitationDirecteur.fromMap(snap.docs.first.data(), snap.docs.first.id);
    if (!inv.estValide) return null;
    return inv;
  }

  /// Active le compte d'un Directeur via son token unique et détruit le token
  Future<UtilisateurEduTrack> consommerInvitationDirecteur({
    required String token,
    required String motDePasse,
    required String prenom,
    required String nom,
  }) async {
    final inv = await getInvitationParToken(token);
    if (inv == null) {
      throw Exception('Lien d\'invitation invalide, expiré ou déjà utilisé.');
    }

    // 1. Création compte Firebase Auth
    final creds = await _auth.createUserWithEmailAndPassword(
      email: inv.emailDirecteur,
      password: motDePasse,
    );
    final uid = creds.user!.uid;

    final utilisateur = UtilisateurEduTrack(
      id: uid,
      email: inv.emailDirecteur,
      role: RoleUtilisateur.directeur,
      profil: ProfilUtilisateur(prenom: prenom, nom: nom),
      schoolId: inv.ecoleId,
      createdAt: DateTime.now(),
    );

    final batch = _db.batch();

    // 2. Sauvegarde du profil directeur
    batch.set(_db.collection('utilisateurs').doc(uid), utilisateur.toMap());

    // 3. Mise à jour de l'école
    batch.update(_db.collection('ecoles').doc(inv.ecoleId), {
      'directeurId': uid,
      'directeurNom': '$prenom $nom'.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 4. Marquer le token comme définitivement consommé/utilisé (ou suppression)
    batch.update(_db.collection('invitations').doc(inv.id), {
      'estUtilise': true,
      'utiliseLe': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return utilisateur;
  }

  // ══════════════════════════════════════════════════
  // INSCRIPTION PUBLIQUE DES PARENTS (AVEC CODE ÉLÈVE)
  // ══════════════════════════════════════════════════

  /// Inscription d'un parent réservée sur l'application publique avec liaison ID élève
  Future<UserCredential> inscrireParent({
    required String email,
    required String motDePasse,
    required String prenom,
    required String nom,
    required String codeEleve,
  }) async {
    final emailClean = email.trim().toLowerCase();

    // 1. Inscription Firebase Auth
    final creds = await _auth.createUserWithEmailAndPassword(
      email: emailClean,
      password: motDePasse,
    );
    final uid = creds.user!.uid;

    final parent = UtilisateurEduTrack(
      id: uid,
      email: emailClean,
      role: RoleUtilisateur.parent,
      profil: ProfilUtilisateur(prenom: prenom, nom: nom),
      eleveIds: [codeEleve.trim()],
      createdAt: DateTime.now(),
    );

    await _db.collection('utilisateurs').doc(uid).set(parent.toMap());
    return creds;
  }

  // ══════════════════════════════════════════════════
  // SUPER ADMIN — GESTION DES ÉCOLES
  // ══════════════════════════════════════════════════

  Future<String> creerEcole(EcoleRDC ecole) async {
    final data = ecole.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    final ref = await _db.collection('ecoles').add(data);
    return ref.id;
  }

  Stream<List<EcoleRDC>> streamToutesLesEcoles() {
    return _db
        .collection('ecoles')
        .orderBy('nom')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => EcoleRDC.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> nommerDirecteur({
    required String ecoleId,
    required String userId,
    required String nomDirecteur,
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection('ecoles').doc(ecoleId), {
      'directeurId': userId,
      'directeurNom': nomDirecteur,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('utilisateurs').doc(userId), {
      'role': RoleUtilisateur.directeur.name,
      'schoolId': ecoleId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> mettreAJourEcole(String ecoleId, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('ecoles').doc(ecoleId).update(data);
  }

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
  // GESTION DES CLASSES
  // ══════════════════════════════════════════════════

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

  // ══════════════════════════════════════════════════
  // RECHERCHE UTILISATEURS
  // ══════════════════════════════════════════════════

  Future<List<UtilisateurEduTrack>> rechercherUtilisateurs(String email) async {
    final snap = await _db
        .collection('utilisateurs')
        .where('email', isGreaterThanOrEqualTo: email.trim().toLowerCase())
        .where('email', isLessThanOrEqualTo: '${email.trim().toLowerCase()}\uf8ff')
        .limit(10)
        .get();
    return snap.docs
        .map((doc) => UtilisateurEduTrack.fromMap(doc.data(), doc.id))
        .toList();
  }
}
