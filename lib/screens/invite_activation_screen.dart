import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/invitation_model.dart';

/// Écran d'activation de compte via lien crypté à usage unique (Directeur / Enseignant) + Google Auth
class InviteActivationScreen extends StatefulWidget {
  final String token;

  const InviteActivationScreen({super.key, required this.token});

  @override
  State<InviteActivationScreen> createState() => _InviteActivationScreenState();
}

class _InviteActivationScreenState extends State<InviteActivationScreen> {
  final FirestoreServiceRDC _service = FirestoreServiceRDC();
  InvitationPersonnel? _invitation;
  bool _chargementInitial = true;
  bool _chargementSoumission = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _verifierToken();
  }

  Future<void> _verifierToken() async {
    try {
      final inv = await _service.getInvitationPersonnelParToken(widget.token);
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
          _erreur = 'Lien invalide ou expiré.';
          _chargementInitial = false;
        });
      }
    }
  }

  Future<void> _activerCompteAvecGoogle() async {
    if (_invitation == null) return;
    setState(() => _chargementSoumission = true);

    try {
      final userCred = await _service.connnecterAvecGoogle(
        roleSouhaite: _invitation!.typeRole,
      );
      final user = userCred.user;

      if (user != null) {
        await _service.consommerInvitationPersonnel(
          token: widget.token,
          user: user,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Compte ${_invitation!.nomRole} activé avec succès avec votre compte Google !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur s\'est produite lors de la connexion Google. Réessaie.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _chargementSoumission = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);

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
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _erreur ?? 'Ce lien a expiré ou a déjà été utilisé.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                  ),
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

    final isEnseignant = _invitation!.typeRole == 'enseignant';
    final roleColor = isEnseignant ? const Color(0xFF0D9488) : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Activation Compte ${_invitation!.nomRole}',
          style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isEnseignant ? Icons.record_voice_over_rounded : Icons.admin_panel_settings_rounded,
                            size: 48,
                            color: roleColor,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _invitation!.ecoleNom,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Invitation pour le rôle de ${_invitation!.nomRole}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: roleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Connecte-toi avec ton compte Google pour activer ton accès. Ce lien unique disparaîtra immédiatement après.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _chargementSoumission ? null : _activerCompteAvecGoogle,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F1F1F),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFDADCE0)),
                        ),
                      ),
                      child: _chargementSoumission
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Color(0xFF4285F4), strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.g_mobiledata_rounded, size: 32, color: Color(0xFF4285F4)),
                                SizedBox(width: 8),
                                Text(
                                  'Activer avec mon compte Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F1F1F),
                                  ),
                                ),
                              ],
                            ),
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
