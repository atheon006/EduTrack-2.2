import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/utilisateur_model.dart';
import '../services/firestore_service.dart';
import '../utils/storage_util.dart';
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';
import 'parent_dashboard.dart';
import 'school_admin_dashboard.dart';
import 'super_admin/super_admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  final String? selectedRole;
  final String schoolName;
  final String schoolToken;

  const LoginScreen({
    super.key,
    this.selectedRole,
    required this.schoolName,
    required this.schoolToken,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirestoreServiceRDC _firestoreService = FirestoreServiceRDC();
  String _selectedRole = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedRole != null) {
      _selectedRole = widget.selectedRole!;
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'super_admin':
      case 'superAdmin':
        return 'Super Administrateur';
      case 'directeur':
        return 'Directeur / Préfet';
      case 'school_admin':
        return 'Administrateur Scolaire';
      case 'teacher':
      case 'enseignant':
        return 'Enseignant';
      case 'student':
      case 'eleve':
        return 'Élève';
      case 'parent':
        return 'Parent / Tuteur';
      default:
        return 'Utilisateur';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'super_admin':
      case 'superAdmin':
        return const Color(0xFF4F46E5);
      case 'directeur':
      case 'school_admin':
        return const Color(0xFF2563EB);
      case 'teacher':
      case 'enseignant':
        return const Color(0xFF0D9488);
      case 'student':
      case 'eleve':
        return const Color(0xFFD97706);
      case 'parent':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF3B82F6);
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'super_admin':
      case 'superAdmin':
        return Icons.security_rounded;
      case 'directeur':
      case 'school_admin':
        return Icons.admin_panel_settings_rounded;
      case 'teacher':
      case 'enseignant':
        return Icons.record_voice_over_rounded;
      case 'student':
      case 'eleve':
        return Icons.menu_book_rounded;
      case 'parent':
        return Icons.family_restroom_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  void _navigateBasedOnRole(String role, User user) {
    if (!mounted) return;

    switch (role) {
      case 'super_admin':
      case 'superAdmin':
        final superAdmin = UtilisateurEduTrack(
          id: user.id,
          email: user.email,
          role: RoleUtilisateur.superAdmin,
          profil: ProfilUtilisateur(
            prenom: user.profile.firstName,
            nom: user.profile.lastName,
          ),
          createdAt: DateTime.now(),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => SuperAdminDashboard(superAdmin: superAdmin),
          ),
          (route) => false,
        );
        break;
      case 'directeur':
      case 'school_admin':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => SchoolAdminDashboard(user: user),
          ),
          (route) => false,
        );
        break;
      case 'teacher':
      case 'enseignant':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TeacherDashboard(user: user),
          ),
          (route) => false,
        );
        break;
      case 'student':
      case 'eleve':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDashboard(user: user),
          ),
          (route) => false,
        );
        break;
      case 'parent':
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ParentDashboard(user: user),
          ),
          (route) => false,
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rôle inconnu: $role')),
        );
    }
  }

  /// Connexion directe via Google Auth
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final userCredential = await _firestoreService.connnecterAvecGoogle(
        roleSouhaite: _selectedRole,
      );
      final fbUser = userCredential.user;

      if (fbUser != null && mounted) {
        final emailClean = fbUser.email?.toLowerCase().trim() ?? '';
        final displayName = fbUser.displayName ?? 'Utilisateur';

        // Auto-reconnaissance du Super Admin (readykalonda38@gmail.com)
        if (emailClean == 'readykalonda38@gmail.com') {
          await StorageUtil.setString('userRole', 'super_admin');
          await StorageUtil.setBool('isLoggedIn', true);

          final superAdmin = UtilisateurEduTrack(
            id: fbUser.uid,
            email: emailClean,
            role: RoleUtilisateur.superAdmin,
            profil: ProfilUtilisateur(
              prenom: displayName.split(' ').first,
              nom: displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : 'Admin',
            ),
            createdAt: DateTime.now(),
          );

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => SuperAdminDashboard(superAdmin: superAdmin),
            ),
            (route) => false,
          );
          return;
        }

        // Pour les autres rôles (Directeur, Enseignant, Parent, Élève)
        final docUtil = await _firestoreService.getUtilisateur(fbUser.uid);
        final roleStr = docUtil?.role.name ?? (_selectedRole.isNotEmpty ? _selectedRole : 'parent');

        await StorageUtil.setString('userRole', roleStr);
        await StorageUtil.setBool('isLoggedIn', true);

        final mockUser = User(
          id: fbUser.uid,
          email: emailClean,
          role: roleStr,
          schoolToken: widget.schoolToken,
          schoolName: widget.schoolName,
          profile: UserProfile(
            firstName: displayName.split(' ').first,
            lastName: displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : '',
            phone: '',
            address: '',
            profilePicture: fbUser.photoURL ?? '',
          ),
        );

        if (!mounted) return;
        _navigateBasedOnRole(roleStr, mockUser);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion Google : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final roleColor = _getRoleColor(_selectedRole);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _selectedRole.isNotEmpty ? _getRoleName(_selectedRole) : 'Authentification Google',
          style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: primaryTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Role Icon Emblem
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getRoleIcon(_selectedRole),
                          size: 48,
                          color: roleColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      _selectedRole.isNotEmpty ? _getRoleName(_selectedRole) : 'Connexion EduTrack',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'Connectez-vous en un clic avec votre compte Google',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Google Sign-In Primary Button
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Icon(Icons.g_mobiledata_rounded, size: 34, color: Colors.white),
                      label: Text(
                        _isLoading ? 'Connexion en cours...' : 'Se connecter avec Google',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: roleColor,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Security Footer Note
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Connexion sécurisée SSL / Firebase Auth',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
