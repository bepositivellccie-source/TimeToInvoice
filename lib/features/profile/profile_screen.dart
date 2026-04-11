import 'package:flutter/material.dart';
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
  final _addressCtrl = TextEditingController();
  final _siretCtrl = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _siretCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileProvider.notifier).save(Profile(
            displayName:
                _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
            address: _addressCtrl.text.trim().isEmpty
                ? null
                : _addressCtrl.text.trim(),
            siret: _siretCtrl.text.trim().isEmpty
                ? null
                : _siretCtrl.text.trim(),
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil enregistré ✓'),
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

    // Initialise les contrôleurs une seule fois quand le profil arrive
    ref.listen(profileProvider, (prev, next) {
      if (!_initialized && next.valueOrNull != null) {
        final p = next.valueOrNull!;
        _nameCtrl.text = p.displayName ?? '';
        _addressCtrl.text = p.address ?? '';
        _siretCtrl.text = p.siret ?? '';
        _initialized = true;
      }
    });

    // Cas où le profil est déjà en cache (hot reload, etc.)
    if (!_initialized && profileAsync.valueOrNull != null) {
      final p = profileAsync.valueOrNull!;
      _nameCtrl.text = p.displayName ?? '';
      _addressCtrl.text = p.address ?? '';
      _siretCtrl.text = p.siret ?? '';
      _initialized = true;
    }
    // Premier chargement — profil nul = pas encore créé, on affiche le form vide
    if (!_initialized && !profileAsync.isLoading) {
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
      ),
      body: profileAsync.isLoading && !_initialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Informations vendeur ─────────────────────────────────
                  Text(
                    'Informations vendeur',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ces infos apparaissent sur vos factures.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7280),
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Nom / raison sociale
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom / raison sociale *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),

                  // Adresse
                  TextField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adresse complète',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),

                  // SIRET
                  TextField(
                    controller: _siretCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SIRET (14 chiffres)',
                      prefixIcon: Icon(Icons.tag_outlined),
                      helperText: 'Auto-entrepreneur : SIRET = SIREN + NIC',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 14,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 28),

                  // Bouton enregistrer
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
    );
  }
}
