import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/invitation_model.dart';

/// Écran d'activation de compte Directeur / Préfet via lien crypté à usage unique + Google Auth
class InviteActivationScreen extends StatefulWidget {
  final String token;

  const InviteActivationScreen({super.key, required this.token});

  @override
  State<InviteActivationScreen> createState() => _InviteActivationScreenState();
}

class _InviteActivationScreenState extends State<InviteActivationScreen> {
  final FirestoreServiceRDC _service = FirestoreServiceRDC();
  InvitationDirecteur? _invitation;
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

  Future<void> _activerCompteAvecGoogle() async {
    setState(() => _chargementSoumission = true);

    try {
      final userCred = await _service.connnecterAvecGoogle(roleSouhaite: 'directeur');
      final user = userCred.user;

      if (user != null) {
        await _service.consommerInvitationDirecteur(
          token: widget.token,
          motDePasse: 'google_auth_sso',
          prenom: user.displayName?.split(' ').first ?? 'Directeur',
          nom: (user.displayName?.split(' ').length ?? 0) > 1
              ? user.displayName!.split(' ').sublist(1).join(' ')
              : '',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte Directeur activé avec succès avec votre compte Google !'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacementNamed('/');
        }
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
                  _erreur ?? 'Ce lien a expiré ou a déjà été consommé.',
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Activation Direction Écoles',
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
                        color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.verified_user_rounded, size: 44, color: Colors.blue),
                          const SizedBox(height: 10),
                          Text(
                            _invitation!.ecoleNom,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFEFF6FF) : const Color(0xFF1E40AF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Invitation Direction Réseau EduTrack',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'Activez votre compte avec votre adresse Google pour finaliser la prise de fonction.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      onPressed: _chargementSoumission ? null : _activerCompteAvecGoogle,
                      icon: _chargementSoumission
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : const Icon(Icons.g_mobiledata_rounded, size: 34, color: Colors.white),
                      label: Text(
                        _chargementSoumission ? 'Activation en cours...' : 'Activer avec mon compte Google',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        backgroundColor: const Color(0xFF2563EB),
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
    );
  }
}
