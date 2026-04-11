import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/client.dart';
import '../../core/models/project.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/projects_provider.dart';

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);
    final projectsAsync = ref.watch(projectsByClientProvider(clientId));

    // Retrouve le client depuis le cache existant
    final client = clientsAsync.valueOrNull
        ?.where((c) => c.id == clientId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(client?.name ?? 'Projets'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/clients'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau projet',
            onPressed: () => _openForm(context, ref, null),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résumé client
          if (client != null) _ClientHeader(client: client),
          // Liste projets
          Expanded(
            child: projectsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (projects) => projects.isEmpty
                  ? _EmptyProjects(onAdd: () => _openForm(context, ref, null))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: projects.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ProjectTile(
                        project: projects[i],
                        onEdit: () => _openForm(context, ref, projects[i]),
                        onDelete: () =>
                            _confirmDelete(context, ref, projects[i]),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, Project? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProjectFormSheet(
        clientId: clientId,
        existing: existing,
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce projet ?'),
        content: Text(
            '${project.name} et toutes ses sessions seront supprimés.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(projectsProvider.notifier)
          .delete(id: project.id, clientId: clientId);
    }
  }
}

// ─── Header client ─────────────────────────────────────────────────────────────

class _ClientHeader extends StatelessWidget {
  final Client client;

  const _ClientHeader({required this.client});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color:
                Theme.of(context).colorScheme.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (client.siret != null)
            _InfoRow(Icons.tag_outlined, 'SIRET: ${client.siret}'),
          if (client.address != null)
            _InfoRow(Icons.location_on_outlined, client.address!),
          if (client.email != null)
            _InfoRow(Icons.email_outlined, client.email!),
          if (client.siret == null &&
              client.address == null &&
              client.email == null)
            const Text('Aucune info complémentaire',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFF374151))),
          ),
        ],
      ),
    );
  }
}

// ─── Project tile ─────────────────────────────────────────────────────────────

class _ProjectTile extends StatelessWidget {
  final Project project;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProjectTile({
    required this.project,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(
            '/clients/${project.clientId}/projects/${project.id}/sessions'),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_outlined,
                    color:
                        Theme.of(context).colorScheme.onSecondaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      '${project.hourlyRate.toStringAsFixed(0)} ${project.currency}/h',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: const Color(0xFF6B7280),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: const Color(0xFFDC2626),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty projects ────────────────────────────────────────────────────────────

class _EmptyProjects extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyProjects({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Aucun projet',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Créez un projet pour commencer à tracker du temps.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau projet'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Project form bottom sheet ─────────────────────────────────────────────────

class ProjectFormSheet extends ConsumerStatefulWidget {
  final String clientId;
  final Project? existing;

  const ProjectFormSheet({
    super.key,
    required this.clientId,
    this.existing,
  });

  @override
  ConsumerState<ProjectFormSheet> createState() => _ProjectFormSheetState();
}

class _ProjectFormSheetState extends ConsumerState<ProjectFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _rate;
  String _currency = 'EUR';
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _rate = TextEditingController(
        text: p != null ? p.hourlyRate.toStringAsFixed(0) : '');
    _currency = p?.currency ?? 'EUR';
  }

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final rate = double.parse(_rate.text.trim().replaceAll(',', '.'));
      final notifier = ref.read(projectsProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          id: widget.existing!.id,
          clientId: widget.clientId,
          name: _name.text.trim(),
          hourlyRate: rate,
          currency: _currency,
        );
      } else {
        await notifier.create(
          clientId: widget.clientId,
          name: _name.text.trim(),
          hourlyRate: rate,
          currency: _currency,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEdit ? 'Modifier le projet' : 'Nouveau projet',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            // Nom
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nom du projet *',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            // Taux horaire + devise
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rate,
                    decoration: const InputDecoration(
                      labelText: 'Taux horaire *',
                      prefixIcon: Icon(Icons.euro_outlined),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Requis';
                      }
                      if (double.tryParse(
                              v.trim().replaceAll(',', '.')) ==
                          null) {
                        return 'Nombre invalide';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 12),
                // Devise selector
                DropdownButtonHideUnderline(
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _currency,
                      items: const [
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                        DropdownMenuItem(value: 'CHF', child: Text('CHF')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _currency = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_isEdit ? 'Enregistrer' : 'Créer le projet'),
            ),
          ],
        ),
      ),
    );
  }
}
