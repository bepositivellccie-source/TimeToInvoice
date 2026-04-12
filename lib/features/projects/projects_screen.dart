import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/client_display_mode_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/clients_provider.dart';
import '../clients/client_detail_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  // ── Nouveau projet : sélectionner un client d'abord ──────────────────────
  Future<void> _openNewProject() async {
    final clients = ref.read(clientsProvider).valueOrNull ?? [];

    if (clients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Créez d\'abord un client dans l\'onglet Clients'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Un seul client → ouvre directement le formulaire projet
    if (clients.length == 1) {
      _openForm(clients.first.id);
      return;
    }

    // Plusieurs clients → sélecteur
    final clientId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ClientPickerSheet(clients: clients),
    );
    if (clientId != null && mounted) {
      _openForm(clientId);
    }
  }

  void _openForm(String clientId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProjectFormSheet(clientId: clientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(timerProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau projet',
            onPressed: _openNewProject,
          ),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFFDC2626)),
              const SizedBox(height: 12),
              Text('Erreur: $e', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(timerProjectsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_open,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    const Text('Aucun projet',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    const Text(
                      'Appuyez sur + pour créer votre premier projet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _openNewProject,
                      icon: const Icon(Icons.add),
                      label: const Text('Nouveau projet'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: entries.length,
            separatorBuilder: (_, index) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = entries[i];
              final rate = e.project.hourlyRate;
              final rateStr = (rate.truncateToDouble() == rate)
                  ? rate.toInt().toString()
                  : rate.toStringAsFixed(2).replaceAll('.', ',');

              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(
                    '/clients/${e.project.clientId}'
                    '/projects/${e.project.id}/sessions',
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        // Icône projet
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: e.project.isActive
                                ? const Color(0xFFDCFCE7)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.folder_outlined,
                            color: e.project.isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Nom projet + client
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.project.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                e.clientName,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        // Taux horaire
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$rateStr ${e.project.currency}/h',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF9CA3AF), size: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Sélecteur de client (multi-client) ──────────────────────────────────────

class _ClientPickerSheet extends ConsumerWidget {
  final List clients;

  const _ClientPickerSheet({required this.clients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(clientDisplayModeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          0, 16, 0, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Titre
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choisir un client',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Liste clients
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: clients.length,
              itemBuilder: (context, i) {
                final c = clients[i];
                final label = c.labelWith(mode);
                final subtitle = c.subtitleWith(mode);
                final initials = label
                    .trim()
                    .split(' ')
                    .take(2)
                    .map((w) =>
                        (w as String).isEmpty ? '' : w[0].toUpperCase())
                    .join();
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: subtitle.isNotEmpty
                      ? Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280)))
                      : null,
                  trailing: const Icon(Icons.chevron_right,
                      color: Color(0xFF9CA3AF)),
                  onTap: () => Navigator.pop(context, c.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
