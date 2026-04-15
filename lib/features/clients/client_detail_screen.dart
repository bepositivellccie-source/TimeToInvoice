import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../core/models/client.dart';
import '../../core/models/project.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';

// ─── Screen ──────────────────────────────────────────────────────────────────

class ClientDetailScreen extends ConsumerStatefulWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientDetailScreen> createState() =>
      _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  bool _isEditing = false;
  bool _saving = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _company;
  late final TextEditingController _firstName;
  late final TextEditingController _name;
  late final TextEditingController _street;
  late final TextEditingController _zipCode;
  late final TextEditingController _city;
  late final TextEditingController _siret;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _email;
  bool _ctrlInitialized = false;

  void _initControllers(Client c) {
    if (_ctrlInitialized) return;
    _ctrlInitialized = true;
    _company = TextEditingController(text: c.company ?? '');
    _firstName = TextEditingController(text: c.firstName ?? '');
    _name = TextEditingController(text: c.name);
    _street = TextEditingController(text: c.street ?? '');
    _zipCode = TextEditingController(text: c.zipCode ?? '');
    _city = TextEditingController(text: c.city ?? '');
    _siret = TextEditingController(text: c.siret ?? '');
    _phone = TextEditingController(text: c.phone ?? '');
    _whatsapp = TextEditingController(text: c.whatsapp ?? '');
    _email = TextEditingController(text: c.email ?? '');
  }

  void _syncControllers(Client c) {
    _company.text = c.company ?? '';
    _firstName.text = c.firstName ?? '';
    _name.text = c.name;
    _street.text = c.street ?? '';
    _zipCode.text = c.zipCode ?? '';
    _city.text = c.city ?? '';
    _siret.text = c.siret ?? '';
    _phone.text = c.phone ?? '';
    _whatsapp.text = c.whatsapp ?? '';
    _email.text = c.email ?? '';
  }

  @override
  void dispose() {
    if (_ctrlInitialized) {
      for (final ctrl in [
        _company, _firstName, _name, _street, _zipCode, _city, _siret,
        _phone, _whatsapp, _email,
      ]) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save(Client current) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(clientsProvider.notifier).edit(
            id: widget.clientId,
            name: _name.text.trim(),
            firstName: _nullIfEmpty(_firstName.text),
            company: _nullIfEmpty(_company.text),
            siret: _nullIfEmpty(_siret.text),
            street: _nullIfEmpty(_street.text),
            zipCode: _nullIfEmpty(_zipCode.text),
            city: _nullIfEmpty(_city.text),
            phone: _nullIfEmpty(_phone.text),
            whatsapp: _nullIfEmpty(_whatsapp.text),
            email: _nullIfEmpty(_email.text),
          );
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Client enregistr\u00e9'),
              backgroundColor: Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelEdit(Client client) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler les modifications ?'),
        content:
            const Text('Les modifications non enregistrées seront perdues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer l\'édition'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Annuler', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      _syncControllers(client);
      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final projectsAsync =
        ref.watch(projectsByClientProvider(widget.clientId));

    final client = clientsAsync.valueOrNull
        ?.where((c) => c.id == widget.clientId)
        .firstOrNull;

    if (client == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    _initControllers(client);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fond page légèrement gris (entre les cards blanches)
    final pageBg = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: pageBg,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            // ── Header compact ─────────────────────────────────
            _ClientHeader(
              client: client,
              onBack: () => context.go('/clients'),
              isEditing: _isEditing,
              isSaving: _saving,
              onCancelEdit: () => _cancelEdit(client),
              onToggleEdit: () {
                if (_isEditing) {
                  _save(client);
                } else {
                  _syncControllers(client);
                  setState(() => _isEditing = true);
                }
              },
            ),

            SliverToBoxAdapter(
              child: Column(
                children: [
                  // ── Actions rapides (lecture only) ──────────
                  if (!_isEditing) ...[
                    _QuickActions(client: client),
                    const SizedBox(height: 16),
                  ],

                  // ── IDENTITÉ card (édition only, MD3 style) ──
                  if (_isEditing) ...[
                    _WhiteCard(
                      title: 'IDENTITÉ',
                      child: Column(
                        children: [
                          _MD3EditField(
                            label: 'Entreprise',
                            controller: _company,
                            hint: 'ex : Cabinet Dupont SARL',
                            textCapitalization: TextCapitalization.words,
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _MD3EditField(
                            label: 'Prénom',
                            controller: _firstName,
                            hint: 'Marie',
                            textCapitalization: TextCapitalization.words,
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _MD3EditField(
                            label: 'Nom *',
                            controller: _name,
                            hint: 'Dupont',
                            textCapitalization: TextCapitalization.words,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Requis' : null,
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _SiretEditField(
                            controller: _siret,
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              if (v.length != 14 || int.tryParse(v) == null) {
                                return '14 chiffres exactement';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── COORDONNÉES card (lecture OU édition) ─────
                  if (_isEditing)
                    _WhiteCard(
                      title: 'COORDONNÉES',
                      child: Column(
                        children: [
                          _MD3EditField(
                            label: 'Email',
                            controller: _email,
                            hint: 'ex : marie.dupont@gmail.com',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _MD3EditField(
                            label: 'Téléphone',
                            controller: _phone,
                            hint: 'ex : +33 6 12 34 56 78',
                            keyboardType: TextInputType.phone,
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _MD3EditField(
                            label: 'WhatsApp',
                            controller: _whatsapp,
                            hint: 'ex : +33 6 12 34 56 78',
                            keyboardType: TextInputType.phone,
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          _MD3EditField(
                            label: 'Rue',
                            controller: _street,
                            hint: 'ex : 12 rue de la Paix',
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          // CP + Ville côte à côte
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  flex: 1,
                                  child: _MD3EditField(
                                    label: 'Code postal',
                                    controller: _zipCode,
                                    hint: '75001',
                                    keyboardType: TextInputType.number,
                                    maxLength: 5,
                                    outerPadding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Flexible(
                                  flex: 2,
                                  child: _MD3EditField(
                                    label: 'Ville',
                                    controller: _city,
                                    hint: 'Paris',
                                    textCapitalization: TextCapitalization.words,
                                    textInputAction: TextInputAction.done,
                                    onSubmit: () => _save(client),
                                    outerPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _ContactCard(client: client),

                  const SizedBox(height: 16),

                  // ── Bouton Enregistrer (bas de page, mode édition) ──
                  if (_isEditing) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _saving ? null : () => _save(client),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF305DA8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Enregistrer',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],

                  // 5 — Section PROJETS (toujours visible)
                  const SizedBox(height: 32),
                  _ProjectsCard(
                    clientId: widget.clientId,
                    projectsAsync: projectsAsync,
                    onAddProject: () => _openProjectForm(context, ref),
                  ),

                  // ── Membre depuis ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
      ),
    );
  }

  void _openProjectForm(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProjectFormSheet(clientId: widget.clientId),
    );
  }
}

// ─── Header Revolut-style (avatar centré + nom + entreprise) ───────────────

class _ClientHeader extends StatelessWidget {
  final Client client;
  final VoidCallback onBack;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onToggleEdit;
  final VoidCallback? onCancelEdit;

  const _ClientHeader({
    required this.client,
    required this.onBack,
    required this.isEditing,
    required this.isSaving,
    required this.onToggleEdit,
    this.onCancelEdit,
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
      expandedHeight: 200,
      pinned: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111827)
          : const Color(0xFFF3F4F6),
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: isEditing
            ? (onCancelEdit ?? onBack)
            : onBack,
      ),
      actions: [
        if (isSaving)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: Icon(
              isEditing ? LucideIcons.check : LucideIcons.pencil,
              size: 20,
            ),
            tooltip: isEditing ? 'Enregistrer' : 'Modifier la fiche',
            onPressed: onToggleEdit,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 28),
              // ── Avatar 64px ─────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF305DA8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF305DA8).withAlpha(60),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Titre principal (entreprise si dispo, sinon nom) ──
              Text(
                hasCompany
                    ? client.company!
                    : client.fullPersonName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              // ── Sous-titre (nom civil si entreprise affichée) ──
              if (hasCompany) ...[
                const SizedBox(height: 4),
                Text(
                  client.fullPersonName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // ── SIRET sous le nom ───────────────────────────
              if (client.siret != null && client.siret!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'SIRET : ${client.siret}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick actions (4 boutons ronds, toujours visibles) ────────────────────

class _QuickActions extends ConsumerWidget {
  final Client client;

  const _QuickActions({required this.client});

  void _handleFacturer(BuildContext context, Client client) {
    final ref = ProviderScope.containerOf(context);
    final projectsAsync =
        ref.read(projectsByClientProvider(client.id));
    final projects = projectsAsync.valueOrNull ?? [];

    if (projects.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Aucun projet à facturer pour ce client'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      return;
    }

    if (projects.length == 1) {
      context.push('/invoices/new/${projects.first.id}');
      return;
    }

    // 2+ projets → bottom sheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quel projet facturer ?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...projects.map((p) {
                final statusLabel = switch (p.status) {
                  'en_attente' => 'En attente',
                  'termine' => 'Terminé',
                  _ => 'En cours',
                };
                return ListTile(
                  leading: const Icon(LucideIcons.fileText,
                      color: Color(0xFF305DA8)),
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(statusLabel),
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/invoices/new/${p.id}');
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionButton(
            icon: LucideIcons.phone,
            label: 'T\u00e9l\u00e9phone',
            color: const Color(0xFF16A34A),
            enabled: client.phone != null,
            onTap: client.phone != null
                ? () => _launchPhone(client.phone!)
                : null,
          ),
          _QuickActionButton(
            icon: LucideIcons.messageCircle,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            enabled: client.whatsapp != null &&
                client.whatsapp!.isNotEmpty &&
                client.whatsapp != client.phone,
            onTap: (client.whatsapp != null &&
                    client.whatsapp!.isNotEmpty &&
                    client.whatsapp != client.phone)
                ? () => _openWhatsApp(client.whatsapp!)
                : null,
          ),
          _QuickActionButton(
            icon: LucideIcons.mail,
            label: 'Email',
            color: const Color(0xFFEA580C),
            enabled: client.email != null,
            onTap: client.email != null
                ? () => _launchEmail(client.email!)
                : null,
          ),
          _QuickActionButton(
            icon: LucideIcons.fileText,
            label: 'Facturer',
            color: const Color(0xFF305DA8),
            enabled: true,
            onTap: () => _handleFacturer(context, client),
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
  final bool enabled;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : const Color(0xFFD1D5DB);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: effectiveColor.withAlpha(enabled ? 18 : 10),
              shape: BoxShape.circle,
              border:
                  Border.all(color: effectiveColor.withAlpha(40), width: 1.5),
            ),
            child: Icon(icon, size: 22, color: effectiveColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section COORDONNÉES (white card, dividers between rows) ───────────────

class _ContactCard extends StatelessWidget {
  final Client client;

  const _ContactCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final rows = <_ContactRowData>[];
    if (client.email != null && client.email!.isNotEmpty) {
      rows.add(_ContactRowData(
        icon: LucideIcons.mail,
        label: 'Email',
        value: client.email!,
        onTap: () async {
          final uri = Uri(scheme: 'mailto', path: client.email!);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      ));
    }
    if (client.phone != null && client.phone!.isNotEmpty) {
      rows.add(_ContactRowData(
        icon: LucideIcons.phone,
        label: 'T\u00e9l\u00e9phone',
        value: client.phone!,
        onTap: () async {
          final uri = Uri(scheme: 'tel', path: client.phone!);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      ));
    }
    if (client.whatsapp != null &&
        client.whatsapp!.isNotEmpty &&
        client.whatsapp != client.phone) {
      rows.add(_ContactRowData(
        icon: LucideIcons.messageCircle,
        label: 'WhatsApp',
        value: client.whatsapp!,
        onTap: () async {
          final clean = client.whatsapp!.replaceAll(RegExp(r'[^\d+]'), '');
          final uri = Uri.parse('https://wa.me/$clean');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ));
    }
    final fullAddr = client.fullAddress;
    if (fullAddr != null && fullAddr.isNotEmpty) {
      rows.add(_ContactRowData(
        icon: LucideIcons.mapPin,
        label: 'Adresse',
        value: fullAddr,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return _WhiteCard(
      title: 'COORDONN\u00c9ES',
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _ContactRow(data: rows[i]),
            if (i < rows.length - 1)
              const Divider(height: 1, indent: 56, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _ContactRowData {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactRowData({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
}

class _ContactRow extends StatelessWidget {
  final _ContactRowData data;

  const _ContactRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: data.value));
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Copi\u00e9 : ${data.value}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(data.icon, size: 20, color: const Color(0xFF9CA3AF)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (data.onTap != null)
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}

// _BusinessCard supprimée — FIX 3 : entreprise intégrée dans header
// Raison sociale → titre principal header, SIRET → sous le nom

// ─── Section PROJETS (white card) ──────────────────────────────────────────

class _ProjectsCard extends StatelessWidget {
  final String clientId;
  final AsyncValue<List<Project>> projectsAsync;
  final VoidCallback onAddProject;

  const _ProjectsCard({
    required this.clientId,
    required this.projectsAsync,
    required this.onAddProject,
  });

  @override
  Widget build(BuildContext context) {
    final hasProjects = projectsAsync.valueOrNull?.isNotEmpty ?? false;

    return _WhiteCard(
      title: 'PROJETS',
      trailing: hasProjects
          ? GestureDetector(
              onTap: onAddProject,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.plus,
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
            )
          : null,
      child: projectsAsync.when(
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
                    _ProjectRow(
                      project: projects[i],
                      clientId: clientId,
                    ),
                    if (i < projects.length - 1)
                      const Divider(height: 1, indent: 56, endIndent: 16),
                  ],
                ],
              ),
      ),
    );
  }
}

// ─── White card wrapper (Revolut-style) ────────────────────────────────────

class _WhiteCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _WhiteCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2937) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section title ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Project row (compact, with colored status) ────────────────────────────

class _ProjectRow extends ConsumerWidget {
  final Project project;
  final String clientId;

  const _ProjectRow({required this.project, required this.clientId});

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
      'en_cours': Color(0xFF659711),
      'en_attente': Color(0xFFFFC73A),
      'termine': Color(0xFF8E92BC),
    };
    final statusColor =
        statusColors[project.status] ?? const Color(0xFF6B7280);
    final statusLabel = switch (project.status) {
      'en_attente' => 'En attente',
      'termine' => 'Termin\u00e9',
      _ => 'En cours',
    };

    return InkWell(
      onTap: () => context.go(
          '/clients/${project.clientId}/projects/${project.id}/sessions'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Status dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            const Icon(LucideIcons.chevronRight,
                size: 16, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}

// ─── Empty projects inline ─────────────────────────────────────────────────

// ─── MD3 Edit Field — label 11px gris, focus bleu, pas d'icône ────────────

class _MD3EditField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final int? maxLength;
  final String? Function(String?)? validator;
  final VoidCallback? onSubmit;
  final EdgeInsetsGeometry? outerPadding;

  const _MD3EditField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.maxLength,
    this.validator,
    this.onSubmit,
    this.outerPadding,
  });

  @override
  State<_MD3EditField> createState() => _MD3EditFieldState();
}

class _MD3EditFieldState extends State<_MD3EditField> {
  late final FocusNode _focus;
  bool _hasFocus = false;

  static const _brand = Color(0xFF305DA8);
  static const _grey = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_hasFocus != _focus.hasFocus) {
      setState(() => _hasFocus = _focus.hasFocus);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.outerPadding ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _hasFocus ? _brand : _grey,
              letterSpacing: 0.3,
            ),
          ),
          TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            validator: widget.validator,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            maxLength: widget.maxLength,
            onFieldSubmitted:
                widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(
                  fontSize: 14, color: Color(0xFFBDBDBD)),
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _brand, width: 1.5),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDC2626), width: 1),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDC2626), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SIRET Edit Field — compteur X/14 à droite du label ───────────────────

class _SiretEditField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _SiretEditField({required this.controller, this.validator});

  @override
  State<_SiretEditField> createState() => _SiretEditFieldState();
}

class _SiretEditFieldState extends State<_SiretEditField> {
  late final FocusNode _focus;
  bool _hasFocus = false;

  static const _brand = Color(0xFF305DA8);
  static const _grey = Color(0xFF9CA3AF);

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (_hasFocus != _focus.hasFocus) {
      setState(() => _hasFocus = _focus.hasFocus);
    }
  }

  void _onTextChange() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.controller.text.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'SIRET',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _hasFocus ? _brand : _grey,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                '$count/14',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: count == 14 ? _brand : _grey,
                ),
              ),
            ],
          ),
          TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            validator: widget.validator,
            keyboardType: TextInputType.number,
            maxLength: 14,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              hintText: 'ex : 12345678901234',
              hintStyle: const TextStyle(
                  fontSize: 14, color: Color(0xFFBDBDBD)),
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _brand, width: 1.5),
              ),
              errorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDC2626), width: 1),
              ),
              focusedErrorBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDC2626), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty projects inline ─────────────────────────────────────────────────

class _EmptyProjectsInline extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyProjectsInline({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Center(
        child: FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(LucideIcons.plus, size: 18),
          label: const Text('Nouveau projet'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Project form bottom sheet ──────────────────────────────────────────────

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
                  hintText: 'ex : Site e-commerce, Refonte logo\u2026',
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
                    : Text(_isEdit ? 'Enregistrer' : 'Cr\u00e9er le projet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
