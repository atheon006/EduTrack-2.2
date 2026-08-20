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
        return 'Super Administrator';
      case 'directeur':
      case 'school_admin':
        return 'School Principal';
      case 'teacher':
      case 'enseignant':
        return 'Teacher';
      case 'student':
      case 'eleve':
        return 'Student';
      case 'parent':
        return 'Parent / Guardian';
      default:
        return 'User';
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

  /// Translates technical error codes to clear English messages for the user
  String _traduireErreur(String erreur) {
    if (erreur.contains('popup_closed') || erreur.contains('popup-closed')) {
      return 'Google sign-in window was closed. Please try again.';
    }
    if (erreur.contains('cancelled') || erreur.contains('canceled')) {
      return 'Sign-in cancelled. Try again whenever you want.';
    }
    if (erreur.contains('network') || erreur.contains('Network')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (erreur.contains('permission-denied') || erreur.contains('PERMISSION_DENIED')) {
      return 'Access denied. Your account is not authorized for this action.';
    }
    if (erreur.contains('configuration-not-found')) {
      return 'Configuration issue. Please contact administrator.';
    }
    if (erreur.contains('account-exists')) {
      return 'An account already exists with this email address. Please sign in directly.';
    }
    if (erreur.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    }
    if (erreur.contains('Redirection')) {
      return 'Redirecting to Google Sign-In...';
    }
    return 'An error occurred. Please try again or contact support.';
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
        final message = _traduireErreur(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          _selectedRole.isNotEmpty ? _getRoleName(_selectedRole) : 'Google Authentication',
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
                      _selectedRole.isNotEmpty ? _getRoleName(_selectedRole) : 'EduTrack Sign In',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      'Sign in with a single click using your Google account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Google Sign-In Primary Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleGoogleSignIn,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F1F1F),
                        elevation: 3,
                        shadowColor: Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFDADCE0)),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Color(0xFF4285F4), strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Official Google Logo
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CustomPaint(painter: _GoogleLogoPainter()),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Sign in with Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F1F1F),
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
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
                          'SSL Encrypted / Firebase Auth',
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

/// Peint le vrai logo Google "G" coloré avec les 4 couleurs officielles Google
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Fond blanc circulaire
    paint.color = Colors.white;
    canvas.drawCircle(center, radius, paint);

    // Segments colorés du G Google (4 couleurs officielles Google)
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.5);
    final rect = Rect.fromCircle(center: Offset.zero, radius: size.width * 0.42);

    // Cercle coloré avec découpe centrale pour former le G
    // Rouge (#EA4335) - quart supérieur gauche
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.36, 1.57, true, paint);

    // Jaune (#FBBC05) - quart inférieur gauche
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -0.79, -1.57, true, paint);

    // Vert (#34A853) - quart inférieur droit
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.79, 1.57, true, paint);

    // Bleu (#4285F4) - quart supérieur droit + barre
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -2.36, -1.57, true, paint);

    // Centre blanc pour créer l'anneau
    paint.color = Colors.white;
    canvas.drawCircle(Offset.zero, size.width * 0.22, paint);

    // Barre horizontale du G (bleue)
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -size.height * 0.09, size.width * 0.42, size.height * 0.18),
      Radius.circular(size.height * 0.09),
    );
    paint.color = const Color(0xFF4285F4);
    canvas.drawRRect(barRect, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
