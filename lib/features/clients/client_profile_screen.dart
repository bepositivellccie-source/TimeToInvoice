import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/client.dart';
import '../../core/providers/client_display_mode_provider.dart';
import '../../core/providers/clients_provider.dart';

/// Fiche client pleine page — consultation par défaut, crayon → édition.
class ClientProfileScreen extends ConsumerStatefulWidget {
  final String clientId;

  const ClientProfileScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientProfileScreen> createState() =>
      _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _editMode = false;
  bool _saving = false;

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

  bool _initialized = false;

  @override
  void dispose() {
    if (_initialized) {
      for (final ctrl in [
        _company, _firstName, _name, _street, _zipCode, _city, _siret, _phone, _whatsapp, _email
      ]) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  void _initControllers(Client c) {
    if (_initialized) return;
    _initialized = true;
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

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
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
        setState(() => _editMode = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Client enregistré'),
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
    final clientsAsync = ref.watch(clientsProvider);
    final mode = ref.watch(clientDisplayModeProvider);

    final client = clientsAsync.valueOrNull
        ?.where((c) => c.id == widget.clientId)
        .firstOrNull;

    if (client == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    _initControllers(client);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editMode ? 'Modifier' : client.labelWith(mode),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_editMode)
            _saving
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _save,
                    child: const Text(
                      'Enregistrer',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  )
          else
            IconButton(
              icon: const Icon(LucideIcons.pencil),
              tooltip: 'Modifier',
              onPressed: () => setState(() => _editMode = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: _editMode ? _buildForm() : _buildView(client),
      ),
    );
  }

  // ── Mode consultation ──────────────────────────────────────────────────────

  Widget _buildView(Client c) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasWhatsApp = c.whatsapp != null && c.whatsapp!.isNotEmpty;
    final hasEmail = c.email != null && c.email!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HEADER COMPACT ────────────────────────────────
        Row(
          children: [
            // Avatar 48px
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  c.fullPersonName.isNotEmpty
                      ? c.fullPersonName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Nom + entreprise
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.fullPersonName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFF111827),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (c.company != null && c.company!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      c.company!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Boutons d'action rapides
            if (hasWhatsApp)
              _ActionCircle(
                icon: LucideIcons.messageCircle,
                color: const Color(0xFF25D366),
                onTap: () => _openWhatsApp(c.whatsapp!),
              ),
            if (hasWhatsApp && hasEmail) const SizedBox(width: 8),
            if (hasEmail)
              _ActionCircle(
                icon: LucideIcons.mail,
                color: Theme.of(context).colorScheme.primary,
                onTap: () => _launchEmail(c.email!),
              ),
          ],
        ),

        const SizedBox(height: 28),

        // ── ENTREPRISE ────────────────────────────────────
        const _SectionHeader(
            icon: LucideIcons.building2, title: 'ENTREPRISE'),
        const SizedBox(height: 12),
        if (c.company != null && c.company!.isNotEmpty)
          _ViewRow(
            icon: LucideIcons.building2,
            text: c.company!,
            bold: true,
          ),
        if (c.siret != null && c.siret!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF305DA8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'SIRET  ${c.siret}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.8,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        if ((c.company == null || c.company!.isEmpty) &&
            (c.siret == null || c.siret!.isEmpty))
          const _EmptyHint('Aucune info entreprise renseignée'),

        const SizedBox(height: 16),
        const Divider(height: 1, thickness: 0.5),
        const SizedBox(height: 16),

        // ── COORDONNÉES (téléphone + email + whatsapp + adresse) ──
        const _SectionHeader(
            icon: LucideIcons.phone, title: 'COORDONNÉES'),
        const SizedBox(height: 12),
        if (c.email != null)
          _ViewRow(
            icon: LucideIcons.mail,
            text: c.email!,
            onTap: () => _launchEmail(c.email!),
          ),
        if (c.phone != null)
          _ViewRow(
            icon: LucideIcons.phone,
            text: c.phone!,
            onTap: () => _launchPhone(c.phone!),
          ),
        if (c.whatsapp != null)
          _ViewRow(
            icon: LucideIcons.messageCircle,
            text: c.whatsapp!,
            iconColor: const Color(0xFF25D366),
            onTap: () => _openWhatsApp(c.whatsapp!),
          ),
        if (c.fullAddress != null)
          _ViewRow(icon: LucideIcons.mapPin, text: c.fullAddress!),
        if (c.email == null &&
            c.phone == null &&
            c.whatsapp == null &&
            c.fullAddress == null)
          const _EmptyHint('Aucune coordonnée renseignée'),
      ],
    );
  }

