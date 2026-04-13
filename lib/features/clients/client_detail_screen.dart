import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/models/client.dart';
import '../../core/models/project.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);
    final projectsAsync = ref.watch(projectsByClientProvider(clientId));

    final client = clientsAsync.valueOrNull
        ?.where((c) => c.id == clientId)
        .firstOrNull;

    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: client == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // ── Header avec avatar + nom ────────────────────────
                _ClientHeader(
                  client: client,
                  primaryColor: primary,
                  onBack: () => context.go('/clients'),
                  onAvatarTap: () =>
                      context.push('/clients/$clientId/profile'),
                ),

                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Quick actions (appeler, whatsapp, email) ───
                      if (_hasContactInfo(client))
                        _QuickActions(client: client),

                      // ── Section Coordonnées ───────────────────────
                      _ContactSection(client: client, primaryColor: primary),

                      // ── Section Entreprise ────────────────────────
                      if (_hasBusinessInfo(client))
                        _BusinessSection(client: client),

                      // ── Section Projets ───────────────────────────
                      _ProjectsSection(
                        clientId: clientId,
                        projectsAsync: projectsAsync,
                        onAddProject: () => _openProjectForm(context, ref),
                      ),

                      // ── Membre depuis ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        child: Center(
                          child: Text(
                            'Client depuis le ${DateFormat.yMMMMd('fr_FR').format(client.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  bool _hasContactInfo(Client c) =>
      c.phone != null || c.whatsapp != null || c.email != null;

  bool _hasBusinessInfo(Client c) =>
      (c.company != null && c.company!.isNotEmpty) || c.siret != null;

  void _openProjectForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProjectFormSheet(clientId: clientId),
    );
  }
}

// ─── Header (SliverAppBar) ──────────────────────────────────────────────────

class _ClientHeader extends StatelessWidget {
  final Client client;
  final Color primaryColor;
  final VoidCallback onBack;
  final VoidCallback onAvatarTap;

