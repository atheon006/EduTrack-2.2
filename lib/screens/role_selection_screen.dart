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
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade100,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24.0, 40.0, 24.0, 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Hero(
                    tag: 'app_logo',
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                       color: Color.fromRGBO(200, 228, 252, 1.0),
                        shape: BoxShape.circle,
                        
                      ),
                      child: Image.asset(
                                'images/logo.png',
                                fit: BoxFit.contain,
                              ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'School Management App',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Select your role to continue',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  _buildRoleButton(
                    context: context,
                    role: 'school_admin',
                    label: 'School Admin',
                    subtitle: 'Manage school operations',
                    icon: Icons.admin_panel_settings,
                    color: Colors.blue,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildRoleButton(
                    context: context,
                    role: 'teacher',
                    label: 'Teacher',
                    subtitle: 'Teach and manage classes',
                    icon: Icons.school,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  
                  _buildRoleButton(
                    context: context,
                    role: 'student',
                    label: 'Student',
                    subtitle: 'Access your academic portal',
                    icon: Icons.person,
                    color: Colors.orange,
                  ),
                  
                  const SizedBox(height: 16),
                 
                  _buildRoleButton(
                    context: context,
                    role: 'parent',
                    label: 'Parent',
                    subtitle: 'Monitor your child\'s progress',
                    icon: Icons.family_restroom,
                    color: Colors.purple,
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
      height: 74,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            // Store selected role in local storage
            await StorageUtil.setString('selectedRole', role);
            
            // Clear any previous login state when selecting a new role
            await StorageUtil.setBool('isLoggedIn', false);
            
            Navigator.push(
              // ignore: use_build_context_synchronously
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
                colors: [color, color.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
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
                  Icons.arrow_forward_ios,
                  color: Colors.white.withValues(alpha: 0.8),
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

