import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/invoice_data.dart';
import '../../core/models/profile.dart';
import '../../core/models/session.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/utils/invoice_number.dart';
import '../../core/utils/invoice_pdf.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  final String projectId;

  const InvoiceScreen({super.key, required this.projectId});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  // Profil vendeur — chargé depuis la table profiles
  final _sellerNameCtrl = TextEditingController();
  final _sellerAddressCtrl = TextEditingController();
  final _sellerSiretCtrl = TextEditingController();
  bool _profileLoaded = false;

  // Sessions sélectionnées
  final Set<String> _selected = {};
  bool _allInitialized = false;

  bool _generating = false;

  @override
  void initState() {
    super.initState();
    // Chargement via profileProvider (voir ref.listen dans build)
  }

  @override
  void dispose() {
    _sellerNameCtrl.dispose();
    _sellerAddressCtrl.dispose();
    _sellerSiretCtrl.dispose();
    super.dispose();
  }

  // ─── Sauvegarde profil vendeur dans la table profiles ────────────────────

  Future<void> _saveSellerProfile() async {
    await ref.read(profileProvider.notifier).save(Profile(
          displayName: _sellerNameCtrl.text.trim().isEmpty
              ? null
              : _sellerNameCtrl.text.trim(),
          address: _sellerAddressCtrl.text.trim().isEmpty
              ? null
              : _sellerAddressCtrl.text.trim(),
          siret: _sellerSiretCtrl.text.trim().isEmpty
              ? null
              : _sellerSiretCtrl.text.trim(),
        ));
  }

  // ─── Initialisation sélection par défaut ─────────────────────────────────

  void _initSelection(List<WorkSession> sessions) {
    if (!_allInitialized && sessions.isNotEmpty) {
      _selected.addAll(sessions.map((s) => s.id));
      _allInitialized = true;
    }
  }

  // ─── Total HT calculé depuis les sessions sélectionnées ─────────────────

  double _computeTotal(
    List<WorkSession> sessions,
    double hourlyRate,
  ) {
    return sessions
        .where((s) => _selected.contains(s.id))
        .fold(0.0, (sum, s) => sum + ((s.durationMinutes ?? 0) / 60.0) * hourlyRate);
  }

  // ─── Construction InvoiceData ─────────────────────────────────────────────

  InvoiceData _buildInvoiceData({
    required String invoiceNumber,
    required List<WorkSession> sessions,
    required String projectName,
    required double hourlyRate,
    required String currency,
    required String buyerName,
    String? buyerAddress,
    String? buyerSiret,
    String? buyerEmail,
  }) {
    final dateFmt = DateFormat('dd/MM/yyyy', 'fr_FR');
    final selectedSessions =
        sessions.where((s) => _selected.contains(s.id)).toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

    final lines = selectedSessions.map((s) {
      final hours = (s.durationMinutes ?? 0) / 60.0;
      final desc = StringBuffer(
          'Prestation du ${dateFmt.format(s.startedAt.toLocal())}');
      if (s.notes != null && s.notes!.isNotEmpty) {
        desc.write(' — ${s.notes}');
      }
      return InvoiceLine(
        description: desc.toString(),
        hours: hours,
        hourlyRate: hourlyRate,
        currency: currency,
      );
    }).toList();

    return InvoiceData(
      invoiceNumber: invoiceNumber,
      issueDate: DateTime.now(),
      sellerName: _sellerNameCtrl.text.trim().isEmpty
          ? (Supabase.instance.client.auth.currentUser?.email ?? 'Vendeur')
          : _sellerNameCtrl.text.trim(),
      sellerAddress: _sellerAddressCtrl.text.trim().isEmpty
          ? null
          : _sellerAddressCtrl.text.trim(),
      sellerSiret: _sellerSiretCtrl.text.trim().isEmpty
          ? null
          : _sellerSiretCtrl.text.trim(),
      buyerName: buyerName,
      buyerAddress: buyerAddress,
      buyerSiret: buyerSiret,
      buyerEmail: buyerEmail,
      lines: lines,
      currency: currency,
    );
  }

  // ─── Prévisualisation PDF ─────────────────────────────────────────────────

  Future<void> _preview(
    List<WorkSession> sessions,
    String projectName,
    double hourlyRate,
    String currency,
    String buyerName, {
    String? buyerAddress,
    String? buyerSiret,
    String? buyerEmail,
  }) async {
    setState(() => _generating = true);
    try {
      await _saveSellerProfile();
      // Numéro temporaire pour la prévisualisation
      final data = _buildInvoiceData(
        invoiceNumber: 'APERÇU',
        sessions: sessions,
        projectName: projectName,
        hourlyRate: hourlyRate,
        currency: currency,
        buyerName: buyerName,
        buyerAddress: buyerAddress,
        buyerSiret: buyerSiret,
        buyerEmail: buyerEmail,
      );
      final bytes = await buildInvoicePdf(data);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Aperçu facture',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur PDF : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ─── Génération + partage + insert DB ────────────────────────────────────

  Future<void> _generateAndShare({
    required List<WorkSession> sessions,
    required String clientId,
    required String projectName,
    required double hourlyRate,
    required String currency,
    required String buyerName,
    String? buyerAddress,
    String? buyerSiret,
    String? buyerEmail,
  }) async {
    setState(() => _generating = true);
    try {
      await _saveSellerProfile();
      final supabase = Supabase.instance.client;

      // Numéro séquentiel réel
      final invoiceNumber = await nextInvoiceNumber(supabase);

      final data = _buildInvoiceData(
        invoiceNumber: invoiceNumber,
        sessions: sessions,
        projectName: projectName,
        hourlyRate: hourlyRate,
        currency: currency,
        buyerName: buyerName,
        buyerAddress: buyerAddress,
        buyerSiret: buyerSiret,
        buyerEmail: buyerEmail,
      );

      final bytes = await buildInvoicePdf(data);

      // Insert en DB
      await supabase.from('invoices').insert({
        'user_id': supabase.auth.currentUser!.id,
        'client_id': clientId,
        'invoice_number': invoiceNumber,
        'total_amount': data.totalTTC,
        'status': 'draft',
      });

      // Partage natif (email, AirDrop, Drive, etc.)
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Facture_$invoiceNumber.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Facture $invoiceNumber générée ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Initialise les contrôleurs quand le profil est disponible
    ref.listen(profileProvider, (prev, next) {
      if (!_profileLoaded && next.valueOrNull != null) {
        final p = next.valueOrNull!;
        setState(() {
          _sellerNameCtrl.text = p.displayName ?? '';
          _sellerAddressCtrl.text = p.address ?? '';
          _sellerSiretCtrl.text = p.siret ?? '';
          _profileLoaded = true;
        });
      }
    });
    // Profil déjà en cache (hot reload / retour écran)
    if (!_profileLoaded) {
      final cached = ref.read(profileProvider).valueOrNull;
      if (cached != null) {
        _sellerNameCtrl.text = cached.displayName ?? '';
        _sellerAddressCtrl.text = cached.address ?? '';
        _sellerSiretCtrl.text = cached.siret ?? '';
        _profileLoaded = true;
      } else if (!ref.read(profileProvider).isLoading) {
        // Pas de profil créé encore — afficher le formulaire vide
        _profileLoaded = true;
      }
    }

    final sessionsAsync =
        ref.watch(sessionsByProjectProvider(widget.projectId));
    final project = ref.watch(projectsProvider).valueOrNull
        ?.where((p) => p.id == widget.projectId)
        .firstOrNull;
    final client = project != null
        ? ref.watch(clientsProvider).valueOrNull
            ?.where((c) => c.id == project.clientId)
            .firstOrNull
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle facture'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: !_profileLoaded
          ? const Center(child: CircularProgressIndicator())
          : sessionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Erreur sessions : $e')),
              data: (sessions) {
                // Initialise la sélection à toutes les sessions
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_allInitialized && mounted) {
                    setState(() => _initSelection(sessions));
                  }
                });

                final hourlyRate = project?.hourlyRate ?? 0;
                final currency = project?.currency ?? 'EUR';
                final total = _computeTotal(sessions, hourlyRate);

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Profil vendeur
                          _SellerSection(
                            nameCtrl: _sellerNameCtrl,
                            addressCtrl: _sellerAddressCtrl,
                            siretCtrl: _sellerSiretCtrl,
                            expanded: _sellerNameCtrl.text.isEmpty,
                          ),
                          const SizedBox(height: 16),

                          // Sessions à facturer
                          _SectionTitle('Sessions à facturer',
                              '${_selected.length}/${sessions.length} sélectionnée(s)'),
                          const SizedBox(height: 8),
                          if (sessions.isEmpty)
                            const _EmptySessions()
                          else
                            ...sessions.map((s) => _SessionCheckTile(
                                  session: s,
                                  hourlyRate: hourlyRate,
                                  currency: currency,
                                  selected: _selected.contains(s.id),
                                  onChanged: (v) => setState(() {
                                    if (v == true) {
                                      _selected.add(s.id);
                                    } else {
                                      _selected.remove(s.id);
                                    }
                                  }),
                                )),
                          const SizedBox(height: 16),

                          // Total
                          _TotalCard(
                            total: total,
                            currency: currency,
                            sessionCount: _selected.length,
                          ),
                          const SizedBox(height: 80), // espace boutons
                        ],
                      ),
                    ),

                    // Boutons action
                    _ActionBar(
                      enabled: _selected.isNotEmpty && !_generating,
                      generating: _generating,
                      onPreview: () => _preview(
                        sessions,
                        project?.name ?? '',
                        hourlyRate,
                        currency,
                        client?.name ?? 'Client',
                        buyerAddress: client?.address,
                        buyerSiret: client?.siret,
                        buyerEmail: client?.email,
                      ),
                      onGenerate: () => _generateAndShare(
                        sessions: sessions,
                        clientId: project?.clientId ?? '',
                        projectName: project?.name ?? '',
                        hourlyRate: hourlyRate,
                        currency: currency,
                        buyerName: client?.name ?? 'Client',
                        buyerAddress: client?.address,
                        buyerSiret: client?.siret,
                        buyerEmail: client?.email,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ─── Section profil vendeur ───────────────────────────────────────────────────

class _SellerSection extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController siretCtrl;
  final bool expanded;

  const _SellerSection({
    required this.nameCtrl,
    required this.addressCtrl,
    required this.siretCtrl,
    required this.expanded,
  });

  @override
  State<_SellerSection> createState() => _SellerSectionState();
}

class _SellerSectionState extends State<_SellerSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.expanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outlined),
            title: const Text('Mes informations (vendeur)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            subtitle: widget.nameCtrl.text.isEmpty
                ? const Text('À compléter',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12))
                : Text(widget.nameCtrl.text,
                    style: const TextStyle(fontSize: 12)),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: widget.nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom / raison sociale *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: widget.addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: widget.siretCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SIRET (14 chiffres)',
                      prefixIcon: Icon(Icons.tag_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 14,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Titre de section ─────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String badge;

  const _SectionTitle(this.title, this.badge);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(badge,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Session checkable tile ───────────────────────────────────────────────────

class _SessionCheckTile extends StatelessWidget {
  final WorkSession session;
  final double hourlyRate;
  final String currency;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  const _SessionCheckTile({
    required this.session,
    required this.hourlyRate,
    required this.currency,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hours = (session.durationMinutes ?? 0) / 60.0;
    final amount = hours * hourlyRate;
    final dateFmt = DateFormat('dd/MM/yyyy', 'fr_FR');
    final euroFmt = NumberFormat.currency(
        locale: 'fr_FR',
        symbol: currency == 'EUR' ? '€' : currency,
        decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: CheckboxListTile(
        value: selected,
        onChanged: onChanged,
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(dateFmt.format(session.startedAt.toLocal()),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_fmtHours(hours)} × ${euroFmt.format(hourlyRate)}/h',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            if (session.notes != null && session.notes!.isNotEmpty)
              Text(session.notes!,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9CA3AF)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        secondary: Text(
          euroFmt.format(amount),
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

// ─── Total card ───────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final double total;
  final String currency;
  final int sessionCount;

  const _TotalCard({
    required this.total,
    required this.currency,
    required this.sessionCount,
  });

  @override
  Widget build(BuildContext context) {
    final euroFmt = NumberFormat.currency(
        locale: 'fr_FR',
        symbol: currency == 'EUR' ? '€' : currency,
        decimalDigits: 2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total HT',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(euroFmt.format(total),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$sessionCount session(s) sélectionnée(s)',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
              const Text('TVA non applicable — art. 293 B CGI',
                  style: TextStyle(color: Colors.white60, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Action bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool enabled;
  final bool generating;
  final VoidCallback onPreview;
  final VoidCallback onGenerate;

  const _ActionBar({
    required this.enabled,
    required this.generating,
    required this.onPreview,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Prévisualiser
          Expanded(
            child: OutlinedButton.icon(
              onPressed: enabled ? onPreview : null,
              icon: generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.visibility_outlined),
              label: const Text('Aperçu'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Générer & partager
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: enabled ? onGenerate : null,
              icon: generating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_outlined),
              label: const Text('Générer & Partager'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty sessions ───────────────────────────────────────────────────────────

class _EmptySessions extends StatelessWidget {
  const _EmptySessions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.history, size: 48, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 8),
            const Text('Aucune session terminée pour ce projet.'),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.go('/timer'),
              child: const Text('Démarrer le timer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper heures ────────────────────────────────────────────────────────────

String _fmtHours(double h) {
  final total = (h * 60).round();
  final hh = total ~/ 60;
  final mm = total % 60;
  if (hh == 0) return '${mm}min';
  if (mm == 0) return '${hh}h';
  return '${hh}h${mm.toString().padLeft(2, '0')}';
}
