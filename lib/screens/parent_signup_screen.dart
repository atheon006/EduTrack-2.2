import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// Écran d'inscription publique réservé uniquement aux Parents / Tuteurs
/// Nécessite le Code Élève / ID de l'enfant pour finaliser la création du compte
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
            content: Text('Inscription réussie ! Votre compte Parent est créé.'),
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Inscription Parent / Tuteur'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.family_restroom_rounded, size: 36, color: Colors.purple.shade700),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Espace Parent EduTrack',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade900,
                                    ),
                                  ),
                                  Text(
                                    'Inscrivez-vous pour suivre la scolarité de votre enfant',
                                    style: TextStyle(fontSize: 12, color: Colors.purple.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Code élève
                      TextFormField(
                        controller: _codeEleveController,
                        decoration: InputDecoration(
                          labelText: 'Code Élève / ID de votre enfant *',
                          hintText: 'ex: ELEVE-2024-001',
                          prefixIcon: const Icon(Icons.qr_code_scanner_rounded),
                          border: const OutlineInputBorder(),
                          suffixIcon: Tooltip(
                            message: 'L\'ID fourni par l\'école pour identifier votre enfant',
                            child: Icon(Icons.info_outline, color: theme.colorScheme.primary),
                          ),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Veuillez entrer le code de votre enfant' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _prenomController,
                        decoration: const InputDecoration(
                          labelText: 'Votre Prénom *',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Votre Nom *',
                          prefixIcon: Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Adresse Email *',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Champ obligatoire';
                          if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passController,
                        obscureText: _cacherMotDePasse,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe *',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_cacherMotDePasse ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _cacherMotDePasse = !_cacherMotDePasse),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Champ obligatoire';
                          if (v.length < 6) return 'Au moins 6 caractères';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _confirmPassController,
                        obscureText: _cacherMotDePasse,
                        decoration: const InputDecoration(
                          labelText: 'Confirmer le mot de passe *',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v != _passController.text) return 'Les mots de passe ne correspondent pas';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      FilledButton.icon(
                        onPressed: _chargement ? null : _inscrireParent,
                        icon: _chargement
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.person_add_rounded),
                        label: const Text('Créer mon compte Parent'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.purple.shade700,
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
