import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// Écran d'inscription publique réservé uniquement aux Parents / Tuteurs
/// Design ultra-épuré, lisibilité maximale, validation du Code Élève / ID
class ParentSignupScreen extends StatefulWidget {
  const ParentSignupScreen({super.key});

  @override
  State<ParentSignupScreen> createState() => _ParentSignupScreenState();
}

class _ParentSignupScreenState extends State<ParentSignupScreen> {
  final FirestoreServiceRDC _service = FirestoreServiceRDC();
  final _formKey = GlobalKey<FormState>();

  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _codeEleveController = TextEditingController();

  bool _chargement = false;
  bool _cacherMotDePasse = true;

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    _codeEleveController.dispose();
    super.dispose();
  }

  Future<void> _inscrireParent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargement = true);

    try {
      await _service.inscrireParent(
        email: _emailController.text.trim(),
        motDePasse: _passController.text.trim(),
        prenom: _prenomController.text.trim(),
        nom: _nomController.text.trim(),
        codeEleve: _codeEleveController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inscription réussie ! Votre compte Parent est maintenant créé.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF3B0764) : const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF6B21A8) : const Color(0xFFE9D5FF),
                          ),
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
                                    'Renseignez l\'ID de votre enfant pour lier votre compte',
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

                      // Code Élève / ID
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
                            ? 'Veuillez entrer le code de votre enfant'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Prénom
                      Text(
                        'Votre Prénom *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _prenomController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Votre prénom',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: theme.colorScheme.primary),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 16),

                      // Nom
                      Text(
                        'Votre Nom de Famille *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nomController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Votre nom de famille',
                          prefixIcon: Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 16),

                      // Email
                      Text(
                        'Adresse Email *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'exemple@domaine.cd',
                          prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Champ obligatoire';
                          if (!v.contains('@') || !v.contains('.')) return 'Adresse email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Mot de passe
                      Text(
                        'Mot de passe *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passController,
                        obscureText: _cacherMotDePasse,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Au moins 6 caractères',
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: theme.colorScheme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _cacherMotDePasse ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () => setState(() => _cacherMotDePasse = !_cacherMotDePasse),
                          ),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Champ obligatoire';
                          if (v.length < 6) return 'Au moins 6 caractères requis';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Confirmation mot de passe
                      Text(
                        'Confirmer le mot de passe *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmPassController,
                        obscureText: _cacherMotDePasse,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Répétez votre mot de passe',
                          prefixIcon: Icon(Icons.lock_reset_rounded, color: theme.colorScheme.primary),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) {
                          if (v != _passController.text) return 'Les mots de passe ne correspondent pas';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      ElevatedButton.icon(
                        onPressed: _chargement ? null : _inscrireParent,
                        icon: _chargement
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                        label: Text(
                          _chargement ? 'Inscription en cours...' : 'Créer mon compte Parent',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          backgroundColor: Colors.purple.shade700,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
