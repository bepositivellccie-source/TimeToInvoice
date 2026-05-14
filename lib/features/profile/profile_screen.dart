import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/profile.dart';
import '../../core/providers/profile_provider.dart';

/// Métadonnées fournies par le provider OAuth (Google) au sign-in.
///
/// Utilisées pour pré-remplir Mon profil dès la première ouverture pour
/// qu'un utilisateur fraîchement inscrit n'ait pas à retaper son nom et
/// son email. On retombe sur un découpage de `full_name` si les champs
/// `given_name` / `family_name` ne sont pas fournis.
class _OAuthIdentity {
  final String firstName;
  final String lastName;
  final String email;
  const _OAuthIdentity(this.firstName, this.lastName, this.email);

  factory _OAuthIdentity.fromAuth() {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? const <String, dynamic>{};
    var firstName = (meta['given_name'] as String?)?.trim() ?? '';
    var lastName = (meta['family_name'] as String?)?.trim() ?? '';
    if (firstName.isEmpty && lastName.isEmpty) {
      final full = ((meta['full_name'] as String?) ??
              (meta['name'] as String?) ??
              '')
          .trim();
      if (full.isNotEmpty) {
        final parts = full.split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          firstName = parts.first;
          lastName = parts.sublist(1).join(' ');
        } else {
          lastName = full;
        }
      }
    }
    final email = (user?.email ?? (meta['email'] as String?) ?? '').trim();
    return _OAuthIdentity(firstName, lastName, email);
  }
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  // ── Controllers ─────────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _zipCodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  final _tvaCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tvaRateCtrl = TextEditingController();

  // ── Focus nodes ────────────────────────────────────────────────────────
  final _companyFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _rateFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _streetFocus = FocusNode();
  final _zipFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _siretFocus = FocusNode();
  final _tvaFocus = FocusNode();
  final _tvaRateFocus = FocusNode();
  final _ibanFocus = FocusNode();

  String _tvaRegime = 'franchise';
  bool _ctrlInitialized = false;
  bool _initialModeSet = false;
  bool _isEditing = false;
  bool _saving = false;

  // ── Inline errors (auto-cleared as user types) ─────────────────────────
  String? _nameError;
  String? _emailError;
  String? _siretError;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onNameChange);
    _emailCtrl.addListener(_onEmailChange);
    _siretCtrl.addListener(_onSiretChange);
  }

  void _onNameChange() {
    if (!mounted || _nameError == null) return;
    if (_nameCtrl.text.trim().isNotEmpty) {
      setState(() => _nameError = null);
    }
  }

  void _onEmailChange() {
    if (!mounted || _emailError == null) return;
    final txt = _emailCtrl.text.trim();
    if (txt.isEmpty || txt.contains('@')) {
      setState(() => _emailError = null);
    }
  }

  void _onSiretChange() {
    if (!mounted || _siretError == null) return;
    final txt = _siretCtrl.text.trim();
    if (txt.isEmpty || (txt.length == 14 && int.tryParse(txt) != null)) {
      setState(() => _siretError = null);
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChange);
    _emailCtrl.removeListener(_onEmailChange);
    _siretCtrl.removeListener(_onSiretChange);
    for (final c in [
      _firstNameCtrl,
      _nameCtrl,
      _companyCtrl,
      _emailCtrl,
      _phoneCtrl,
      _streetCtrl,
      _zipCodeCtrl,
      _cityCtrl,
      _siretCtrl,
      _tvaCtrl,
      _ibanCtrl,
      _rateCtrl,
      _tvaRateCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _companyFocus,
      _firstNameFocus,
      _nameFocus,
      _rateFocus,
      _emailFocus,
      _phoneFocus,
      _streetFocus,
      _zipFocus,
      _cityFocus,
      _siretFocus,
      _tvaFocus,
      _tvaRateFocus,
      _ibanFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncControllers(Profile? p) {
    // Fallback Google sign-in : si le champ correspondant est vide côté
    // profil DB, on utilise les métadonnées OAuth pour pré-remplir
    // (prénom, nom, email). Évite à un nouvel utilisateur de retaper
    // des infos que Google nous a déjà fournies au sign-in.
    final oauth = _OAuthIdentity.fromAuth();
    final dbFirstName = (p?.firstName ?? '').trim();
    final dbName = (p?.displayName ?? '').trim();
    final dbEmail = (p?.email ?? '').trim();

    _firstNameCtrl.text =
        dbFirstName.isNotEmpty ? dbFirstName : oauth.firstName;
    _nameCtrl.text = dbName.isNotEmpty ? dbName : oauth.lastName;
    _companyCtrl.text = p?.company ?? '';
    _emailCtrl.text = dbEmail.isNotEmpty ? dbEmail : oauth.email;
    _phoneCtrl.text = p?.phone ?? '';
    _streetCtrl.text = p?.street ?? '';
    _zipCodeCtrl.text = p?.zipCode ?? '';
    _cityCtrl.text = p?.city ?? '';
    _siretCtrl.text = p?.siret ?? '';
    _tvaCtrl.text = p?.tvaNumber ?? '';
    _ibanCtrl.text = p?.iban ?? '';
    final rate = p?.defaultHourlyRate;
    _rateCtrl.text = rate == null
        ? ''
        : (rate.truncateToDouble() == rate
            ? rate.toInt().toString()
            : rate.toStringAsFixed(2));
    _tvaRegime = p?.tvaRegime ?? 'franchise';
    final tvaR = p?.tvaRate;
    _tvaRateCtrl.text = tvaR == null
        ? ''
        : (tvaR.truncateToDouble() == tvaR
            ? tvaR.toInt().toString()
            : tvaR.toStringAsFixed(2));
    _nameError = null;
    _emailError = null;
    _siretError = null;
  }

  bool _isProfileEmpty(Profile? p) =>
      p == null || (p.displayName ?? '').trim().isEmpty;

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  bool _validateName() {
    final err = _nameCtrl.text.trim().isEmpty ? 'Requis' : null;
    if (err != _nameError) setState(() => _nameError = err);
    return err == null;
  }

  bool _validateEmail() {
    final txt = _emailCtrl.text.trim();
    final err = txt.isEmpty
        ? 'Requis'
        : (!txt.contains('@') ? 'Email invalide' : null);
    if (err != _emailError) setState(() => _emailError = err);
    return err == null;
  }

  bool _validateSiret() {
    final txt = _siretCtrl.text.trim();
    final err = txt.isEmpty
        ? null
        : ((txt.length != 14 || int.tryParse(txt) == null)
            ? '14 chiffres exactement'
            : null);
    if (err != _siretError) setState(() => _siretError = err);
    return err == null;
  }

  Future<void> _save() async {
    final nameOk = _validateName();
    final emailOk = _validateEmail();
    final siretOk = _validateSiret();
    if (!nameOk || !emailOk || !siretOk) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).save(
            Profile(
              displayName: _nullIfEmpty(_nameCtrl.text),
              firstName: _nullIfEmpty(_firstNameCtrl.text),
              company: _nullIfEmpty(_companyCtrl.text),
              street: _nullIfEmpty(_streetCtrl.text),
              zipCode: _nullIfEmpty(_zipCodeCtrl.text),
              city: _nullIfEmpty(_cityCtrl.text),
              email: _nullIfEmpty(_emailCtrl.text),
              phone: _nullIfEmpty(_phoneCtrl.text),
              siret: _nullIfEmpty(_siretCtrl.text),
              tvaNumber: _nullIfEmpty(_tvaCtrl.text),
              iban: _nullIfEmpty(_ibanCtrl.text),
              defaultHourlyRate:
                  double.tryParse(_rateCtrl.text.trim().replaceAll(',', '.')),
              tvaRegime: _tvaRegime,
              tvaRate: _tvaRegime == 'assujetti'
                  ? (double.tryParse(
                          _tvaRateCtrl.text.trim().replaceAll(',', '.')) ??
                      20.0)
                  : null,
            ),
          );
      ref.invalidate(profileProvider);
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Profil enregistré.'),
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

  Future<void> _cancelEdit(Profile? p) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler les modifications ?'),
        content: const Text(
            'Les modifications non enregistrées seront perdues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Continuer l'édition"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      FocusManager.instance.primaryFocus?.unfocus();
      _syncControllers(p);
      setState(() => _isEditing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);

    if (profileAsync.isLoading && !_ctrlInitialized) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: pageBg,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_ctrlInitialized) {
      _ctrlInitialized = true;
      _syncControllers(profile);
    }
    if (!_initialModeSet) {
      _initialModeSet = true;
      _isEditing = _isProfileEmpty(profile);
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: CustomScrollView(
        slivers: [
          _ProfileHeader(
            profile: profile,
            isEditing: _isEditing,
            isSaving: _saving,
            onBack: () => context.pop(),
            onCancelEdit: () => _cancelEdit(profile),
            onToggleEdit: () {
              if (_isEditing) {
                _save();
              } else {
                _syncControllers(profile);
                setState(() => _isEditing = true);
              }
            },
          ),
          SliverToBoxAdapter(
            child: Column(
              children: _isEditing
                  ? _buildEditFields()
                  : _buildReadFields(profile),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edit mode ───────────────────────────────────────────────────────────

  List<Widget> _buildEditFields() {
    return [
      _editSectionTitle('IDENTITÉ'),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.briefcase,
          focusedIcon: Icons.business,
          label: 'Raison sociale',
          hint: 'ex : Cabinet Dupont SARL',
          controller: _companyCtrl,
          focusNode: _companyFocus,
          textCapitalization: TextCapitalization.words,
          onValidate: () => _firstNameFocus.requestFocus(),
        ),
      ),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.user,
          focusedIcon: Icons.person,
          label: 'Prénom',
          hint: 'Marie',
          controller: _firstNameCtrl,
          focusNode: _firstNameFocus,
          textCapitalization: TextCapitalization.words,
          onValidate: () => _nameFocus.requestFocus(),
        ),
      ),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.user,
          focusedIcon: Icons.person,
          label: 'Nom *',
          hint: 'Dupont',
          controller: _nameCtrl,
          focusNode: _nameFocus,
          textCapitalization: TextCapitalization.words,
          errorText: _nameError,
          onValidate: () {
            if (!_validateName()) return;
            _rateFocus.requestFocus();
          },
        ),
      ),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.banknote,
          focusedIcon: Icons.payments,
          label: 'Taux horaire par défaut (€/h)',
          hint: 'ex : 60',
          controller: _rateCtrl,
          focusNode: _rateFocus,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onValidate: () => _emailFocus.requestFocus(),
        ),
      ),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.mail,
          focusedIcon: Icons.email,
          label: 'Email professionnel *',
          hint: 'ex : contact@monentreprise.fr',
          controller: _emailCtrl,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onValidate: () {
            if (!_validateEmail()) return;
            _phoneFocus.requestFocus();
          },
        ),
      ),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.phone,
          focusedIcon: Icons.phone,
          label: 'Téléphone',
          hint: 'ex : 06 12 34 56 78',
          controller: _phoneCtrl,
          focusNode: _phoneFocus,
          keyboardType: TextInputType.phone,
          onValidate: () => _streetFocus.requestFocus(),
        ),
      ),

      _editSectionTitle('ADRESSE', topGap: 24),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.mapPin,
          focusedIcon: Icons.location_on,
          label: 'Rue',
          hint: 'ex : 12 rue de la Paix',
          controller: _streetCtrl,
          focusNode: _streetFocus,
          textCapitalization: TextCapitalization.words,
          onValidate: () => _zipFocus.requestFocus(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: _DetailFieldCard(
                icon: LucideIcons.hash,
                focusedIcon: Icons.numbers,
                label: 'CP',
                hint: '75001',
                controller: _zipCodeCtrl,
                focusNode: _zipFocus,
                keyboardType: TextInputType.number,
                maxLength: 5,
                onValidate: () => _cityFocus.requestFocus(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DetailFieldCard(
                icon: LucideIcons.building2,
                focusedIcon: Icons.location_city,
                label: 'Ville',
                hint: 'Paris',
                controller: _cityCtrl,
                focusNode: _cityFocus,
                textCapitalization: TextCapitalization.words,
                onValidate: () => _siretFocus.requestFocus(),
              ),
            ),
          ],
        ),
      ),

      _editSectionTitle('FISCAL', topGap: 24),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.fileText,
          focusedIcon: Icons.description,
          label: 'SIRET *',
          hint: 'ex : 12345678901234',
          controller: _siretCtrl,
          focusNode: _siretFocus,
          keyboardType: TextInputType.number,
          maxLength: 14,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          errorText: _siretError,
          onValidate: () {
            if (!_validateSiret()) return;
            _tvaFocus.requestFocus();
          },
        ),
      ),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.percent,
          focusedIcon: Icons.percent,
          label: 'N° TVA (si assujetti)',
          hint: 'ex : FR12345678901',
          controller: _tvaCtrl,
          focusNode: _tvaFocus,
          textCapitalization: TextCapitalization.characters,
          maxLength: 13,
          onValidate: () => _ibanFocus.requestFocus(),
        ),
      ),
      _editFieldCardSpaced(
        _RegimeTvaCard(
          tvaRegime: _tvaRegime,
          tvaRateCtrl: _tvaRateCtrl,
          tvaRateFocus: _tvaRateFocus,
          onChanged: (v) => setState(() {
            _tvaRegime = v ? 'assujetti' : 'franchise';
            if (v && _tvaRateCtrl.text.trim().isEmpty) {
              _tvaRateCtrl.text = '20';
            }
          }),
        ),
      ),
      _editFieldCardSpaced(
        _DetailFieldCard(
          icon: LucideIcons.landmark,
          focusedIcon: Icons.account_balance,
          label: 'IBAN (optionnel)',
          hint: 'ex : FR76 3000 6000 0112 3456 7890 189',
          controller: _ibanCtrl,
          focusNode: _ibanFocus,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onValidate: _save,
        ),
      ),

      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
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
      ),
      const SizedBox(height: 40),
    ];
  }

  // ─── Read mode ───────────────────────────────────────────────────────────

  List<Widget> _buildReadFields(Profile? p) {
    final rows = <_ReadRow>[];

    // Identité
    final fullName = p?.fullPersonName ?? '';
    if (fullName.isNotEmpty) {
      rows.add(_ReadRow(
        icon: LucideIcons.user,
        label: 'Nom complet',
        value: fullName,
      ));
    }
    if ((p?.company ?? '').isNotEmpty) {
      rows.add(_ReadRow(
        icon: LucideIcons.briefcase,
        label: 'Raison sociale',
        value: p!.company!,
      ));
    }
    if (p?.defaultHourlyRate != null) {
      final r = p!.defaultHourlyRate!;
      final rStr = r.truncateToDouble() == r
          ? r.toInt().toString()
          : r.toStringAsFixed(2);
      rows.add(_ReadRow(
        icon: LucideIcons.banknote,
        label: 'Taux horaire par défaut',
        value: '$rStr €/h',
      ));
    }
    if ((p?.email ?? '').isNotEmpty) {
      rows.add(_ReadRow(
        icon: LucideIcons.mail,
        label: 'Email professionnel',
        value: p!.email!,
      ));
    }
    if ((p?.phone ?? '').isNotEmpty) {
      rows.add(_ReadRow(
        icon: LucideIcons.phone,
        label: 'Téléphone',
        value: p!.phone!,
      ));
    }

    // Adresse
    final addressRows = <_ReadRow>[];
    if ((p?.street ?? '').isNotEmpty) {
      addressRows.add(_ReadRow(
        icon: LucideIcons.mapPin,
        label: 'Rue',
        value: p!.street!,
      ));
    }
    final cp = p?.zipCode ?? '';
    final city = p?.city ?? '';
    final cpCity = '$cp $city'.trim();
    if (cpCity.isNotEmpty) {
      addressRows.add(_ReadRow(
        icon: LucideIcons.building2,
        label: 'Code postal · Ville',
        value: cpCity,
      ));
    }

    // Fiscal
    final fiscalRows = <_ReadRow>[];
    if ((p?.siret ?? '').isNotEmpty) {
      fiscalRows.add(_ReadRow(
        icon: LucideIcons.fileText,
        label: 'SIRET',
        value: p!.siret!,
      ));
    }
    if ((p?.tvaNumber ?? '').isNotEmpty) {
      fiscalRows.add(_ReadRow(
        icon: LucideIcons.percent,
        label: 'N° TVA',
        value: p!.tvaNumber!,
      ));
    }
    if (p?.tvaRegime == 'assujetti') {
      final r = p!.tvaRate ?? 20.0;
      final rStr = r.truncateToDouble() == r
          ? r.toInt().toString()
          : r.toStringAsFixed(2);
      fiscalRows.add(_ReadRow(
        icon: LucideIcons.percent,
        label: 'Régime TVA',
        value: 'Assujetti · taux $rStr %',
      ));
    } else {
      fiscalRows.add(const _ReadRow(
        icon: LucideIcons.percent,
        label: 'Régime TVA',
        value: 'Franchise en base (art. 293 B)',
      ));
    }
    if ((p?.iban ?? '').isNotEmpty) {
      fiscalRows.add(_ReadRow(
        icon: LucideIcons.landmark,
        label: 'IBAN',
        value: p!.iban!,
      ));
    }

    final widgets = <Widget>[];

    widgets.add(_editSectionTitle('IDENTITÉ'));
    if (rows.isNotEmpty) {
      widgets.add(_readCard(rows));
    } else {
      widgets.add(_readEmptyHint('Aucune info renseignée.'));
    }

    widgets.add(_editSectionTitle('ADRESSE', topGap: 24));
    if (addressRows.isNotEmpty) {
      widgets.add(_readCard(addressRows));
    } else {
      widgets.add(_readEmptyHint('Aucune adresse renseignée.'));
    }

    widgets.add(_editSectionTitle('FISCAL', topGap: 24));
    if (fiscalRows.isNotEmpty) {
      widgets.add(_readCard(fiscalRows));
    } else {
      widgets.add(_readEmptyHint('Aucune info fiscale renseignée.'));
    }

    widgets.add(const SizedBox(height: 40));
    return widgets;
  }

  Widget _readCard(List<_ReadRow> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(const Divider(
          height: 1,
          thickness: 0.5,
          color: Color(0xFFE5E7EB),
        ));
      }
      children.add(rows[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _readEmptyHint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ),
      );

  Widget _editSectionTitle(String title, {double topGap = 16}) => Padding(
        padding: EdgeInsets.fromLTRB(32, topGap, 32, 8),
        child: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      );

  Widget _editFieldCardSpaced(Widget card) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: card,
      );
}

