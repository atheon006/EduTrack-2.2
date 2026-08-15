import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// Écran d'inscription publique réservé uniquement aux Parents / Tuteurs avec Google Auth
class ParentSignupScreen extends StatefulWidget {
  const ParentSignupScreen({super.key});

  @override
  State<ParentSignupScreen> createState() => _ParentSignupScreenState();
}

class _ParentSignupScreenState extends State<ParentSignupScreen> {
  final FirestoreServiceRDC _service = FirestoreServiceRDC();
  final _formKey = GlobalKey<FormState>();
  final _codeEleveController = TextEditingController();
  bool _chargement = false;

  @override
  void dispose() {
    _codeEleveController.dispose();
    super.dispose();
  }

  Future<void> _inscrireParentAvecGoogle() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargement = true);

    try {
      final userCred = await _service.connnecterAvecGoogle(roleSouhaite: 'parent');
      final user = userCred.user;

      if (user != null) {
        await _service.inscrireParent(
          email: user.email ?? '',
          motDePasse: 'google_auth_sso',
          prenom: user.displayName?.split(' ').first ?? 'Parent',
          nom: (user.displayName?.split(' ').length ?? 0) > 1
              ? user.displayName!.split(' ').sublist(1).join(' ')
              : '',
          codeEleve: _codeEleveController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte Parent lié et créé avec succès !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'inscription : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inputBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Inscription Parent / Tuteur',
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(26.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade700,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.family_restroom_rounded, size: 28, color: Colors.white),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Espace Parent EduTrack',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? const Color(0xFFF3E8FF) : const Color(0xFF581C87),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Liez votre compte Google au code élève de votre enfant',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFE9D5FF) : const Color(0xFF7E22CE),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Code Élève / ID de votre enfant *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeEleveController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'ex: ELEVE-2024-001',
                          prefixIcon: Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.primary),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Veuillez entrer le code élève de votre enfant'
                            : null,
                      ),
                      const SizedBox(height: 28),

                      ElevatedButton.icon(
                        onPressed: _chargement ? null : _inscrireParentAvecGoogle,
                        icon: _chargement
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.g_mobiledata_rounded, size: 34, color: Colors.white),
                        label: Text(
                          _chargement ? 'Inscription en cours...' : 'S\'inscrire avec Google',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: Colors.purple.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
