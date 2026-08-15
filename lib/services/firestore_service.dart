import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/ecole_rdc_model.dart';
import '../models/classe_rdc_model.dart';
import '../models/utilisateur_model.dart';
import '../models/invitation_model.dart';

/// Email unique du Super Administrateur
const String kSuperAdminEmail = 'readykalonda38@gmail.com';

/// Service Firestore central adapté au système EduTrack RDC
/// Gère : Super Admin (readykalonda38@gmail.com), Directeurs, Enseignants, Élèves, Parents
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
  // AUTHENTIFICATION SÉCURISÉE GOOGLE + EMAIL
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

  /// Connexion multiplateforme avec Google Auth (Web + Mobile App)
  /// Reconnaît automatiquement l'adresse du Super Admin principal
  Future<UserCredential> connnecterAvecGoogle({String? roleSouhaite}) async {
    UserCredential userCredential;
    final googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');

    // Web OAuth 2.0 Client ID (copa-ecole) — requis pour signInWithPopup sur Flutter Web
    if (kIsWeb) {
      googleProvider.setCustomParameters({
        'client_id': '786691292552-neuda6294ea8a6af9dm8tk7k6da5enlo.apps.googleusercontent.com',
      });
    }

    try {
      if (kIsWeb) {
        try {
          userCredential = await _auth.signInWithPopup(googleProvider);
        } catch (e) {
          // Si les fenêtres surgissantes sont bloquées par le navigateur, utiliser la redirection
          await _auth.signInWithRedirect(googleProvider);
          throw Exception('Redirection vers la connexion Google en cours...');
        }
      } else {
        // Application Mobile Native (Android / iOS)
        try {
          final GoogleSignIn googleSignIn = GoogleSignIn();
          final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
          if (googleUser == null) {
            throw Exception('Connexion Google annulée.');
          }
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final OAuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          userCredential = await _auth.signInWithCredential(credential);
        } catch (e) {
          userCredential = await _auth.signInWithProvider(googleProvider);
        }
      }
    } catch (e) {
      rethrow;
    }

    final user = userCredential.user;
    if (user != null) {
      final emailClean = user.email?.toLowerCase().trim() ?? '';
      final photo = user.photoURL ?? '';

      // Auto-reconnaissance du Super Admin (readykalonda38@gmail.com)
      if (emailClean == kSuperAdminEmail.toLowerCase()) {
        final displayName = user.displayName ?? 'Super Admin';
        final utilisateurAdmin = UtilisateurEduTrack(
          id: user.uid,
          email: emailClean,
          role: RoleUtilisateur.superAdmin,
          profil: ProfilUtilisateur(
            prenom: displayName.split(' ').first,
            nom: displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : 'Admin',
            photoProfil: photo,
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
              photoProfil: photo,
            ),
            estActif: true,
            createdAt: DateTime.now(),
          );
          await sauvegarderUtilisateur(nouveau);
        } else if (photo.isNotEmpty) {
          // Mettre à jour la photo de profil si elle est disponible
          await _db.collection('utilisateurs').doc(user.uid).set({
            'profil': {'photoProfil': photo}
          }, SetOptions(merge: true));
        }
      }
    }
    return userCredential;
  }

  Future<void> seDeconnecter() async {
    await _auth.signOut();
  }

  // ══════════════════════════════════════════════════
  // PROFIL UTILISATEUR & UPLOAD PHOTO
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

  /// Mise à jour de la photo de profil de l'utilisateur (URL ou base64)
  Future<void> mettreAJourPhotoProfil(String userId, String photoUrl) async {
    await _db.collection('utilisateurs').doc(userId).set({
      'profil': {'photoProfil': photoUrl}
    }, SetOptions(merge: true));
  }

  // ══════════════════════════════════════════════════
  // LIENS D'INVITATION UNIQUE DIRECTEUR / PRÉFET
  // ══════════════════════════════════════════════════

  Future<String> genererLienInvitationDirecteur({
    required String ecoleId,
    required String ecoleNom,
    required String emailDirecteur,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final rawString = '$ecoleId-$emailDirecteur-$timestamp-edutrack-secret-key';
    final token = sha256.convert(utf8.encode(rawString)).toString();

    final invitation = InvitationPersonnel(
      id: '',
      ecoleId: ecoleId,
      ecoleNom: ecoleNom,
      emailPersonnel: emailDirecteur.trim().toLowerCase(),
      token: token,
      typeRole: 'directeur',
      nomRole: 'Directeur',
      estUtilise: false,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    await _db.collection('invitations_personnel').add(invitation.toMap());
    return 'https://copa-ecole.web.app/invite/$token';
  }

  Future<String> genererLienInvitationEnseignant({
    required String ecoleId,
    required String ecoleNom,
    required String emailEnseignant,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final rawString = '$ecoleId-$emailEnseignant-$timestamp-edutrack-teacher-key';
    final token = sha256.convert(utf8.encode(rawString)).toString();

    final invitation = InvitationPersonnel(
      id: '',
      ecoleId: ecoleId,
      ecoleNom: ecoleNom,
      emailPersonnel: emailEnseignant.trim().toLowerCase(),
      token: token,
      typeRole: 'enseignant',
      nomRole: 'Enseignant',
      estUtilise: false,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );

    await _db.collection('invitations_personnel').add(invitation.toMap());
    return 'https://copa-ecole.web.app/invite/$token';
  }

  Future<InvitationPersonnel?> getInvitationPersonnelParToken(String token) async {
    // 1. Chercher d'abord dans invitations_personnel
    final snap = await _db
        .collection('invitations_personnel')
        .where('token', isEqualTo: token)
        .limit(1)
        .get();

    if (snap.docs.isNotEmpty) {
      final doc = snap.docs.first;
      final inv = InvitationPersonnel.fromMap(doc.data(), doc.id);
      if (!inv.estUtilise && !inv.estExpire) return inv;
      return null;
    }

    // 2. Fallback rétrocompatible dans invitations_directeurs
    final snapDir = await _db
        .collection('invitations_directeurs')
        .where('token', isEqualTo: token)
        .limit(1)
        .get();

    if (snapDir.docs.isNotEmpty) {
      final doc = snapDir.docs.first;
      final invDir = InvitationDirecteur.fromMap(doc.data(), doc.id);
      if (!invDir.estUtilise && !invDir.estExpire) {
        return InvitationPersonnel(
          id: invDir.id,
          ecoleId: invDir.ecoleId,
          ecoleNom: invDir.ecoleNom,
          emailPersonnel: invDir.emailDirecteur,
          token: invDir.token,
          typeRole: 'directeur',
          nomRole: 'Directeur',
          estUtilise: invDir.estUtilise,
          createdAt: invDir.createdAt,
          expiresAt: invDir.expiresAt,
        );
      }
    }

    return null;
  }

  Future<InvitationDirecteur?> getInvitationParToken(String token) async {
    final invPers = await getInvitationPersonnelParToken(token);
    if (invPers == null) return null;
    return InvitationDirecteur(
      id: invPers.id,
      ecoleId: invPers.ecoleId,
      ecoleNom: invPers.ecoleNom,
      emailDirecteur: invPers.emailPersonnel,
      token: invPers.token,
      estUtilise: invPers.estUtilise,
      createdAt: invPers.createdAt,
      expiresAt: invPers.expiresAt,
    );
  }

  Future<void> consommerInvitationPersonnel({
    required String token,
    required User user,
  }) async {
    final inv = await getInvitationPersonnelParToken(token);
    if (inv == null) {
      throw Exception('Lien d\'invitation invalide, expiré ou déjà consommé.');
    }

    final role = inv.typeRole == 'enseignant'
        ? RoleUtilisateur.enseignant
        : RoleUtilisateur.directeur;
    final displayName = user.displayName ?? inv.emailPersonnel.split('@').first;

    final utilisateur = UtilisateurEduTrack(
      id: user.uid,
      email: inv.emailPersonnel.isNotEmpty ? inv.emailPersonnel : (user.email ?? ''),
      role: role,
      schoolId: inv.ecoleId,
      profil: ProfilUtilisateur(
        prenom: displayName.split(' ').first,
        nom: displayName.split(' ').length > 1
            ? displayName.split(' ').sublist(1).join(' ')
            : '',
        photoProfil: user.photoURL ?? '',
      ),
      estActif: true,
      createdAt: DateTime.now(),
    );

    await sauvegarderUtilisateur(utilisateur);

    if (role == RoleUtilisateur.directeur) {
      await _db.collection('ecoles_rdc').doc(inv.ecoleId).set({
        'directeurId': user.uid,
        'directeurNom': displayName,
      }, SetOptions(merge: true));
    }

    // Marquer l'invitation comme utilisée dans sa collection d'origine
    await _db.collection('invitations_personnel').doc(inv.id).set({
      'estUtilise': true,
      'utiliseLe': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('invitations_directeurs').doc(inv.id).set({
      'estUtilise': true,
      'utiliseLe': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> consommerInvitationDirecteur({
    required String token,
    required String motDePasse,
    required String prenom,
    required String nom,
  }) async {
    final user = _auth.currentUser;
    if (user != null) {
      await consommerInvitationPersonnel(token: token, user: user);
    }
  }

  // ══════════════════════════════════════════════════
  // PARENTS & INSCRIPTION PAR CODE ÉLÈVE
  // ══════════════════════════════════════════════════

  Future<void> inscrireParent({
    required String email,
    required String motDePasse,
    required String prenom,
    required String nom,
    required String codeEleve,
  }) async {
    UserCredential cred;
    if (_auth.currentUser != null) {
      cred = UserCredentialMock(_auth.currentUser!);
    } else {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: motDePasse,
      );
    }

    final user = cred.user!;

    final eleveSnap = await _db
        .collection('eleves')
        .where('codeEleve', isEqualTo: codeEleve.trim().toUpperCase())
        .limit(1)
        .get();

    String? eleveIdFound;
    if (eleveSnap.docs.isNotEmpty) {
      eleveIdFound = eleveSnap.docs.first.id;
    }

    final parent = UtilisateurEduTrack(
      id: user.uid,
      email: email.trim().toLowerCase(),
      role: RoleUtilisateur.parent,
      profil: ProfilUtilisateur(
        prenom: prenom,
        nom: nom,
        photoProfil: user.photoURL ?? '',
      ),
      eleveIds: eleveIdFound != null ? [eleveIdFound] : [],
      estActif: true,
      createdAt: DateTime.now(),
    );

    await sauvegarderUtilisateur(parent);
  }

  // ══════════════════════════════════════════════════
  // ÉCOLES & INFRASTRUCTURE RDC
  // ══════════════════════════════════════════════════

  Stream<List<EcoleRDC>> streamToutesLesEcoles() {
    return _db.collection('ecoles_rdc').snapshots().map((snap) =>
        snap.docs.map((doc) => EcoleRDC.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> ajouterEcole(EcoleRDC ecole) async {
    await _db.collection('ecoles_rdc').add(ecole.toMap());
  }

  /// Alias used by SuperAdminDashboard
  Future<void> creerEcole(EcoleRDC ecole) => ajouterEcole(ecole);

  Future<void> supprimerEcole(String ecoleId) async {
    await _db.collection('ecoles_rdc').doc(ecoleId).delete();
  }

  // ══════════════════════════════════════════════════
  // STATISTIQUES GLOBALES SUPER ADMIN
  // ══════════════════════════════════════════════════

  Future<Map<String, int>> getStatistiquesGlobales() async {
    final results = await Future.wait([
      _db.collection('ecoles_rdc').count().get(),
      _db.collection('utilisateurs').where('role', isEqualTo: 'parent').count().get(),
      _db.collection('utilisateurs').where('role', isEqualTo: 'enseignant').count().get(),
      _db.collection('eleves').count().get(),
    ]);
    return {
      'ecoles': results[0].count ?? 0,
      'parents': results[1].count ?? 0,
      'enseignants': results[2].count ?? 0,
      'eleves': results[3].count ?? 0,
    };
  }

  // ══════════════════════════════════════════════════
  // GESTION DIRECTEURS
  // ══════════════════════════════════════════════════

  Future<List<UtilisateurEduTrack>> rechercherUtilisateurs(String emailPartiel) async {
    final snap = await _db
        .collection('utilisateurs')
        .where('email', isGreaterThanOrEqualTo: emailPartiel.toLowerCase())
        .where('email', isLessThan: '${emailPartiel.toLowerCase()}z')
        .limit(10)
        .get();
    return snap.docs
        .map((doc) => UtilisateurEduTrack.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> nommerDirecteur({
    required String ecoleId,
    required String userId,
    required String nomDirecteur,
  }) async {
    await Future.wait([
      _db.collection('utilisateurs').doc(userId).set({
        'role': 'directeur',
        'schoolId': ecoleId,
      }, SetOptions(merge: true)),
      _db.collection('ecoles_rdc').doc(ecoleId).set({
        'directeurId': userId,
        'directeurNom': nomDirecteur,
      }, SetOptions(merge: true)),
    ]);
  }

  // ══════════════════════════════════════════════════
  // CLASSES & NIVEAUX
  // ══════════════════════════════════════════════════

  Stream<List<ClasseRDC>> streamClassesParEcole(String ecoleId) {
    return _db
        .collection('classes_rdc')
        .where('ecoleId', isEqualTo: ecoleId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => ClasseRDC.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> ajouterClasse(ClasseRDC classe) async {
    await _db.collection('classes_rdc').add(classe.toMap());
  }
}

class UserCredentialMock implements UserCredential {
  @override
  final User user;
  UserCredentialMock(this.user);

  @override
  AuthCredential? get credential => null;

  @override
  AdditionalUserInfo? get additionalUserInfo => null;
}