// ─── Profile header (Sliver, Revolut-style avatar + name) ───────────────────

class _ProfileHeader extends StatelessWidget {
  final Profile? profile;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onBack;
  final VoidCallback onToggleEdit;
  final VoidCallback onCancelEdit;

  const _ProfileHeader({
    required this.profile,
    required this.isEditing,
    required this.isSaving,
    required this.onBack,
    required this.onToggleEdit,
    required this.onCancelEdit,
  });

  String _initials(Profile? p) {
    final src = (p?.headerName.isNotEmpty ?? false)
        ? p!.headerName
        : (p?.fullPersonName ?? '');
    if (src.trim().isEmpty) return '?';
    return src
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6);
    final hasCompany =
        (profile?.company != null) && profile!.company!.isNotEmpty;
    final personName = profile?.fullPersonName ?? '';
    final title = hasCompany
        ? profile!.company!
        : (personName.isNotEmpty ? personName : 'Mon profil');

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: pageBg,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: isEditing ? onCancelEdit : onBack,
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
            tooltip: isEditing ? 'Enregistrer' : 'Modifier',
            onPressed: onToggleEdit,
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 28),
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
                    _initials(profile),
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasCompany && personName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  personName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if ((profile?.siret ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'SIRET : ${profile!.siret}',
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

// ─── Read row (icon + label + value) ────────────────────────────────────────

class _ReadRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Régime TVA card (switch + conditional rate field) ─────────────────────

class _RegimeTvaCard extends StatefulWidget {
  final String tvaRegime;
  final TextEditingController tvaRateCtrl;
  final FocusNode tvaRateFocus;
  final ValueChanged<bool> onChanged;

  const _RegimeTvaCard({
    required this.tvaRegime,
    required this.tvaRateCtrl,
    required this.tvaRateFocus,
    required this.onChanged,
  });

  @override
  State<_RegimeTvaCard> createState() => _RegimeTvaCardState();
}

class _RegimeTvaCardState extends State<_RegimeTvaCard> {
  bool _rateFocused = false;

  @override
  void initState() {
    super.initState();
    widget.tvaRateFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (_rateFocused != widget.tvaRateFocus.hasFocus) {
      setState(() => _rateFocused = widget.tvaRateFocus.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.tvaRateFocus.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assujetti = widget.tvaRegime == 'assujetti';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.percent,
                  size: 16,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Régime TVA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        assujetti
                            ? 'Assujetti à la TVA'
                            : 'Franchise en base (art. 293 B)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: assujetti,
                  onChanged: widget.onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF305DA8),
                ),
              ],
            ),
          ),
          if (assujetti) ...[
            const Divider(
              height: 1,
              thickness: 0.5,
              color: Color(0xFFE5E7EB),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.percent,
                        size: 16,
                        color: _rateFocused
                            ? const Color(0xFF305DA8)
                            : const Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Taux TVA (%)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _rateFocused
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _rateFocused
                              ? const Color(0xFF305DA8)
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: widget.tvaRateCtrl,
                    focusNode: widget.tvaRateFocus,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF111827),
                    ),
                    decoration: const InputDecoration(
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'ex : 20',
                      hintStyle: TextStyle(
                        fontSize: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Detail Field Card (mirror of client_detail_screen pattern) ────────────

class _DetailFieldCard extends StatefulWidget {
  final IconData icon;
  final IconData? focusedIcon;
  final String label;
  final String? hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onValidate;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;

  const _DetailFieldCard({
    required this.icon,
    this.focusedIcon,
    required this.label,
    this.hint,
    required this.controller,
    required this.focusNode,
    required this.onValidate,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.maxLength,
    this.inputFormatters,
    this.errorText,
  });

  @override
  State<_DetailFieldCard> createState() => _DetailFieldCardState();
}

class _DetailFieldCardState extends State<_DetailFieldCard> {
  bool _focused = false;
  bool _isValidated = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    _isValidated = false;
    widget.focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
  }

  void _handleFocusChange() {
    if (!mounted) return;
    if (widget.focusNode.hasFocus != _focused) {
      setState(() {
        _focused = widget.focusNode.hasFocus;
        if (_focused) {
          _isValidated = false;
        } else if (widget.controller.text.trim().isNotEmpty) {
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

    final Color borderColor;
    final double borderWidth;
    final List<BoxShadow> shadows;
    if (hasError) {
      borderColor = const Color(0xFFEF4444);
      borderWidth = 2;
      shadows = const [];
    } else if (_focused) {
      borderColor = const Color(0xFF305DA8);
      borderWidth = 2;
      shadows = const [
        BoxShadow(
          color: Color(0x2E305DA8),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
    } else {
      borderColor = const Color(0xFFE5E7EB);
      borderWidth = 1;
      shadows = const [];
    }

    final Color accentColor =
        showAccent ? const Color(0xFF305DA8) : const Color(0xFF6B7280);
    final FontWeight labelWeight =
        showAccent ? FontWeight.w600 : FontWeight.w400;
    final IconData displayIcon = showAccent && widget.focusedIcon != null
        ? widget.focusedIcon!
        : widget.icon;

    final Color checkColor =
        _isValidated ? const Color(0xFF305DA8) : const Color(0xFF9CA3AF);
    final Color checkBorderColor =
        _isValidated ? Colors.transparent : const Color(0xFFE5E7EB);

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
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: labelWeight,
                        color: accentColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: (hasText || _focused) ? 1.0 : 0.0,
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
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                textCapitalization: widget.textCapitalization,
                maxLength: widget.maxLength,
                inputFormatters: widget.inputFormatters,
                onSubmitted: (_) => widget.onValidate(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF111827),
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
                  hintStyle: const TextStyle(
                    fontSize: 18,
                    color: Color(0xFF9CA3AF),
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
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
