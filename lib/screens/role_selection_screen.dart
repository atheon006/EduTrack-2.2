import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
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
                  // Hero Logo
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        size: 54,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // App Title
                  Text(
                    'EduTrack RDC',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Système de gestion scolaire pour la RDC',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Text(
                    'Choisissez votre rôle pour accéder au portail',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Roles list
                  _buildRoleButton(
                    context: context,
                    role: 'super_admin',
                    label: 'Super Administrateur',
                    subtitle: 'Gestion globale de toutes les écoles du réseau',
                    icon: Icons.public_rounded,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'directeur',
                    label: 'Directeur / Préfet',
                    subtitle: 'Direction de l\'établissement et administration',
                    icon: Icons.admin_panel_settings_rounded,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'teacher',
                    label: 'Enseignant / Professeur',
                    subtitle: 'Gestion des cours, présences et bulletins',
                    icon: Icons.record_voice_over_rounded,
                    color: Colors.teal.shade700,
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'student',
                    label: 'Élève',
                    subtitle: 'Consultation des horaires, notes et annonces',
                    icon: Icons.person_rounded,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(height: 12),

                  _buildRoleButton(
                    context: context,
                    role: 'parent',
                    label: 'Parent / Tuteur',
                    subtitle: 'Suivi du parcours et frais scolaires des enfants',
                    icon: Icons.family_restroom_rounded,
                    color: Colors.purple.shade700,
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
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
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
                    size: 26,
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
                          fontSize: 16,
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
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
