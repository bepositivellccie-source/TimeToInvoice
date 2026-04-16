import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/models/profile.dart';
import '../../core/providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
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

  String _tvaRegime = 'franchise';
  bool _ctrlInitialized = false;
  bool _initialModeSet = false;
  bool _isEditing = false;
  bool _saving = false;

  @override
  void dispose() {
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
    super.dispose();
  }

  void _syncControllers(Profile? p) {
    _firstNameCtrl.text = p?.firstName ?? '';
    _nameCtrl.text = p?.displayName ?? '';
    _companyCtrl.text = p?.company ?? '';
    _emailCtrl.text = p?.email ?? '';
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
  }

  bool _isProfileEmpty(Profile? p) =>
      p == null || (p.displayName ?? '').trim().isEmpty;

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
              content: Text('Profil enregistré'),
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

  void _cancelEdit(Profile? p) {
    FocusManager.instance.primaryFocus?.unfocus();
    _syncControllers(p);
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.valueOrNull;

    if (profileAsync.isLoading && !_ctrlInitialized) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Mon profil',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isEditing && !_isProfileEmpty(profile)) {
              _cancelEdit(profile);
            } else {
              context.pop();
            }
          },
        ),
        title: const Text(
          'Mon profil',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_isEditing)
            TextButton(
              onPressed: () => _cancelEdit(profile),
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(LucideIcons.pencil, size: 20),
              tooltip: 'Modifier',
              onPressed: () {
                _syncControllers(profile);
                setState(() => _isEditing = true);
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── IDENTITÉ ─────────────────────────────────────
              const _SectionHeader(title: 'IDENTITÉ'),
              const SizedBox(height: 8),
              if (_isEditing)
                _buildIdentityEdit()
              else
                _buildIdentityRead(profile),

              const SizedBox(height: 24),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 16),

              // ── ADRESSE ──────────────────────────────────────
              const _SectionHeader(title: 'ADRESSE'),
              const SizedBox(height: 8),
              if (_isEditing)
                _buildAddressEdit()
              else
                _buildAddressRead(profile),

              const SizedBox(height: 24),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 16),

              // ── FISCAL ───────────────────────────────────────
              const _SectionHeader(title: 'FISCAL'),
              const SizedBox(height: 8),
              if (_isEditing)
                _buildFiscalEdit()
              else
                _buildFiscalRead(profile),

              if (_isEditing) ...[
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF305DA8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
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
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Blocs édition ──────────────────────────────────────────────────────

  Widget _buildIdentityEdit() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MD3ProfileField(
                  label: 'Prénom',
                  controller: _firstNameCtrl,
                  hint: 'Marie',
                  textCapitalization: TextCapitalization.words,
                  outerPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MD3ProfileField(
                  label: 'Nom *',
                  controller: _nameCtrl,
                  hint: 'Dupont',
                  textCapitalization: TextCapitalization.words,
                  outerPadding: EdgeInsets.zero,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requis' : null,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        _MD3ProfileField(
          label: 'Raison sociale / nom commercial',
          controller: _companyCtrl,
          hint: 'ex : Cabinet Dupont SARL',
          textCapitalization: TextCapitalization.words,
        ),
        const Divider(height: 1, thickness: 0.5),
        _MD3ProfileField(
          label: 'Taux horaire par défaut (€/h)',
          controller: _rateCtrl,
          hint: 'ex : 60',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const Divider(height: 1, thickness: 0.5),
        _MD3ProfileField(
          label: 'Email professionnel *',
          controller: _emailCtrl,
          hint: 'ex : contact@monentreprise.fr',
          keyboardType: TextInputType.emailAddress,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
        ),
        const Divider(height: 1, thickness: 0.5),
        _MD3ProfileField(
          label: 'Téléphone',
          controller: _phoneCtrl,
          hint: 'ex : 06 12 34 56 78',
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildAddressEdit() {
    return Column(
      children: [
        _MD3ProfileField(
          label: 'Rue *',
          controller: _streetCtrl,
          hint: 'ex : 12 rue de la Paix',
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
        ),
        const Divider(height: 1, thickness: 0.5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                flex: 1,
                child: _MD3ProfileField(
                  label: 'Code postal',
                  controller: _zipCodeCtrl,
                  hint: '75001',
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  outerPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                flex: 2,
                child: _MD3ProfileField(
                  label: 'Ville',
                  controller: _cityCtrl,
                  hint: 'Paris',
                  textCapitalization: TextCapitalization.words,
                  outerPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFiscalEdit() {
    return Column(
      children: [
        _SiretProfileField(
          controller: _siretCtrl,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Requis';
            if (v.length != 14 || int.tryParse(v) == null) {
              return '14 chiffres exactement';
            }
            return null;
          },
        ),
        const Divider(height: 1, thickness: 0.5),
        _MD3ProfileField(
          label: 'N° TVA (si assujetti)',
          controller: _tvaCtrl,
          hint: 'ex : FR12345678901',
          textCapitalization: TextCapitalization.characters,
          maxLength: 13,
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'RÉGIME TVA'),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Franchise en base (art. 293 B)',
                  style: TextStyle(fontSize: 14),
                ),
              ),
              Switch(
                value: _tvaRegime == 'assujetti',
                onChanged: (v) => setState(() {
                  _tvaRegime = v ? 'assujetti' : 'franchise';
                  if (v && _tvaRateCtrl.text.trim().isEmpty) {
                    _tvaRateCtrl.text = '20';
                  }
                }),
              ),
            ],
          ),
        ),
        if (_tvaRegime == 'assujetti') ...[
          const Divider(height: 1, thickness: 0.5),
          _MD3ProfileField(
            label: 'Taux TVA (%)',
            controller: _tvaRateCtrl,
            hint: 'ex : 20',
            keyboardType: TextInputType.number,
          ),
        ],
        const Divider(height: 1, thickness: 0.5),
        _MD3ProfileField(
          label: 'IBAN (optionnel)',
          controller: _ibanCtrl,
          hint: 'ex : FR76 3000 6000 0112 3456 7890 189',
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          onSubmit: _save,
        ),
      ],
    );
  }

  // ─── Blocs consultation ─────────────────────────────────────────────────

  Widget _buildIdentityRead(Profile? p) {
    final rows = <_ReadRow>[];

    final name = p?.fullPersonName ?? '';
    if (name.isNotEmpty) {
      rows.add(_ReadRow(label: 'Nom complet', value: name));
    }
    if ((p?.company ?? '').isNotEmpty) {
      rows.add(_ReadRow(label: 'Raison sociale', value: p!.company!));
    }
    if (p?.defaultHourlyRate != null) {
      final r = p!.defaultHourlyRate!;
      final rStr = r.truncateToDouble() == r
          ? r.toInt().toString()
          : r.toStringAsFixed(2);
      rows.add(
          _ReadRow(label: 'Taux horaire par défaut', value: '$rStr €/h'));
    }
    if ((p?.email ?? '').isNotEmpty) {
      rows.add(_ReadRow(label: 'Email professionnel', value: p!.email!));
    }
    if ((p?.phone ?? '').isNotEmpty) {
      rows.add(_ReadRow(label: 'Téléphone', value: p!.phone!));
    }
    return _rowsWithDividers(rows);
  }

  Widget _buildAddressRead(Profile? p) {
    final rows = <_ReadRow>[];
    if ((p?.street ?? '').isNotEmpty) {
      rows.add(_ReadRow(label: 'Rue', value: p!.street!));
    }
    final cp = p?.zipCode ?? '';
    final city = p?.city ?? '';
    final cpCity = '$cp $city'.trim();
    if (cpCity.isNotEmpty) {
      rows.add(_ReadRow(label: 'Code postal · Ville', value: cpCity));
    }
    return _rowsWithDividers(rows);
  }

  Widget _buildFiscalRead(Profile? p) {
    final rows = <_ReadRow>[];
    if ((p?.siret ?? '').isNotEmpty) {
      rows.add(_ReadRow(label: 'SIRET', value: p!.siret!));
    }
    if ((p?.tvaNumber ?? '').isNotEmpty) {
      rows.add(_ReadRow(label: 'N° TVA', value: p!.tvaNumber!));
    }
    if (p?.tvaRegime == 'assujetti') {
      final r = p!.tvaRate ?? 20.0;
      final rStr = r.truncateToDouble() == r
          ? r.toInt().toString()
          : r.toStringAsFixed(2);
      rows.add(_ReadRow(
          label: 'Régime TVA', value: 'Assujetti · taux $rStr %'));
    } else {
      rows.add(const _ReadRow(
          label: 'Régime TVA', value: 'Franchise en base (art. 293 B)'));
    }
    if ((p?.iban ?? '').isNotEmpty) {
      rows.add(_ReadRow(label: 'IBAN', value: p!.iban!));
    }
    return _rowsWithDividers(rows);
  }

  Widget _rowsWithDividers(List<_ReadRow> rows) {
    if (rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Text(
          '—',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF9CA3AF),
          ),
        ),
      );
    }
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(const Divider(height: 1, thickness: 0.5));
      children.add(rows[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

// ─── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 1.2,
      ),
    );
  }
}

// ─── Read row — label 11px gris + valeur 15px ──────────────────────────────

class _ReadRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReadRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          const SizedBox(height: 4),
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
    );
  }
}

// ─── MD3 Profile Field (TextFormField) ─────────────────────────────────────

class _MD3ProfileField extends StatefulWidget {
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

  const _MD3ProfileField({
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
  State<_MD3ProfileField> createState() => _MD3ProfileFieldState();
}

class _MD3ProfileFieldState extends State<_MD3ProfileField> {
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
              hintStyle:
                  const TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
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

// ─── SIRET Profile Field — compteur X/14 ───────────────────────────────────

class _SiretProfileField extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _SiretProfileField({required this.controller, this.validator});

  @override
  State<_SiretProfileField> createState() => _SiretProfileFieldState();
}

class _SiretProfileFieldState extends State<_SiretProfileField> {
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
                'SIRET *',
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
            textInputAction: TextInputAction.next,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: 0.5,
            ),
            decoration: InputDecoration(
              hintText: 'ex : 12345678901234',
              hintStyle:
                  const TextStyle(fontSize: 14, color: Color(0xFFBDBDBD)),
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
