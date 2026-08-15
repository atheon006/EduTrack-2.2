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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primaryContainer.withValues(alpha: 0.8),
              theme.colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo Header
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      height: 90,
                      width: 90,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Text(
                    'EduTrack RDC',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    'Portail Officiel de Gestion Scolaire',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Role Selection Buttons
                  _buildRoleButton(
                    context: context,
                    role: 'super_admin',
                    label: 'Super Administrateur',
                    subtitle: 'Accès exclusif (readykalonda38@gmail.com)',
                    icon: Icons.shield_rounded,
                    color: Colors.indigo.shade800,
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'directeur',
                    label: 'Directeur / Préfet',
                    subtitle: 'Connexion direction d\'établissement',
                    icon: Icons.admin_panel_settings_rounded,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'teacher',
                    label: 'Enseignant / Professeur',
                    subtitle: 'Espace corps professoral',
                    icon: Icons.record_voice_over_rounded,
                    color: Colors.teal.shade700,
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'student',
                    label: 'Élève',
                    subtitle: 'Portail des élèves',
                    icon: Icons.person_rounded,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'parent',
                    label: 'Parent / Tuteur',
                    subtitle: 'Connexion espace tuteur',
                    icon: Icons.family_restroom_rounded,
                    color: Colors.purple.shade700,
                  ),
                  const SizedBox(height: 24),

                  const Divider(),
                  const SizedBox(height: 12),

                  // Public Parent Signup Section
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ParentSignupScreen()),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text(
                      'Nouveau Parent ? Créer un compte avec l\'ID Élève',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
            color: color.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.85)],
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
                    color: Colors.white.withValues(alpha: 0.25),
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
                          fontSize: 11,
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