  const _ClientHeader({
    required this.client,
    required this.primaryColor,
    required this.onBack,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = client.displayName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();
    final hasCompany =
        client.company != null && client.company!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 20),
          tooltip: 'Modifier la fiche',
          onPressed: onAvatarTap,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withAlpha(30),
                primaryColor.withAlpha(12),
                const Color(0xFFF9FAFB),
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                // ── Avatar ───────────────────────────────────────
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primaryColor.withAlpha(180),
                          primaryColor,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withAlpha(50),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Nom complet ──────────────────────────────────
                Text(
                  client.fullPersonName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                // ── Entreprise ───────────────────────────────────
                if (hasCompany) ...[
                  const SizedBox(height: 4),
                  Text(
                    client.company!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Quick actions (boutons ronds) ──────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final Client client;

  const _QuickActions({required this.client});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (client.phone != null)
            _QuickActionButton(
              icon: Icons.phone_outlined,
              label: 'Appeler',
              color: const Color(0xFF2563EB),
              onTap: () => _launchPhone(client.phone!),
            ),
          if (client.phone != null &&
              (client.whatsapp != null || client.email != null))
            const SizedBox(width: 24),
          if (client.whatsapp != null)
            _QuickActionButton(
              icon: Icons.chat_bubble_outline,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: () => _openWhatsApp(client.whatsapp!),
            ),
          if (client.whatsapp != null && client.email != null)
            const SizedBox(width: 24),
          if (client.email != null)
            _QuickActionButton(
              icon: Icons.email_outlined,
              label: 'Email',
              color: const Color(0xFFEA580C),
              onTap: () => _launchEmail(client.email!),
            ),
        ],
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha(40), width: 1.5),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Coordonnées ────────────────────────────────────────────────────

class _ContactSection extends StatelessWidget {
  final Client client;
  final Color primaryColor;

  const _ContactSection({
    required this.client,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = client.phone != null && client.phone!.isNotEmpty;
    final hasWhatsapp = client.whatsapp != null && client.whatsapp!.isNotEmpty;
    final hasEmail = client.email != null && client.email!.isNotEmpty;
    final hasAddress = client.address != null && client.address!.isNotEmpty;

    if (!hasPhone && !hasWhatsapp && !hasEmail && !hasAddress) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      title: 'Coordonnées',
      icon: Icons.contact_mail_outlined,
      children: [
        if (hasPhone)
          _InfoRow(
            icon: Icons.phone_outlined,
            label: 'Téléphone',
            value: client.phone!,
            iconColor: const Color(0xFF2563EB),
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: client.phone!);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            onLongPress: () => _copyToClipboard(context, client.phone!),
          ),
        if (hasWhatsapp)
          _InfoRow(
            icon: Icons.chat_bubble_outline,
            label: 'WhatsApp',
            value: client.whatsapp!,
            iconColor: const Color(0xFF25D366),
            onTap: () async {
              final clean = client.whatsapp!.replaceAll(RegExp(r'[^\d+]'), '');
              final uri = Uri.parse('https://wa.me/$clean');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            onLongPress: () => _copyToClipboard(context, client.whatsapp!),
          ),
        if (hasEmail)
          _InfoRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: client.email!,
            iconColor: const Color(0xFFEA580C),
            onTap: () async {
              final uri = Uri(scheme: 'mailto', path: client.email!);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            onLongPress: () => _copyToClipboard(context, client.email!),
          ),
        if (hasAddress)
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: 'Adresse',
            value: client.address!,
            iconColor: const Color(0xFF7C3AED),
            onTap: () async {
              final query = Uri.encodeComponent(client.address!);
              final uri = Uri.parse('https://maps.google.com/?q=$query');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            onLongPress: () => _copyToClipboard(context, client.address!),
          ),
      ],
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copié : $text'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─── Section Entreprise ─────────────────────────────────────────────────────

class _BusinessSection extends StatelessWidget {
  final Client client;

  const _BusinessSection({required this.client});

  @override
  Widget build(BuildContext context) {
    final hasCompany = client.company != null && client.company!.isNotEmpty;
    final hasSiret = client.siret != null && client.siret!.isNotEmpty;

    return _SectionCard(
      title: 'Entreprise',
      icon: Icons.business_outlined,
      children: [
        if (hasCompany)
          _InfoRow(
            icon: Icons.domain_outlined,
            label: 'Raison sociale',
            value: client.company!,
            iconColor: const Color(0xFF0891B2),
          ),
        if (hasSiret)
          _InfoRow(
            icon: Icons.tag_outlined,
            label: 'SIRET',
            value: client.siret!,
            iconColor: const Color(0xFF6B7280),
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: client.siret!));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('SIRET copié : ${client.siret}'),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
      ],
    );
  }
}

// ─── Section Projets ────────────────────────────────────────────────────────

class _ProjectsSection extends StatelessWidget {
  final String clientId;
  final AsyncValue<List<Project>> projectsAsync;
  final VoidCallback onAddProject;

  const _ProjectsSection({
    required this.clientId,
    required this.projectsAsync,
    required this.onAddProject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Titre section ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 12),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined,
                    size: 18, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Projets',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF374151),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Material(
                  color: Theme.of(context).colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onAddProject,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Projet',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Liste projets ──────────────────────────────────
          projectsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: Text('Erreur: $e')),
            ),
            data: (projects) => projects.isEmpty
                ? _EmptyProjectsInline(onAdd: onAddProject)
                : Column(
                    children: [
                      for (int i = 0; i < projects.length; i++) ...[
                        _ProjectTile(
                          project: projects[i],
                          clientId: clientId,
                        ),
                        if (i < projects.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Section card wrapper ───────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Builder(
        builder: (context) {
        final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
        final borderColor = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF334155)
            : const Color(0xFFE5E7EB);
        return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // ── Rows ─────────────────────────────────────────
            ...children,
            const SizedBox(height: 8),
          ],
        ),
      );
        },
      ),
    );
  }
}

// ─── Info row ───────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 18,
                color: iconColor.withAlpha(100),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Project tile — navigation vers sessions ───────────────────────────────

class _ProjectTile extends ConsumerWidget {
  final Project project;
  final String clientId;
  const _ProjectTile({required this.project, required this.clientId});

  static String _fmtHHMMSS(int secs) {
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(projectsTotalSecondsProvider).valueOrNull ?? {};
    final totalSecs = totals[project.id] ?? 0;

    const statusColors = {
      'en_cours': Color(0xFF659711),   // FigmaSuccess.c700
      'en_attente': Color(0xFFFFC73A), // FigmaWarning.c500
      'termine': Color(0xFF8E92BC),    // FigmaSecondary.c300
    };
    final statusColor = statusColors[project.status] ?? const Color(0xFF6B7280);
    final statusLabel = switch (project.status) {
      'en_attente' => 'En attente',
      'termine' => 'Terminé',
      _ => 'En cours',
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(
            '/clients/${project.clientId}/projects/${project.id}/sessions'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.folder_outlined,
                    color: statusColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _fmtHHMMSS(totalSecs),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 20, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty projects inline ──────────────────────────────────────────────────

class _EmptyProjectsInline extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyProjectsInline({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withAlpha(100)),
            const SizedBox(height: 12),
            const Text('Aucun projet',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Créez un projet pour commencer\nà tracker du temps.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nouveau projet'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Project form bottom sheet ───────────────────────────────────────────────

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

  static const _kLastRate = 'last_hourly_rate';

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _rate = TextEditingController(
        text: p != null ? p.hourlyRate.toStringAsFixed(0) : '');
    _currency = p?.currency ?? 'EUR';
    if (!_isEdit) _loadLastRate();
  }

  Future<void> _loadLastRate() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getDouble(_kLastRate);
    if (last != null && mounted && _rate.text.isEmpty) {
      _rate.text = last == last.truncateToDouble()
          ? last.toInt().toString()
          : last.toStringAsFixed(2);
    }
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kLastRate, rate);

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

  static IconData _currencyIcon(String currency) => switch (currency) {
        'USD' => Icons.attach_money,
        'GBP' => Icons.currency_pound,
        'CHF' => Icons.money,
        _ => Icons.euro_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: SingleChildScrollView(
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
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nom du projet *',
                  hintText: 'ex : Site e-commerce, Refonte logo…',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rate,
                      decoration: InputDecoration(
                        labelText: 'Taux horaire *',
                        hintText: 'ex : 75',
                        prefixIcon: Icon(_currencyIcon(_currency)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Requis';
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
                  DropdownButtonHideUnderline(
                    child: Container(
                      height: 52,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButton<String>(
                        value: _currency,
                        items: const [
                          DropdownMenuItem(
                              value: 'EUR', child: Text('EUR')),
                          DropdownMenuItem(
                              value: 'USD', child: Text('USD')),
                          DropdownMenuItem(
                              value: 'GBP', child: Text('GBP')),
                          DropdownMenuItem(
                              value: 'CHF', child: Text('CHF')),
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
      ),
    );
  }
}
