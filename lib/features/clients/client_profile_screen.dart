import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  bool _optionalExpanded = false;

  late final TextEditingController _company;
  late final TextEditingController _firstName;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _siret;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _email;

  bool _initialized = false;

  @override
  void dispose() {
    if (_initialized) {
      for (final ctrl in [
        _company, _firstName, _name, _address, _siret, _phone, _whatsapp, _email
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
    _address = TextEditingController(text: c.address ?? '');
    _siret = TextEditingController(text: c.siret ?? '');
    _phone = TextEditingController(text: c.phone ?? '');
    _whatsapp = TextEditingController(text: c.whatsapp ?? '');
    _email = TextEditingController(text: c.email ?? '');
    _optionalExpanded = c.siret?.isNotEmpty == true ||
        c.address?.isNotEmpty == true ||
        c.phone?.isNotEmpty == true ||
        c.whatsapp?.isNotEmpty == true ||
        c.email?.isNotEmpty == true;
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
            address: _nullIfEmpty(_address.text),
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
            icon: const Icon(Icons.arrow_back),
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
          icon: const Icon(Icons.arrow_back),
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
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
              onPressed: () => setState(() => _editMode = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: _editMode ? _buildForm() : _buildView(client),
      ),
    );
  }

  // ── Mode consultation ──────────────────────────────────────────────────────

  Widget _buildView(Client c) {
    final hasExtra = c.address != null ||
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
        _ViewRow(icon: Icons.person_outline, text: c.fullPersonName),
        // Séparateur
        if (hasExtra) ...[
          const SizedBox(height: 4),
          const Divider(),
          const SizedBox(height: 4),
        ],
        if (c.address != null)
          _ViewRow(icon: Icons.location_on_outlined, text: c.address!),
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

  // ── Mode édition ──────────────────────────────────────────────────────────

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Entreprise ─────────────────────────────────────────────
          TextFormField(
            controller: _company,
            decoration: const InputDecoration(
              labelText: 'Entreprise',
              hintText: 'ex : Cabinet Dupont SARL',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  _company.text.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          // ── Prénom + Nom ───────────────────────────────────────────
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
          // ── Section optionnelle ─────────────────────────────────────
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
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                hintText: 'ex : 12 rue de la Paix, 75001 Paris',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              textInputAction: TextInputAction.next,
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
                  color:
                      bold ? const Color(0xFF111827) : const Color(0xFF374151),
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

// ─── Icône WhatsApp ─────────────────────────────────────────────────────────

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
