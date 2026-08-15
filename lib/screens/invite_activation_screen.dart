import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/invitation_model.dart';

/// Écran d'activation de compte Directeur / Préfet via lien crypté à usage unique
class InviteActivationScreen extends StatefulWidget {
  final String token;

  const InviteActivationScreen({super.key, required this.token});

  @override
  State<InviteActivationScreen> createState() => _InviteActivationScreenState();
}

class _InviteActivationScreenState extends State<InviteActivationScreen> {
  final FirestoreServiceRDC _service = FirestoreServiceRDC();
  final _formKey = GlobalKey<FormState>();
  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  InvitationDirecteur? _invitation;
  bool _chargementInitial = true;
  bool _chargementSoumission = false;
  String? _erreur;
  bool _cacherMotDePasse = true;

  @override
  void initState() {
    super.initState();
    _verifierToken();
  }

  Future<void> _verifierToken() async {
    try {
      final inv = await _service.getInvitationParToken(widget.token);
      if (mounted) {
        setState(() {
          _invitation = inv;
          _chargementInitial = false;
          if (inv == null) {
            _erreur = 'Ce lien d\'invitation est invalide, expiré ou a déjà été utilisé.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = 'Erreur lors de la vérification du lien d\'invitation : $e';
          _chargementInitial = false;
        });
      }
    }
  }

  Future<void> _activerCompte() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _chargementSoumission = true);

    try {
      await _service.consommerInvitationDirecteur(
        token: widget.token,
        motDePasse: _passController.text.trim(),
        prenom: _prenomController.text.trim(),
        nom: _nomController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compte Directeur activé avec succès ! Connexion en cours...'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _chargementSoumission = false);
    }
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final inputBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_chargementInitial) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Vérification du lien d\'invitation sécurisé...'),
            ],
          ),
        ),
      );
    }

    if (_erreur != null || _invitation == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_off_rounded, size: 80, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  'Lien d\'invitation invalide',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryTextColor),
                ),
                const SizedBox(height: 12),
                Text(
                  _erreur ?? 'Ce lien a expiré ou a déjà été consommé.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                  child: const Text('Retourner à l\'accueil'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Activation de votre compte Directeur', style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
                          color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.verified_user_rounded, size: 40, color: Colors.blue),
                            const SizedBox(height: 8),
                            Text(
                              _invitation!.ecoleNom,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFEFF6FF) : const Color(0xFF1E40AF),
                              ),
                            ),
                            Text(
                              _invitation!.emailDirecteur,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Complétez votre profil de Direction',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: primaryTextColor),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Votre Prénom *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _prenomController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Prénom',
                          prefixIcon: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Votre Nom de famille *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nomController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Nom de famille',
                          prefixIcon: Icon(Icons.badge_outlined, color: theme.colorScheme.primary),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Champ obligatoire' : null,
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Définir un mot de passe *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: primaryTextColor),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passController,
                        obscureText: _cacherMotDePasse,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Au moins 6 caractères',
                          prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                          suffixIcon: IconButton(
                            icon: Icon(_cacherMotDePasse ? Icons.visibility : Icons.visibility_off, color: theme.colorScheme.primary),
                            onPressed: () => setState(() => _cacherMotDePasse = !_cacherMotDePasse),
                          ),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Champ obligatoire';
                          if (v.length < 6) return 'Au moins 6 caractères nécessaires';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

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
                          prefixIcon: Icon(Icons.lock_reset_outlined, color: theme.colorScheme.primary),
                          fillColor: inputBgColor,
                          filled: true,
                        ),
                        validator: (v) {
                          if (v != _passController.text) return 'Les mots de passe ne correspondent pas';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      FilledButton.icon(
                        onPressed: _chargementSoumission ? null : _activerCompte,
                        icon: _chargementSoumission
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_outline, color: Colors.white),
                        label: const Text('Activer mon compte & Accéder à l\'école', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
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
