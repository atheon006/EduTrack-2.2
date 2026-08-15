import 'package:flutter/material.dart';
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
              'EduTrack RDC',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              'Super Administrateur',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                nomAdmin.isNotEmpty ? nomAdmin[0].toUpperCase() : 'S',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'profil',
                child: const Row(
                  children: [
                    Icon(Icons.person_outline),
                    SizedBox(width: 8),
                    Text('Mon profil'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deconnexion',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Text('Se déconnecter',
                        style: TextStyle(color: theme.colorScheme.error)),
                  ],
                ),
              ),
            ],
            onSelected: (val) async {
              if (val == 'deconnexion') {
                await _service.seDeconnecter();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Vue d\'ensemble'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Écoles'),
            Tab(icon: Icon(Icons.people_outline), text: 'Utilisateurs'),
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
                    'Réseau EduTrack RDC',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Année académique 2024–2025',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Statistiques du réseau',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Grille de stats
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
                  label: 'Écoles',
                  valeur: '${stats['ecoles'] ?? 0}',
                  couleur: Colors.indigo,
                ),
                _CarteStatistique(
                  icone: Icons.people,
                  label: 'Élèves',
                  valeur: '${stats['eleves'] ?? 0}',
                  couleur: Colors.teal,
                ),
                _CarteStatistique(
                  icone: Icons.person_outline,
                  label: 'Enseignants',
                  valeur: '${stats['enseignants'] ?? 0}',
                  couleur: Colors.orange,
                ),
                _CarteStatistique(
                  icone: Icons.group,
                  label: 'Total utilisateurs',
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
        label: const Text('Nouvelle école'),
      ),
      body: StreamBuilder<List<EcoleRDC>>(
        stream: service.streamToutesLesEcoles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur : ${snapshot.error}'),
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
                    'Aucune école enregistrée',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Appuyez sur + pour ajouter votre première école',
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
  final VoidCallback onNommerDirecteur;

  const _CarteEcole({required this.ecole, required this.onNommerDirecteur});

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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    ecole.directeurNom ?? 'Aucun directeur nommé',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: ecole.directeurId != null
                          ? null
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _afficherDialogueGenererLien(context, ecole),
                  icon: const Icon(Icons.vpn_key_outlined, size: 14),
                  label: const Text('Lien unique', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _afficherDialogueGenererLien(BuildContext context, EcoleRDC ecole) {
    showDialog(
      context: context,
      builder: (_) => _DialogueGenererLienInvitation(ecole: ecole),
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
          child: const Text('Annuler'),
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
// GESTION UTILISATEURS (placeholder)
// ════════════════════════════════════════════
class _GestionUtilisateurs extends StatelessWidget {
  final FirestoreServiceRDC service;

  const _GestionUtilisateurs({required this.service});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline,
              size: 80,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Gestion des utilisateurs',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Disponible prochainement',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// DIALOGUE GÉNÉRER LIEN INVITATION UNIQUE
// ════════════════════════════════════════════
class _DialogueGenererLienInvitation extends StatefulWidget {
  final EcoleRDC ecole;

  const _DialogueGenererLienInvitation({required this.ecole});

  @override
  State<_DialogueGenererLienInvitation> createState() => _DialogueGenererLienInvitationState();
}

class _DialogueGenererLienInvitationState extends State<_DialogueGenererLienInvitation> {
  final FirestoreServiceRDC _service = FirestoreServiceRDC();
  final _emailController = TextEditingController();

  String? _lienGenere;
  bool _chargement = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _generer() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une adresse email valide.')),
      );
      return;
    }

    setState(() => _chargement = true);
    try {
      final url = await _service.genererLienInvitationDirecteur(
        ecoleId: widget.ecole.id,
        ecoleNom: widget.ecole.nom,
        emailDirecteur: email,
      );
      if (mounted) {
        setState(() => _lienGenere = url);
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
    return AlertDialog(
      title: Text('Invitation du Directeur / Préfet\n${widget.ecole.nom}',
          style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_lienGenere == null) ...[
              const Text(
                'Entrez l\'adresse email du futur Directeur. Un lien d\'activation crypté à usage unique sera généré.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email du Directeur / Préfet *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
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
                        'Lien unique d\'invitation généré ! Ce lien expirera dès sa première utilisation.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(
                _lienGenere!,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.blue),
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
          ),
      ],
    );
  }
}
