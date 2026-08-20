import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/ecole_rdc_model.dart';
import '../../models/classe_rdc_model.dart';
import '../../models/utilisateur_model.dart';
import '../../services/firestore_service.dart';

/// Tableau de bord du Super Administrateur
/// Gestion centralisée de toutes les écoles du réseau
class SuperAdminDashboard extends StatefulWidget {
  final UtilisateurEduTrack superAdmin;

  const SuperAdminDashboard({super.key, required this.superAdmin});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard>
    with SingleTickerProviderStateMixin {
  final FirestoreServiceRDC _service = FirestoreServiceRDC();
  late TabController _tabController;
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _chargerStatistiques();
  }

  Future<void> _chargerStatistiques() async {
    final stats = await _service.getStatistiquesGlobales();
    if (mounted) setState(() => _stats = stats);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _afficherDialogProfil(BuildContext context) {
    final photoCtrl = TextEditingController(text: widget.superAdmin.profil.photoProfil);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Super Administrator Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 44,
              backgroundImage: widget.superAdmin.profil.photoProfil.isNotEmpty
                  ? NetworkImage(widget.superAdmin.profil.photoProfil)
                  : null,
              child: widget.superAdmin.profil.photoProfil.isEmpty
                  ? const Icon(Icons.person, size: 44)
                  : null,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: photoCtrl,
              decoration: const InputDecoration(
                labelText: 'Profile photo URL',
                hintText: 'https://...',
                prefixIcon: Icon(Icons.image_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save'),
            onPressed: () async {
              await _service.mettreAJourPhotoProfil(widget.superAdmin.id, photoCtrl.text.trim());
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile photo saved successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nomAdmin = widget.superAdmin.profil.nomComplet;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EduTrack',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              'Super Administrator',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _afficherDialogNotifications(context),
            tooltip: 'Broadcast & Notifications',
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: widget.superAdmin.profil.photoProfil.isNotEmpty
                  ? NetworkImage(widget.superAdmin.profil.photoProfil)
                  : null,
              child: widget.superAdmin.profil.photoProfil.isEmpty
                  ? Text(
                      nomAdmin.isNotEmpty ? nomAdmin[0].toUpperCase() : 'S',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profil',
                child: const Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('My Profile & Photo'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deconnexion',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text('Sign Out',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ],
            onSelected: (val) async {
              if (val == 'deconnexion') {
                await _service.seDeconnecter();
              } else if (val == 'profil') {
                _afficherDialogProfil(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Schools'),
            Tab(icon: Icon(Icons.people_outline), text: 'Users'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _VueEnsemble(stats: _stats, onRefresh: _chargerStatistiques),
          _GestionEcoles(service: _service, superAdminId: widget.superAdmin.id),
          _GestionUtilisateurs(service: _service),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// VUE D'ENSEMBLE (Statistiques globales)
// ════════════════════════════════════════════
class _VueEnsemble extends StatelessWidget {
  final Map<String, int> stats;
  final VoidCallback onRefresh;

  const _VueEnsemble({required this.stats, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.public, color: Colors.white, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'EduTrack School Network',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Academic Year 2024–2025',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Network Statistics',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _CarteStatistique(
                  icone: Icons.school,
                  label: 'Schools',
                  valeur: '${stats['ecoles'] ?? 0}',
                  couleur: Colors.indigo,
                ),
                _CarteStatistique(
                  icone: Icons.people,
                  label: 'Students',
                  valeur: '${stats['eleves'] ?? 0}',
                  couleur: Colors.teal,
                ),
                _CarteStatistique(
                  icone: Icons.person_outline,
                  label: 'Teachers',
                  valeur: '${stats['enseignants'] ?? 0}',
                  couleur: Colors.orange,
                ),
                _CarteStatistique(
                  icone: Icons.group,
                  label: 'Total Users',
                  valeur: '${stats['utilisateurs'] ?? 0}',
                  couleur: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteStatistique extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valeur;
  final Color couleur;

  const _CarteStatistique({
    required this.icone,
    required this.label,
    required this.valeur,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: couleur.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icone, color: couleur, size: 28),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valeur,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: couleur,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// GESTION DES ÉCOLES
// ════════════════════════════════════════════
class _GestionEcoles extends StatelessWidget {
  final FirestoreServiceRDC service;
  final String superAdminId;

  const _GestionEcoles({required this.service, required this.superAdminId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _afficherDialogueAjoutEcole(context),
        icon: const Icon(Icons.add),
        label: const Text('New School'),
      ),
      body: StreamBuilder<List<EcoleRDC>>(
        stream: service.streamToutesLesEcoles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }
          final ecoles = snapshot.data ?? [];
          if (ecoles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No schools registered',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add your first school',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ecoles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final ecole = ecoles[index];
              return _CarteEcole(
                ecole: ecole,
                service: service,
                onNommerDirecteur: () =>
                    _afficherDialogueNommerDirecteur(context, ecole),
              );
            },
          );
        },
      ),
    );
  }

  void _afficherDialogueAjoutEcole(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FormulaireAjoutEcole(
        service: service,
        superAdminId: superAdminId,
      ),
    );
  }

  void _afficherDialogueNommerDirecteur(BuildContext context, EcoleRDC ecole) {
    showDialog(
      context: context,
      builder: (_) => _DialogueNommerDirecteur(
        service: service,
        ecole: ecole,
      ),
    );
  }
}

class _CarteEcole extends StatelessWidget {
  final EcoleRDC ecole;
  final FirestoreServiceRDC service;
  final VoidCallback onNommerDirecteur;

  const _CarteEcole({
    required this.ecole,
    required this.service,
    required this.onNommerDirecteur,
  });

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete School'),
        content: Text('Are you sure you want to permanently delete "${ecole.nom}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await service.supprimerEcole(ecole.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('School "${ecole.nom}" deleted successfully.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.school,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ecole.nom,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${ecole.ville} · ${ecole.province.label}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await service.toggleEcoleActiveStatus(ecole.id, !ecole.estActive);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ecole.estActive
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      ecole.estActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: ecole.estActive ? Colors.green[700] : Colors.red[700],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) async {
                    if (val == 'supprimer') {
                      _confirmDelete(context);
                    } else if (val == 'toggle') {
                      await service.toggleEcoleActiveStatus(ecole.id, !ecole.estActive);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(ecole.estActive ? Icons.pause_circle_outline : Icons.play_circle_outline, size: 18),
                          const SizedBox(width: 8),
                          Text(ecole.estActive ? 'Deactivate School' : 'Activate School'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'supprimer',
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('Delete School', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text(ecole.typeEcole.label, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                ...ecole.cyclesDisponibles.map((c) => Chip(
                      label: Text(c.label, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    )),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  ecole.directeurId != null
                      ? Icons.person
                      : Icons.person_add_outlined,
                  size: 16,
                  color: ecole.directeurId != null
                      ? Colors.green
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ecole.directeurNom ?? 'No Principal Assigned',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ecole.directeurId != null
                          ? null
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _afficherDialogueGenererLien(context, ecole, typeRole: 'directeur'),
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 14),
                  label: const Text('Principal Link', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    foregroundColor: const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _afficherDialogueGenererLien(context, ecole, typeRole: 'enseignant'),
                  icon: const Icon(Icons.record_voice_over_outlined, size: 14),
                  label: const Text('Teacher Link', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    foregroundColor: const Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _afficherDialogueGenererLien(BuildContext context, EcoleRDC ecole, {required String typeRole}) {
    showDialog(
      context: context,
      builder: (_) => _DialogueGenererLienInvitation(ecole: ecole, typeRole: typeRole),
    );
  }
}

// ════════════════════════════════════════════
// FORMULAIRE AJOUT ÉCOLE
// ════════════════════════════════════════════
class _FormulaireAjoutEcole extends StatefulWidget {
  final FirestoreServiceRDC service;
  final String superAdminId;

  const _FormulaireAjoutEcole(
      {required this.service, required this.superAdminId});

  @override
  State<_FormulaireAjoutEcole> createState() => _FormulaireAjoutEcoleState();
}

class _FormulaireAjoutEcoleState extends State<_FormulaireAjoutEcole> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _adresseController = TextEditingController();
  final _villeController = TextEditingController();
  final _emailController = TextEditingController();
  final _telController = TextEditingController();

  TypeEcole _typeEcole = TypeEcole.prive;
  ProvinceRDC _province = ProvinceRDC.kinshasa;
  final Set<CycleEnseignement> _cycles = {
    CycleEnseignement.primaire,
    CycleEnseignement.secondaire,
  };
  bool _chargement = false;

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _emailController.dispose();
    _telController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cycles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un cycle.')),
      );
      return;
    }
    setState(() => _chargement = true);
    try {
      final ecole = EcoleRDC(
        id: '',
        nom: _nomController.text.trim(),
        adresse: _adresseController.text.trim(),
        ville: _villeController.text.trim(),
        province: _province,
        typeEcole: _typeEcole,
        emailContact: _emailController.text.trim(),
        telephoneContact: _telController.text.trim(),
        cyclesDisponibles: _cycles.toList(),
        creePar: widget.superAdminId,
        anneeAcademique: '2024-2025',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await widget.service.creerEcole(ecole);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('École « ${ecole.nom} » créée avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scrollController) => Form(
        key: _formKey,
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          children: [
            // Poignée
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Enregistrer une nouvelle école',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Nom
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'école *',
                prefixIcon: Icon(Icons.school_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 16),

            // Type d'école
            DropdownButtonFormField<TypeEcole>(
              value: _typeEcole,
              decoration: const InputDecoration(
                labelText: 'Type d\'école',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: TypeEcole.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _typeEcole = v!),
            ),
            const SizedBox(height: 16),

            // Province
            DropdownButtonFormField<ProvinceRDC>(
              value: _province,
              decoration: const InputDecoration(
                labelText: 'Province',
                prefixIcon: Icon(Icons.map_outlined),
                border: OutlineInputBorder(),
              ),
              items: ProvinceRDC.values
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.label),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _province = v!),
            ),
            const SizedBox(height: 16),

            // Ville
            TextFormField(
              controller: _villeController,
              decoration: const InputDecoration(
                labelText: 'Ville *',
                prefixIcon: Icon(Icons.location_city_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.isEmpty ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 16),

            // Adresse
            TextFormField(
              controller: _adresseController,
              decoration: const InputDecoration(
                labelText: 'Adresse complète',
                prefixIcon: Icon(Icons.place_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Cycles disponibles
            Text('Cycles disponibles *',
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: CycleEnseignement.values.map((cycle) {
                final selected = _cycles.contains(cycle);
                return FilterChip(
                  label: Text(cycle.label),
                  selected: selected,
                  onSelected: (val) {
                    setState(() {
                      val ? _cycles.add(cycle) : _cycles.remove(cycle);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email de contact',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Téléphone
            TextFormField(
              controller: _telController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Bouton
            FilledButton.icon(
              onPressed: _chargement ? null : _enregistrer,
              icon: _chargement
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Enregistrer l\'école'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════
// DIALOGUE NOMMER DIRECTEUR
// ════════════════════════════════════════════
class _DialogueNommerDirecteur extends StatefulWidget {
  final FirestoreServiceRDC service;
  final EcoleRDC ecole;

  const _DialogueNommerDirecteur(
      {required this.service, required this.ecole});

  @override
  State<_DialogueNommerDirecteur> createState() =>
      _DialogueNommerDirecteurState();
}

class _DialogueNommerDirecteurState extends State<_DialogueNommerDirecteur> {
  final _emailController = TextEditingController();
  List<UtilisateurEduTrack> _resultats = [];
  UtilisateurEduTrack? _selection;
  bool _chargement = false;

  Future<void> _rechercher() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _chargement = true);
    try {
      final resultats = await widget.service.rechercherUtilisateurs(email);
      setState(() => _resultats = resultats);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _nommer() async {
    if (_selection == null) return;
    setState(() => _chargement = true);
    try {
      await widget.service.nommerDirecteur(
        ecoleId: widget.ecole.id,
        userId: _selection!.id,
        nomDirecteur: _selection!.profil.nomComplet,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selection!.profil.nomComplet} nommé(e) directeur de ${widget.ecole.nom}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Nommer un directeur\n${widget.ecole.nom}',
          style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Rechercher par email',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _rechercher,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
            if (_chargement) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_resultats.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...(_resultats.map((u) => RadioListTile<UtilisateurEduTrack>(
                    value: u,
                    groupValue: _selection,
                    onChanged: (val) => setState(() => _selection = val),
                    title: Text(u.profil.nomComplet),
                    subtitle: Text(u.email),
                  ))),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selection == null || _chargement ? null : _nommer,
          child: const Text('Confirmer'),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════
// GESTION UTILISATEURS (Complet & Temps Réel)
// ════════════════════════════════════════════
class _GestionUtilisateurs extends StatefulWidget {
  final FirestoreServiceRDC service;

  const _GestionUtilisateurs({required this.service});

  @override
  State<_GestionUtilisateurs> createState() => _GestionUtilisateursState();
}

class _GestionUtilisateursState extends State<_GestionUtilisateurs> {
  final _searchController = TextEditingController();
  String _filtreRole = 'tous';
  String _recherche = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search bar & Filters
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _recherche = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChipFilter('tous', 'All'),
                    const SizedBox(width: 8),
                    _buildChipFilter('superAdmin', 'Super Admin'),
                    const SizedBox(width: 8),
                    _buildChipFilter('directeur', 'Principals'),
                    const SizedBox(width: 8),
                    _buildChipFilter('enseignant', 'Teachers'),
                    const SizedBox(width: 8),
                    _buildChipFilter('parent', 'Parents'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Users list
        Expanded(
          child: StreamBuilder<List<UtilisateurEduTrack>>(
            stream: widget.service.streamTousLesUtilisateurs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final users = snapshot.data ?? [];

              final filtres = users.where((u) {
                final matchSearch = _recherche.isEmpty ||
                    u.email.toLowerCase().contains(_recherche) ||
                    u.profil.nomComplet.toLowerCase().contains(_recherche);
                final matchRole = _filtreRole == 'tous' || u.role.name == _filtreRole;
                return matchSearch && matchRole;
              }).toList();

              if (filtres.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('No users found', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filtres.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final user = filtres[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.15)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getColorForRole(user.role.name).withValues(alpha: 0.15),
                        child: Text(
                          user.profil.nomComplet.isNotEmpty ? user.profil.nomComplet[0].toUpperCase() : 'U',
                          style: TextStyle(color: _getColorForRole(user.role.name), fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(user.profil.nomComplet.isNotEmpty ? user.profil.nomComplet : user.email,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(user.email, style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getColorForRole(user.role.name).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRoleLabel(user.role.name),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getColorForRole(user.role.name),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChipFilter(String value, String label) {
    final estSelectionne = _filtreRole == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: estSelectionne ? Colors.white : null)),
      selected: estSelectionne,
      selectedColor: Theme.of(context).colorScheme.primary,
      onSelected: (_) => setState(() => _filtreRole = value),
    );
  }

  Color _getColorForRole(String role) {
    switch (role) {
      case 'superAdmin':
      case 'super_admin':
        return Colors.indigo;
      case 'directeur':
        return Colors.blue;
      case 'enseignant':
        return Colors.teal;
      case 'parent':
        return Colors.purple;
      case 'eleve':
      case 'student':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'superAdmin':
      case 'super_admin':
        return 'Super Admin';
      case 'directeur':
        return 'Principal';
      case 'enseignant':
        return 'Teacher';
      case 'parent':
        return 'Parent';
      case 'eleve':
      case 'student':
        return 'Student';
      default:
        return role;
    }
  }
}

/// Dialogue des Notifications Système & Diffusion Globale
void _afficherDialogNotifications(BuildContext context) {
  final service = FirestoreServiceRDC();
  final titreController = TextEditingController();
  final messageController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.campaign_rounded, color: Colors.blue),
          SizedBox(width: 8),
          Text('Broadcast & Notifications', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Send a global broadcast notification to all school networks across the application.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titreController,
              decoration: const InputDecoration(
                labelText: 'Message Title *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message Content *',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Broadcast'),
          onPressed: () async {
            final titre = titreController.text.trim();
            final msg = messageController.text.trim();
            if (titre.isEmpty || msg.isEmpty) return;

            Navigator.pop(ctx);
            try {
              await service.envoyerNotificationGlobale(titre: titre, message: msg);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification broadcast successfully to the entire network!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            }
          },
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════
// GENERATE UNIQUE INVITATION LINK DIALOG
// ════════════════════════════════════════════
class _DialogueGenererLienInvitation extends StatefulWidget {
  final EcoleRDC ecole;
  final String typeRole; // 'directeur' or 'enseignant'

  const _DialogueGenererLienInvitation({required this.ecole, required this.typeRole});

  @override
  State<_DialogueGenererLienInvitation> createState() => _DialogueGenererLienInvitationState();
}

class _DialogueGenererLienInvitationState extends State<_DialogueGenererLienInvitation> {
  final FirestoreServiceRDC _service = FirestoreServiceRDC();
  final _emailController = TextEditingController();

  String? _lienGenere;
  bool _chargement = false;

  bool get _estEnseignant => widget.typeRole == 'enseignant';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _generer() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    setState(() => _chargement = true);
    try {
      final String url;
      if (_estEnseignant) {
        url = await _service.genererLienInvitationEnseignant(
          ecoleId: widget.ecole.id,
          ecoleNom: widget.ecole.nom,
          emailEnseignant: email,
        );
      } else {
        url = await _service.genererLienInvitationDirecteur(
          ecoleId: widget.ecole.id,
          ecoleNom: widget.ecole.nom,
          emailDirecteur: email,
        );
      }
      if (mounted) {
        setState(() => _lienGenere = url);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _estEnseignant ? 'Enseignant' : 'Directeur / Préfet';
    final color = _estEnseignant ? const Color(0xFF0D9488) : const Color(0xFF2563EB);
    final icon = _estEnseignant ? Icons.record_voice_over : Icons.admin_panel_settings;

    return AlertDialog(
      title: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Inviter un $label\n${widget.ecole.nom}',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_lienGenere == null) ...[
              Text(
                'Entre l\'adresse email du futur $label. Un lien unique sera généré — il disparaît dès qu\'il est utilisé.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email du $label *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lien généré avec succès ! Copie-le et envoie-le.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _lienGenere!,
                        style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: color, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _lienGenere!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📋 Lien d\'invitation copié dans le presse-papier !'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(_lienGenere != null ? 'Fermer' : 'Annuler'),
        ),
        if (_lienGenere == null)
          FilledButton.icon(
            onPressed: _chargement ? null : _generer,
            icon: _chargement
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.vpn_key),
            label: const Text('Générer le lien'),
            style: FilledButton.styleFrom(backgroundColor: color),
          )
        else
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _lienGenere!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📋 Lien d\'invitation copié dans le presse-papier !'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copier le lien'),
            style: FilledButton.styleFrom(backgroundColor: color),
          ),
      ],
    );
  }
}
