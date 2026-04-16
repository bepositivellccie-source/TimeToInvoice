import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/profile.dart';
import '../../core/providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _zipCodeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  final _tvaCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _streetCtrl.dispose();
    _zipCodeCtrl.dispose();
    _cityCtrl.dispose();
    _siretCtrl.dispose();
    _tvaCtrl.dispose();
    _ibanCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(Profile p) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = p.displayName ?? '';
    _emailCtrl.text = p.email ?? '';
    _streetCtrl.text = p.street ?? '';
    _zipCodeCtrl.text = p.zipCode ?? '';
    _cityCtrl.text = p.city ?? '';
    _siretCtrl.text = p.siret ?? '';
    _tvaCtrl.text = p.tvaNumber ?? '';
    _ibanCtrl.text = p.iban ?? '';
  }

  String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).save(Profile(
            displayName: _nullIfEmpty(_nameCtrl.text),
            street: _nullIfEmpty(_streetCtrl.text),
            zipCode: _nullIfEmpty(_zipCodeCtrl.text),
            city: _nullIfEmpty(_cityCtrl.text),
            email: _nullIfEmpty(_emailCtrl.text),
            siret: _nullIfEmpty(_siretCtrl.text),
            tvaNumber: _nullIfEmpty(_tvaCtrl.text),
            iban: _nullIfEmpty(_ibanCtrl.text),
          ));

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Profil enregistré'),
              backgroundColor: Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    ref.listen(profileProvider, (prev, next) {
      if (!_initialized && next.valueOrNull != null) {
        setState(() => _initFromProfile(next.valueOrNull!));
      }
    });
    if (!_initialized && profileAsync.valueOrNull != null) {
      _initFromProfile(profileAsync.valueOrNull!);
    }
    if (!_initialized && !profileAsync.isLoading) {
      _initialized = true;
    }

    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Mon profil',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 16),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withAlpha(30),
                      primary.withAlpha(12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: profileAsync.isLoading && !_initialized
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).padding.bottom + 16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── IDENTITÉ ───────────────────────────────────
                  const _SectionHeader(title: 'IDENTITÉ'),
                  const SizedBox(height: 8),
                  _MD3ProfileField(
                    label: 'Nom / raison sociale *',
                    controller: _nameCtrl,
                    hint: 'ex : Marie Dupont ou Cabinet Dupont',
                    textCapitalization: TextCapitalization.words,
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  _MD3ProfileField(
                    label: 'Email professionnel *',
                    controller: _emailCtrl,
                    hint: 'ex : contact@monentreprise.fr',
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 16),

                  // ── ADRESSE ────────────────────────────────────
                  const _SectionHeader(title: 'ADRESSE'),
                  const SizedBox(height: 8),
                  _MD3ProfileField(
                    label: 'Rue *',
                    controller: _streetCtrl,
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

                  const SizedBox(height: 24),
                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 16),

                  // ── FISCAL ─────────────────────────────────────
                  const _SectionHeader(title: 'FISCAL'),
                  const SizedBox(height: 8),
                  _SiretProfileField(controller: _siretCtrl),
                  const Divider(height: 1, thickness: 0.5),
                  _MD3ProfileField(
                    label: 'N° TVA (si assujetti)',
                    controller: _tvaCtrl,
                    hint: 'ex : FR12345678901',
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 13,
                  ),
                  const Divider(height: 1, thickness: 0.5),
                  _MD3ProfileField(
                    label: 'IBAN (optionnel)',
                    controller: _ibanCtrl,
                    hint: 'ex : FR76 3000 6000 0112 3456 7890 189',
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    onSubmit: _save,
                  ),

                  const SizedBox(height: 28),

                  // ── Bouton enregistrer ─────────────────────────────
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Enregistrer le profil',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),

                ],
              ),
            ),
      ),
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

// ─── MD3 Profile Field — label 11px gris, fond transparent ─────────────────

class _MD3ProfileField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final int? maxLength;
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
          TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: widget.keyboardType,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            maxLength: widget.maxLength,
            onSubmitted:
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
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SIRET Profile Field — compteur X/14 à droite du label ─────────────────

class _SiretProfileField extends StatefulWidget {
  final TextEditingController controller;

  const _SiretProfileField({required this.controller});

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
          TextField(
            controller: widget.controller,
            focusNode: _focus,
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
            ),
          ),
        ],
      ),
    );
  }
}
