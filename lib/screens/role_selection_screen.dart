import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/parent_signup_screen.dart';
import '../utils/storage_util.dart';

class RoleSelectionScreen extends StatelessWidget {
  final String schoolName;
  final String schoolToken;
  final String schoolAddress;
  final String schoolPhone;

  const RoleSelectionScreen({
    super.key,
    required this.schoolName,
    required this.schoolToken,
    required this.schoolAddress,
    required this.schoolPhone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo Header with Glowing Shield & Cap Emblem
                  Center(
                    child: Container(
                      height: 96,
                      width: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 64,
                            color: Colors.white24,
                          ),
                          const Icon(
                            Icons.school_rounded,
                            size: 46,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'EduTrack RDC',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    'Portail Officiel de Gestion Scolaire',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Role Selection Cards
                  _buildRoleButton(
                    context: context,
                    role: 'super_admin',
                    label: 'Super Administrateur',
                    subtitle: 'Administration réseau principal RDC',
                    icon: Icons.security_rounded,
                    color: const Color(0xFF4F46E5),
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'directeur',
                    label: 'Directeur / Préfet',
                    subtitle: 'Espace Direction d\'Établissement',
                    icon: Icons.admin_panel_settings_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'teacher',
                    label: 'Enseignant / Professeur',
                    subtitle: 'Gestion des classes, notes et présences',
                    icon: Icons.record_voice_over_rounded,
                    color: const Color(0xFF0D9488),
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'student',
                    label: 'Élève',
                    subtitle: 'Consultation du bulletin et des devoirs',
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'parent',
                    label: 'Parent / Tuteur',
                    subtitle: 'Suivi de la scolarité de vos enfants',
                    icon: Icons.family_restroom_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                  const SizedBox(height: 28),

                  const Divider(),
                  const SizedBox(height: 14),

                  // Public Parent Signup Section
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ParentSignupScreen()),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text(
                      'Créer un compte Parent (avec Code Élève)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton({
    required BuildContext context,
    required String role,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await StorageUtil.setString('selectedRole', role);
            await StorageUtil.setBool('isLoggedIn', false);

            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LoginScreen(
                  selectedRole: role,
                  schoolToken: schoolToken,
                  schoolName: schoolName,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.88)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
