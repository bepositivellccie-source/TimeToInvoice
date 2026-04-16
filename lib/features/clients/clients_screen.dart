import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientFormSheet(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final mode = ref.watch(clientDisplayModeProvider);

    return Scaffold(
      appBar: AppBar(
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

          // ── Tri alphabétique par labelWith(mode) ─────────────────────
          final sorted = [...clients]
            ..sort((a, b) => a
                .labelWith(mode)
                .toLowerCase()
                .compareTo(b.labelWith(mode).toLowerCase()));

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
                                    child: Icon(
                                      LucideIcons.userCircle2,
                                      key: ValueKey(isCompanyMode),
                                      size: 22,
                                      color: isCompanyMode
                                          ? Theme.of(context).colorScheme.primary
                                          : AppColors.textSecondary(context),
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
                                mainAxisSize: MainAxisSize.min,
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
            c.phone?.isNotEmpty == true ||
            c.whatsapp?.isNotEmpty == true ||
            c.email?.isNotEmpty == true);
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

    // Titre : entreprise → nom civil → "Nouveau client"
    final sheetTitle = !_isEdit
        ? 'Nouveau client'
        : _editMode
            ? 'Modifier'
            : (c!.company?.isNotEmpty == true
                ? c.company!
                : c.fullPersonName);

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
          // ── En-tête : titre + bouton d'action ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sheetTitle,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Bouton droit : crayon (vue) ↔ Enregistrer/Créer (édition)
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
                          child: Text(
                            _isEdit ? 'Enregistrer' : 'Créer',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
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
          // ── Entreprise ────────────────────────────────────────────────
          TextFormField(
            controller: _company,
            autofocus: !_isEdit,
            decoration: const InputDecoration(
              labelText: 'Entreprise',
              hintText: 'ex : Cabinet Dupont SARL',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: _company.text.isNotEmpty
                  ? FontWeight.w600
                  : FontWeight.w400,
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // ── Prénom + Nom ───────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(
                    labelText: 'Prénom',
                    hintText: 'Marie',
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    hintText: 'Dupont',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Section optionnelle dépliable ──────────────────────────────
          GestureDetector(
            onTap: () =>
                setState(() => _optionalExpanded = !_optionalExpanded),
            child: Row(
              children: [
                Icon(
                  _optionalExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Informations complémentaires (optionnel)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (_optionalExpanded) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _street,
              decoration: const InputDecoration(
                labelText: 'Rue',
                hintText: 'ex : 12 rue de la Paix',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _zipCode,
                    decoration: const InputDecoration(
                      labelText: 'Code postal',
                      hintText: '75001',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(
                      labelText: 'Ville',
                      hintText: 'Paris',
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _siret,
              decoration: const InputDecoration(
                labelText: 'SIRET (14 chiffres)',
                hintText: 'ex : 12345678901234',
                prefixIcon: Icon(Icons.tag_outlined),
              ),
              keyboardType: TextInputType.number,
              maxLength: 14,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (v.length != 14 || int.tryParse(v) == null) {
                  return '14 chiffres exactement';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                hintText: 'ex : +33 6 12 34 56 78',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _whatsapp,
              decoration: InputDecoration(
                labelText: 'WhatsApp',
                hintText: 'ex : +33 6 12 34 56 78',
                prefixIcon: const _WhatsAppIcon(),
                suffixIcon: _whatsapp.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.open_in_new, size: 18),
                        tooltip: 'Ouvrir WhatsApp',
                        onPressed: () => _openWhatsApp(_whatsapp.text),
                      )
                    : null,
                helperText: 'Numéro international (+33…)',
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'ex : marie.dupont@gmail.com',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
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
                  (bold ? const Color(0xFF2563EB) : const Color(0xFF6B7280)),
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
