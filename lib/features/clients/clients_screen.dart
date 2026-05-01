import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/client.dart';
import '../../core/providers/client_display_mode_provider.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/theme/app_colors.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';

  // Un GlobalKey stable par lettre — assigné au premier client de chaque lettre
  final Map<String, GlobalKey> _letterKeys = {
    for (final l in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) l: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToLetter(String letter) {
    final key = _letterKeys[letter];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: 0.0, // cible en haut de la zone visible
      );
    }
  }

  void _openForm(BuildContext context, Client? existing) {
    if (existing == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewClientFormScreen()),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ClientFormSheet(existing: existing),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final mode = ref.watch(clientDisplayModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Retour',
          onPressed: () => context.go('/menu'),
        ),
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nouveau client',
            onPressed: () => _openForm(context, null),
          ),
        ],
      ),
      body: clientsAsync.when(
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
                onPressed: () => ref.invalidate(clientsProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (clients) {
          if (clients.isEmpty) {
            return _EmptyState(onAdd: () => _openForm(context, null));
          }

          // ── Tri : billing_status (overdue > pending > clear > new), puis label ─
          int billingPriority(String s) => switch (s) {
                'overdue' => 0,
                'pending' => 1,
                'clear' => 2,
                _ => 3,
              };
          final sorted = [...clients]
            ..sort((a, b) {
              final pa = billingPriority(a.billingStatus);
              final pb = billingPriority(b.billingStatus);
              if (pa != pb) return pa.compareTo(pb);
              return a
                  .labelWith(mode)
                  .toLowerCase()
                  .compareTo(b.labelWith(mode).toLowerCase());
            });

          // ── Premier index par lettre + lettres actives (A-Z seulement)
          final activeLetters = <String>{};
          final letterFirstIndex = <String, int>{};
          for (int i = 0; i < sorted.length; i++) {
            final label = sorted[i].labelWith(mode);
            if (label.isEmpty) continue;
            final l = label[0].toUpperCase();
            if (l.codeUnitAt(0) < 65 || l.codeUnitAt(0) > 90) continue;
            activeLetters.add(l);
            letterFirstIndex.putIfAbsent(l, () => i);
          }

          // ── Filtre recherche — startsWith sur labelWith(mode) uniquement
          final displayed = _query.isEmpty
              ? sorted
              : sorted
                  .where((c) =>
                      c.labelWith(mode).toLowerCase().startsWith(_query))
                  .toList();

          // L'index n'est visible qu'en mode navigation (pas en recherche)
          final showIndex = _query.isEmpty;

          // ── Construction des tiles avec clés alphabétiques ────────────
          final tiles = <Widget>[];
          for (int i = 0; i < displayed.length; i++) {
            if (i > 0) tiles.add(const SizedBox(height: 8));
            final c = displayed[i];
            final label = c.labelWith(mode);
            final l = label.isNotEmpty ? label[0].toUpperCase() : '';
            // Assigne le GlobalKey au premier client de chaque lettre
            final key =
                (showIndex && letterFirstIndex[l] == i) ? _letterKeys[l] : null;
            tiles.add(_ClientTile(
              key: key,
              client: c,
              onDelete: () =>
                  ref.read(clientsProvider.notifier).delete(c.id),
            ));
          }

          return Column(
            children: [
              // ── Barre de recherche ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceFill(context),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // ── Liste + index alphabétique ─────────────────────────────
              Expanded(
                child: displayed.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun résultat pour "$_query"',
                          style: TextStyle(color: AppColors.textTertiary(context)),
                        ),
                      )
                    : Stack(
                        children: [
                          // Liste — padding droit réduit pour laisser place à l'index
                          SingleChildScrollView(
                            controller: _scrollCtrl,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                  16, 8, showIndex ? 28 : 16, 32),
                              child: Column(children: tiles),
                            ),
                          ),

                          // Index latéral A→Z
                          if (showIndex)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: _AlphaIndex(
                                activeLetters: activeLetters,
                                onLetterTap: _scrollToLetter,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Index alphabétique latéral ──────────────────────────────────────────────

class _AlphaIndex extends StatelessWidget {
  final Set<String> activeLetters;
  final void Function(String) onLetterTap;

  const _AlphaIndex({
    required this.activeLetters,
    required this.onLetterTap,
  });

  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  void _hitTest(double dy, double totalHeight) {
    if (totalHeight <= 0) return;
    final index = ((dy / totalHeight) * _alphabet.length)
        .floor()
        .clamp(0, _alphabet.length - 1);
    final l = _alphabet[index];
    if (activeLetters.contains(l)) onLetterTap(l);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _hitTest(d.localPosition.dy, constraints.maxHeight),
          onPanUpdate: (d) => _hitTest(d.localPosition.dy, constraints.maxHeight),
          child: SizedBox(
            width: 24,
            height: constraints.maxHeight,
            child: Column(
              children: _alphabet.split('').map((l) {
                final active = activeLetters.contains(l);
                return Expanded(
                  child: Center(
                    child: Text(
                      l,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            active ? FontWeight.w700 : FontWeight.w400,
                        color: active ? primary : AppColors.borderStrong(context),
                        height: 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

// ─── Tile — swipe bidirectionnel : droite = supprimer, gauche = modifier ─────

class _ClientTile extends ConsumerStatefulWidget {
  final Client client;
  final VoidCallback onDelete;

  const _ClientTile({
    super.key,
    required this.client,
    required this.onDelete,
  });

  @override
  ConsumerState<_ClientTile> createState() => _ClientTileState();
}

/// Icône double flèche qui apparaît brièvement au toggle.
const _kToggleArrowDuration = Duration(milliseconds: 800);

class _ClientTileState extends ConsumerState<_ClientTile>
    {
  static const _deleteRevealWidth = 72.0;

  double _dragOffset = 0;
  bool _showToggleArrow = false;

  void _onToggleTap() {
    ref.read(clientDisplayModeProvider.notifier).toggle();
    setState(() => _showToggleArrow = true);
    Future.delayed(_kToggleArrowDuration, () {
      if (mounted) setState(() => _showToggleArrow = false);
    });
  }

  void _resetPosition() => setState(() => _dragOffset = 0);

  Future<void> _showDeleteDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce client ?'),
        content: Text(
          '${widget.client.displayName} sera supprimé ainsi que tous ses projets et sessions.',
        ),
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
    if (!mounted) return;
    if (confirmed == true) {
      widget.onDelete();
    } else {
      _resetPosition();
    }
  }


  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(clientDisplayModeProvider);
    final label = widget.client.labelWith(mode);
    final subtitle = widget.client.subtitleWith(mode);
    final isCompanyMode = mode == 'company';

    final screenWidth = MediaQuery.sizeOf(context).width;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          // ── Fond rouge (swipe gauche → supprimer) ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showDeleteDialog,
                child: SizedBox(
                  width: _deleteRevealWidth,
                  child: const Center(
                    child: Icon(LucideIcons.trash2,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
          // ── Card glissante ─────────────────────────────────────────
          AnimatedContainer(
            duration: Duration(
                milliseconds:
                    (_dragOffset == 0 || _dragOffset == -_deleteRevealWidth)
                        ? 200
                        : 0),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragOffset = (_dragOffset + details.delta.dx)
                      .clamp(-screenWidth, 0.0);
                });
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;

                // Swipe gauche → snap révèle supprimer
                if (_dragOffset < 0) {
                  if (_dragOffset < -_deleteRevealWidth * 0.4 || velocity < -300) {
                    setState(() => _dragOffset = -_deleteRevealWidth);
                  } else {
                    _resetPosition();
                  }
                }
              },
              child: Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.go('/clients/${widget.client.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // ── Avatar toggle (tap = switch mode) ─────────
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _onToggleTap,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isCompanyMode
                                      ? Theme.of(context).colorScheme.primary.withAlpha(20)
                                      : AppColors.surfaceFill(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCompanyMode
                                        ? Theme.of(context).colorScheme.primary.withAlpha(60)
                                        : AppColors.border(context),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    child: SvgPicture.asset(
                                      isCompanyMode
                                          ? 'assets/icons/Entreprise.svg'
                                          : 'assets/icons/profil-actif.svg',
                                      key: ValueKey(isCompanyMode),
                                      width: 20,
                                      height: 20,
                                      colorFilter: ColorFilter.mode(
                                        isCompanyMode
                                            ? const Color(0xFF4B5563)
                                            : const Color(0xFF305DA8),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // ── Double flèche toggle ──────────
                              AnimatedOpacity(
                                opacity: _showToggleArrow ? 1.0 : 0.0,
                                duration: Duration(
                                    milliseconds:
                                        _showToggleArrow ? 100 : 400),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white).withAlpha(200),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.swap_vert,
                                    size: 18,
                                    color: AppColors.textBody(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // ── Nom + sous-titre (tap = ouvre fiche) ──────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      transitionBuilder:
                                          (child, animation) => FadeTransition(
                                              opacity: animation,
                                              child: child),
                                      layoutBuilder:
                                          (currentChild, previousChildren) =>
                                              Stack(
                                        alignment: Alignment.centerLeft,
                                        children: [
                                          ...previousChildren,
                                          ?currentChild,
                                        ],
                                      ),
                                      child: Text(
                                        label,
                                        key: ValueKey(label),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  _BillingBadge(status: widget.client.billingStatus),
                                ],
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(subtitle,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary(context))),
                              ],
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            size: 20, color: AppColors.textTertiary(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Badge statut facturation ────────────────────────────────────────────────

class _BillingBadge extends StatelessWidget {
  final String status;

  const _BillingBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'overdue' => (label: 'Impayé', color: const Color(0xFFEF4444)),
      'pending' => (label: 'En attente', color: const Color(0xFFF97316)),
      _ => null,
    };
    if (config == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: config.color.withAlpha(31),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          config.label,
          style: TextStyle(
            fontSize: 11,
            color: config.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            const Text('Aucun client',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Créez votre premier client pour commencer à tracker du temps.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau client'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Formulaire / fiche client ────────────────────────────────────────────────
//
//  Consultation par défaut (existing != null) → crayon → mode édition.
//  Nouveau client → édition directe.

class ClientFormSheet extends ConsumerStatefulWidget {
  final Client? existing;
  const ClientFormSheet({super.key, this.existing});

  @override
  ConsumerState<ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends ConsumerState<ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
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
  bool _saving = false;
  bool _optionalExpanded = false;
  late bool _editMode;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    // Existant → consultation d'abord ; nouveau → édition directe
    _editMode = !_isEdit;
    final c = widget.existing;
    _company = TextEditingController(text: c?.company ?? '');
    _firstName = TextEditingController(text: c?.firstName ?? '');
    _name = TextEditingController(text: c?.name ?? '');
    _street = TextEditingController(text: c?.street ?? '');
    _zipCode = TextEditingController(text: c?.zipCode ?? '');
    _city = TextEditingController(text: c?.city ?? '');
    _siret = TextEditingController(text: c?.siret ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _whatsapp = TextEditingController(text: c?.whatsapp ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _optionalExpanded = _isEdit &&
        (c!.siret?.isNotEmpty == true ||
            c.street?.isNotEmpty == true ||
            c.zipCode?.isNotEmpty == true ||
            c.city?.isNotEmpty == true);
  }

  @override
  void dispose() {
    for (final ctrl in [
      _company, _firstName, _name, _street, _zipCode, _city, _siret, _phone, _whatsapp, _email
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final notifier = ref.read(clientsProvider.notifier);
      final args = (
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
      if (_isEdit) {
        await notifier.edit(
          id: widget.existing!.id,
          name: args.name,
          firstName: args.firstName,
          company: args.company,
          siret: args.siret,
          street: args.street,
          zipCode: args.zipCode,
          city: args.city,
          phone: args.phone,
          whatsapp: args.whatsapp,
          email: args.email,
        );
      } else {
        await notifier.create(
          name: args.name,
          firstName: args.firstName,
          company: args.company,
          siret: args.siret,
          street: args.street,
          zipCode: args.zipCode,
          city: args.city,
          phone: args.phone,
          whatsapp: args.whatsapp,
          email: args.email,
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openWhatsApp(String number) async {
    final clean = number.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final c = widget.existing;

    // Titre : entreprise → nom civil
    final sheetTitle = _editMode
        ? 'Modifier'
        : (c!.company?.isNotEmpty == true ? c.company! : c.fullPersonName);

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // ── En-tête : Annuler / titre centré / Créer ou Enregistrer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Text(
                    sheetTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_editMode)
                  _saving
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(
                          onPressed: _save,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF305DA8),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(
                            _isEdit ? 'Enregistrer' : 'Créer',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        )
                else
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Modifier',
                    color: const Color(0xFF6B7280),
                    onPressed: () => setState(() => _editMode = true),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Contenu défilable ────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, 24 + (_editMode ? bottom : 0)),
              child: _editMode ? _buildForm(context) : _buildView(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode consultation ────────────────────────────────────────────────────────

  Widget _buildView() {
    final c = widget.existing!;
    final hasExtra = c.fullAddress != null ||
        c.siret != null ||
        c.phone != null ||
        c.whatsapp != null ||
        c.email != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Entreprise (gras)
        if (c.company != null && c.company!.isNotEmpty)
          _ViewRow(
            icon: Icons.business_outlined,
            text: c.company!,
            bold: true,
          ),
        // Nom civil
        _ViewRow(icon: LucideIcons.userCircle2, text: c.fullPersonName),
        // Séparateur avant les infos complémentaires
        if (hasExtra) ...[
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),
        ],
        if (c.fullAddress != null)
          _ViewRow(icon: Icons.location_on_outlined, text: c.fullAddress!),
        if (c.siret != null)
          _ViewRow(icon: Icons.tag_outlined, text: 'SIRET : ${c.siret}'),
        if (c.phone != null)
          _ViewRow(
            icon: Icons.phone_outlined,
            text: c.phone!,
            onTap: () => _launchPhone(c.phone!),
          ),
        if (c.whatsapp != null)
          _ViewRow(
            icon: Icons.chat_bubble_outline,
            text: c.whatsapp!,
            iconColor: const Color(0xFF25D366),
            onTap: () => _openWhatsApp(c.whatsapp!),
          ),
        if (c.email != null)
          _ViewRow(
            icon: Icons.email_outlined,
            text: c.email!,
            onTap: () => _launchEmail(c.email!),
          ),
        // Aucune info complémentaire
        if (!hasExtra && (c.company == null || c.company!.isEmpty))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Aucune information complémentaire.',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ),
      ],
    );
  }

  // ── Mode édition ─────────────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── IDENTITÉ ──────────────────────────────────────────────
          const _MD3SectionHeader(title: 'IDENTITÉ'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MD3Field(
                  label: 'Prénom',
                  hint: 'Marie',
                  controller: _firstName,
                  autofocus: !_isEdit,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _MD3Field(
                  label: 'Nom *',
                  hint: 'Dupont',
                  controller: _name,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          _MD3Field(
            label: 'Entreprise / raison sociale',
            hint: 'ex : Cabinet Dupont SARL',
            controller: _company,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),

          // ── CONTACT ───────────────────────────────────────────────
          const _MD3SectionHeader(title: 'CONTACT'),
          _MD3Field(
            label: 'Email',
            hint: 'ex : marie.dupont@gmail.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          _MD3Field(
            label: 'Téléphone',
            hint: '+33 6 12 34 56 78',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          _MD3Field(
            label: 'WhatsApp',
            hint: '+33 6 12 34 56 78',
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefix: const _WhatsAppIcon(),
            suffix: _whatsapp.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    tooltip: 'Ouvrir WhatsApp',
                    onPressed: () => _openWhatsApp(_whatsapp.text),
                  )
                : null,
            onChanged: () => setState(() {}),
          ),

          // ── ADRESSE (collapsible) ─────────────────────────────────
          const SizedBox(height: 14),
          InkWell(
            onTap: () =>
                setState(() => _optionalExpanded = !_optionalExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Text(
                    'ADRESSE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _optionalExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: const Color(0xFF6B7280),
                  ),
                ],
              ),
            ),
          ),
          if (_optionalExpanded) ...[
            _MD3Field(
              label: 'Rue',
              hint: 'ex : 12 rue de la Paix',
              controller: _street,
              textInputAction: TextInputAction.next,
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: _MD3Field(
                    label: 'Code postal',
                    hint: '75001',
                    controller: _zipCode,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _MD3Field(
                    label: 'Ville',
                    hint: 'Paris',
                    controller: _city,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            _MD3Field(
              label: 'SIRET (14 chiffres)',
              hint: 'ex : 12345678901234',
              controller: _siret,
              keyboardType: TextInputType.number,
              maxLength: 14,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (v.length != 14 || int.tryParse(v) == null) {
                  return '14 chiffres exactement';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Ligne de consultation ────────────────────────────────────────────────────

class _ViewRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;
  final Color? iconColor;
  final VoidCallback? onTap;

  const _ViewRow({
    required this.icon,
    required this.text,
    this.bold = false,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: iconColor ??
                  (bold ? const Color(0xFF305DA8) : const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: bold ? 15 : 14,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                  color: bold
                      ? const Color(0xFF111827)
                      : const Color(0xFF374151),
                ),
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// ─── Icône WhatsApp (cercle vert + W) ────────────────────────────────────────

class _WhatsAppIcon extends StatelessWidget {
  const _WhatsAppIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0xFF25D366),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            'W',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MD3 helpers : section header + field ────────────────────────────────────

class _MD3SectionHeader extends StatelessWidget {
  final String title;
  const _MD3SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7280),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _MD3Field extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final bool autofocus;
  final VoidCallback? onChanged;
  final ValueChanged<String>? onFieldSubmitted;

  const _MD3Field({
    required this.label,
    this.hint,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.autofocus = false,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          validator: validator,
          maxLength: maxLength,
          onChanged: onChanged != null ? (_) => onChanged!() : null,
          onFieldSubmitted: onFieldSubmitted,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: Color(0xFFBDBDBD),
              fontSize: 15,
            ),
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.transparent,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF305DA8), width: 1.5),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEF4444), width: 0.5),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

// ─── Card de champ — élévation 3 états + check tappable ────────────────────

class _ClientFieldCard extends StatefulWidget {
  final IconData icon;
  final IconData? focusedIcon;
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onValidate;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final String? errorText;

  const _ClientFieldCard({
    required this.icon,
    this.focusedIcon,
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.onValidate,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.errorText,
  });

  @override
  State<_ClientFieldCard> createState() => _ClientFieldCardState();
}

class _ClientFieldCardState extends State<_ClientFieldCard> {
  bool _focused = false;
  bool _isValidated = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    if (widget.focusNode.hasFocus != _focused) {
      setState(() {
        _focused = widget.focusNode.hasFocus;
        // Auto-validation : quitter un champ rempli le fait passer en état validé
        // (sans avoir à tapper explicitement le check).
        if (!_focused && widget.controller.text.trim().isNotEmpty) {
          _isValidated = true;
        }
      });
    }
  }

  void _handleTextChange() {
    if (!mounted) return;
    final txt = widget.controller.text;
    if (txt == _lastText) return;
    _lastText = txt;
    // La validation persiste tant que le champ contient du texte.
    // Effacer le contenu repasse en non-validé (le check redevient outline).
    setState(() {
      if (_isValidated && txt.trim().isEmpty) _isValidated = false;
    });
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _onCheckTap() {
    if (_isValidated) return;
    if (widget.controller.text.trim().isEmpty) return;
    setState(() => _isValidated = true);
    widget.onValidate();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final showAccent = _focused || _isValidated;

    // ── Card border + shadow ──
    // Actif (focused) → green border 2px + shadow (élévation).
    // Validé OU idle → gray border 1px, pas d'ombre (posé).
    final Color borderColor;
    final double borderWidth;
    final List<BoxShadow> shadows;
    if (hasError) {
      borderColor = const Color(0xFFEF4444);
      borderWidth = 2;
      shadows = const [];
    } else if (_focused) {
      borderColor = const Color(0xFF05B89C);
      borderWidth = 2;
      shadows = const [
        BoxShadow(
          color: Color.fromRGBO(5, 184, 156, 0.18),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
    } else {
      borderColor = const Color(0xFFE5E7EB);
      borderWidth = 1;
      shadows = const [];
    }

    // ── Field icon + label : verts en actif OU validé ──
    final Color accentColor =
        showAccent ? const Color(0xFF05B89C) : const Color(0xFF6B7280);
    final FontWeight labelWeight =
        showAccent ? FontWeight.w600 : FontWeight.w400;
    final IconData displayIcon = showAccent && widget.focusedIcon != null
        ? widget.focusedIcon!
        : widget.icon;

    // ── Check pastille ──
    // Idle (hasText && !showAccent) : gris + border circle gris.
    // Actif OU validé : icône verte, pas de border.
    final Color checkColor =
        showAccent ? const Color(0xFF05B89C) : const Color(0xFF9CA3AF);
    final Color checkBorderColor =
        showAccent ? Colors.transparent : const Color(0xFFE5E7EB);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(displayIcon, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: labelWeight,
                        color: accentColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: hasText ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !hasText,
                      child: GestureDetector(
                        onTap: _onCheckTap,
                        behavior: HitTestBehavior.opaque,
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                                border: Border.all(
                                  color: checkBorderColor,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: checkColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: widget.autofocus,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                maxLength: widget.maxLength,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF111827),
                ),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 18,
                    color: const Color(0xFF9CA3AF),
                  ),
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              widget.errorText!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Toggle "Plus d'infos" ──────────────────────────────────────────────────

class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  const _ExpandToggle({
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      onVerticalDragEnd: (_) => onToggle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Plus d'infos · optionnel",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF374151),
                ),
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: const Icon(
                LucideIcons.chevronDown,
                size: 20,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page plein écran : Nouveau client ──────────────────────────────────────

class NewClientFormScreen extends ConsumerStatefulWidget {
  const NewClientFormScreen({super.key});

  @override
  ConsumerState<NewClientFormScreen> createState() =>
      _NewClientFormScreenState();
}

class _NewClientFormScreenState extends ConsumerState<NewClientFormScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _company = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _street = TextEditingController();
  final _zipCode = TextEditingController();
  final _city = TextEditingController();
  final _siret = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _companyFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _whatsappFocus = FocusNode();
  final _streetFocus = FocusNode();
  final _zipFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _siretFocus = FocusNode();

  bool _saving = false;
  bool _optionalExpanded = false;
  String? _emailError;
  String? _siretError;

  bool get _isFormValid => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Rebuild AppBar "Créer" button enabled state on name changes.
    _name.addListener(_onNameChange);
    // Clear inline errors as soon as the value becomes valid again
    // (no nag during typing, but corrections are reflected immediately).
    _email.addListener(_onEmailChange);
    _siret.addListener(_onSiretChange);
  }

  void _onNameChange() {
    if (mounted) setState(() {});
  }

  void _onEmailChange() {
    if (!mounted || _emailError == null) return;
    final txt = _email.text.trim();
    if (txt.isEmpty || txt.contains('@')) {
      setState(() => _emailError = null);
    }
  }

  void _onSiretChange() {
    if (!mounted || _siretError == null) return;
    final txt = _siret.text.trim();
    if (txt.isEmpty || (txt.length == 14 && int.tryParse(txt) != null)) {
      setState(() => _siretError = null);
    }
  }

  @override
  void dispose() {
    _name.removeListener(_onNameChange);
    _email.removeListener(_onEmailChange);
    _siret.removeListener(_onSiretChange);
    for (final c in [
      _name, _email, _firstName, _company, _phone, _whatsapp,
      _street, _zipCode, _city, _siret,
    ]) {
      c.dispose();
    }
    for (final f in [
      _nameFocus, _emailFocus, _firstNameFocus, _companyFocus,
      _phoneFocus, _whatsappFocus, _streetFocus, _zipFocus,
      _cityFocus, _siretFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  bool _validateEmail() {
    final txt = _email.text.trim();
    final err =
        (txt.isNotEmpty && !txt.contains('@')) ? 'Email invalide' : null;
    if (err != _emailError) setState(() => _emailError = err);
    return err == null;
  }

  bool _validateSiret() {
    final txt = _siret.text.trim();
    final err = (txt.isNotEmpty &&
            (txt.length != 14 || int.tryParse(txt) == null))
        ? 'SIRET : 14 chiffres requis'
        : null;
    if (err != _siretError) setState(() => _siretError = err);
    return err == null;
  }

  Future<void> _submitNewClient() async {
    if (!_isFormValid || _saving) return;
    final emailOk = _validateEmail();
    final siretOk = _validateSiret();
    if (!emailOk || !siretOk) {
      if (!siretOk && !_optionalExpanded) {
        setState(() => _optionalExpanded = true);
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(clientsProvider.notifier).create(
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
      if (mounted) Navigator.pop(context, true);
    } catch (e, st) {
      debugPrint('🔴 Client creation error: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        leadingWidth: 100,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF6B7280),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Text(
            'Annuler',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        title: Text(
          'Nouveau client',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF111827),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_isFormValid && !_saving) ? _submitNewClient : null,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF05B89C),
              disabledForegroundColor: const Color(0xFFD1D5DB),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Créer',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: _isFormValid
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: Color(0xFFE5E7EB),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ClientFieldCard(
              icon: LucideIcons.user,
              focusedIcon: Icons.person,
              label: 'Nom du client',
              hint: 'Rocher, Maison Pierre, Cabinet Dupont',
              controller: _name,
              focusNode: _nameFocus,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onValidate: () => _emailFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Le nom suffit. Vous pourrez compléter plus tard.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ClientFieldCard(
              icon: LucideIcons.mail,
              focusedIcon: Icons.email,
              label: 'Email · optionnel',
              hint: 'ex : contact@cabinet-dupon',
              controller: _email,
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: _emailError,
              onValidate: () {
                if (!_validateEmail()) return;
                if (_optionalExpanded) {
                  _firstNameFocus.requestFocus();
                } else {
                  _submitNewClient();
                }
              },
            ),
            const SizedBox(height: 28),
            _ExpandToggle(
              expanded: _optionalExpanded,
              onToggle: () => setState(
                () => _optionalExpanded = !_optionalExpanded,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _optionalExpanded
                  ? _buildExpandedFields()
                  : const SizedBox(width: double.infinity, height: 0),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _ClientFieldCard(
          icon: LucideIcons.user,
          focusedIcon: Icons.person,
          label: 'Prénom · optionnel',
          hint: 'Sophie',
          controller: _firstName,
          focusNode: _firstNameFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onValidate: () => _companyFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        _ClientFieldCard(
          icon: LucideIcons.briefcase,
          focusedIcon: Icons.business,
          label: 'Société · optionnel',
          hint: 'SARL Dupont',
          controller: _company,
          focusNode: _companyFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onValidate: () => _phoneFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        _ClientFieldCard(
          icon: LucideIcons.phone,
          focusedIcon: Icons.phone,
          label: 'Téléphone · optionnel',
          hint: '06 12 34 56 78',
          controller: _phone,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onValidate: () => _whatsappFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        _ClientFieldCard(
          icon: LucideIcons.messageCircle,
          focusedIcon: Icons.chat,
          label: 'WhatsApp · optionnel',
          hint: '06 12 34 56 78',
          controller: _whatsapp,
          focusNode: _whatsappFocus,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          onValidate: () => _streetFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        _ClientFieldCard(
          icon: LucideIcons.mapPin,
          focusedIcon: Icons.location_on,
          label: 'Rue · optionnel',
          hint: '12 rue de la Paix',
          controller: _street,
          focusNode: _streetFocus,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onValidate: () => _zipFocus.requestFocus(),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: _ClientFieldCard(
                icon: LucideIcons.hash,
                focusedIcon: Icons.numbers,
                label: 'CP · optionnel',
                hint: '75001',
                controller: _zipCode,
                focusNode: _zipFocus,
                keyboardType: TextInputType.number,
                maxLength: 5,
                textInputAction: TextInputAction.next,
                onValidate: () => _cityFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ClientFieldCard(
                icon: LucideIcons.building2,
                focusedIcon: Icons.location_city,
                label: 'Ville · optionnel',
                hint: 'Paris',
                controller: _city,
                focusNode: _cityFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                onValidate: () => _siretFocus.requestFocus(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ClientFieldCard(
          icon: LucideIcons.fileText,
          focusedIcon: Icons.description,
          label: 'SIRET · optionnel',
          hint: '123 456 789 01234',
          controller: _siret,
          focusNode: _siretFocus,
          keyboardType: TextInputType.number,
          maxLength: 14,
          errorText: _siretError,
          textInputAction: TextInputAction.done,
          onValidate: () {
            if (!_validateSiret()) return;
            _submitNewClient();
          },
        ),
      ],
    );
  }
}