  // ── Mode édition ──────────────────────────────────────────────────────────

  Widget _buildForm() {
    const divider = Divider(
      height: 1,
      thickness: 0.5,
      color: Color(0xFFE5E7EB),
    );

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── IDENTITÉ ────────────────────────────────────────
          const _SectionHeader(icon: LucideIcons.user, title: 'IDENTITÉ'),
          const SizedBox(height: 12),
          _MD3Field(
            label: 'Entreprise',
            controller: _company,
            hint: 'ex : Cabinet Dupont SARL',
            textCapitalization: TextCapitalization.words,
          ),
          divider,
          _MD3Field(
            label: 'Prénom',
            controller: _firstName,
            hint: 'Marie',
            textCapitalization: TextCapitalization.words,
          ),
          divider,
          _MD3Field(
            label: 'Nom *',
            controller: _name,
            hint: 'Dupont',
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requis' : null,
          ),
          divider,
          _SiretField(
            controller: _siret,
            validator: (v) {
              if (v == null || v.isEmpty) return null;
              if (v.length != 14 || int.tryParse(v) == null) {
                return '14 chiffres exactement';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // ── COORDONNÉES ─────────────────────────────────────
          const _SectionHeader(
              icon: LucideIcons.phone, title: 'COORDONNÉES'),
          const SizedBox(height: 12),
          _MD3Field(
            label: 'Email',
            controller: _email,
            hint: 'ex : marie.dupont@gmail.com',
            keyboardType: TextInputType.emailAddress,
          ),
          divider,
          _MD3Field(
            label: 'Téléphone',
            controller: _phone,
            hint: 'ex : +33 6 12 34 56 78',
            keyboardType: TextInputType.phone,
          ),
          divider,
          _MD3Field(
            label: 'WhatsApp',
            controller: _whatsapp,
            hint: 'ex : +33 6 12 34 56 78',
            keyboardType: TextInputType.phone,
          ),
          divider,
          _MD3Field(
            label: 'Rue',
            controller: _street,
            hint: 'ex : 12 rue de la Paix',
          ),
          divider,
          // CP + Ville côte à côte
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 1,
                child: _MD3Field(
                  label: 'Code postal',
                  controller: _zipCode,
                  hint: '75001',
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 2,
                child: _MD3Field(
                  label: 'Ville',
                  controller: _city,
                  hint: 'Paris',
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmit: _save,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Bouton Enregistrer ───────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
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
        ],
      ),
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF6B7280)),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

// ─── Ligne de consultation ──────────────────────────────────────────────────

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  (bold
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFF6B7280)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: bold ? 15 : 14,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                  color: isDark
                      ? (bold ? const Color(0xFFF1F5F9) : const Color(0xFFCBD5E1))
                      : (bold ? const Color(0xFF111827) : const Color(0xFF374151)),
                ),
              ),
            ),
            if (onTap != null)
              const Icon(LucideIcons.chevronRight,
                  size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// ─── Hint vide ─────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
      ),
    );
  }
}

// ─── Bouton action rond (header compact) ───────────────────────────────────

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCircle({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

// ─── MD3 Field — champ édition Material Design 3 ──────────────────────────

class _MD3Field extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final VoidCallback? onSubmit;

  const _MD3Field({
    required this.label,
    required this.controller,
    this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.validator,
    this.maxLength,
    this.textInputAction,
    this.onSubmit,
  });

  @override
  State<_MD3Field> createState() => _MD3FieldState();
}

class _MD3FieldState extends State<_MD3Field> {
  late final FocusNode _focus;
  bool _hasFocus = false;

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

  static const _brand = Color(0xFF305DA8);
  static const _grey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            textCapitalization: widget.textCapitalization,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction ?? TextInputAction.next,
            maxLength: widget.maxLength,
            onFieldSubmitted: widget.onSubmit != null ? (_) => widget.onSubmit!() : null,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
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

// ─── SIRET Field — champ SIRET avec compteur X/14 ─────────────────────────

class _SiretField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _SiretField({required this.controller, this.validator});

  @override
  State<_SiretField> createState() => _SiretFieldState();
}

class _SiretFieldState extends State<_SiretField> {
  late final FocusNode _focus;
  bool _hasFocus = false;

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

  static const _brand = Color(0xFF305DA8);
  static const _grey = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    final count = widget.controller.text.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
            style: const TextStyle(
              fontSize: 15,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              hintText: 'ex : 12345678901234',
              hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
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
