import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/invoice.dart';
import '../../core/models/invoice_data.dart';
import '../../core/models/profile.dart';
import '../../core/models/session.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/utils/invoice_number.dart';
import '../../core/utils/invoice_pdf.dart';
import '../../core/utils/paywall_gate.dart';
import 'pdf_viewer_screen.dart';

// TODO: false avant release
const bool kAdminMode = true;

class InvoiceScreen extends ConsumerStatefulWidget {
  final String projectId;

  const InvoiceScreen({super.key, required this.projectId});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  // Sessions sélectionnées
  final Set<String> _selected = {};
  bool _allInitialized = false;

  bool _generating = false;

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
        .fold(0.0, (sum, s) => sum + (s.workedSeconds / 3600.0) * hourlyRate);
  }

  // ─── Construction InvoiceData ─────────────────────────────────────────────

  InvoiceData _buildInvoiceData({
    required String invoiceNumber,
    required List<WorkSession> sessions,
    required Profile profile,
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
      final hours = s.workedSeconds / 3600.0;
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

    final tvaRate = profile.tvaRegime == 'assujetti'
        ? (profile.tvaRate ?? 20.0)
        : 0.0;

    return InvoiceData(
      invoiceNumber: invoiceNumber,
      issueDate: DateTime.now(),
      sellerName: profile.displayName ??
          (Supabase.instance.client.auth.currentUser?.email ?? 'Vendeur'),
      sellerAddress: profile.fullAddress,
      sellerSiret: profile.siret,
      sellerVatNumber: profile.tvaNumber,
      buyerName: buyerName,
      buyerAddress: buyerAddress,
      buyerSiret: buyerSiret,
      buyerEmail: buyerEmail,
      lines: lines,
      currency: currency,
      tvaRate: tvaRate,
    );
  }

  // ─── Génération + insert DB + ouverture PdfViewerScreen ─────────────────

  Future<void> _generate({
    required List<WorkSession> sessions,
    required Profile profile,
    required String clientId,
    required double hourlyRate,
    required String currency,
    required String buyerName,
    String? buyerAddress,
    String? buyerSiret,
    String? buyerEmail,
  }) async {
    if (!kAdminMode) {
      if (!await checkInvoiceQuota(context, ref)) return;
    }

    setState(() => _generating = true);
    try {
      final supabase = Supabase.instance.client;
      final invoiceNumber = await nextInvoiceNumber(supabase);

      final data = _buildInvoiceData(
        invoiceNumber: invoiceNumber,
        sessions: sessions,
        profile: profile,
        hourlyRate: hourlyRate,
        currency: currency,
        buyerName: buyerName,
        buyerAddress: buyerAddress,
        buyerSiret: buyerSiret,
        buyerEmail: buyerEmail,
      );

      final bytes = await buildInvoicePdf(data);

      // Sauvegarde locale du PDF
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Facture_$invoiceNumber.pdf');
      await file.writeAsBytes(bytes);

      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now();

      // Upload PDF dans Supabase Storage
      String? storagePath;
      try {
        storagePath = '$userId/$invoiceNumber.pdf';
        await supabase.storage.from('invoices').uploadBinary(
              storagePath,
              bytes,
              fileOptions: const FileOptions(
                contentType: 'application/pdf',
                upsert: true,
              ),
            );
      } catch (e) {
        debugPrint('Upload Storage error: $e');
        storagePath = null;
      }

      // Insert en DB + récupération de la ligne créée
      final inserted = await supabase
          .from('invoices')
          .insert({
            'user_id': userId,
            'client_id': clientId,
            'invoice_number': invoiceNumber,
            'total_amount': data.totalTTC,
            'status': 'draft',
            'pdf_path': storagePath,
            'issued_at': now.toIso8601String(),
            'due_at': now.add(const Duration(days: 30)).toIso8601String(),
            'client_name': buyerName,
          })
          .select()
          .single();

      final invoice = Invoice.fromJson(inserted);

      if (!mounted) return;

      // Navigation vers le viewer embarqué
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: file.path,
            invoice: invoice,
          ),
        ),
      );

      // Au retour → rafraîchir la liste
      ref.invalidate(invoicesProvider);
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
    final profileAsync = ref.watch(profileProvider);
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
      body: profileAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : sessionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Erreur sessions : $e')),
              data: (sessions) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_allInitialized && mounted) {
                    setState(() => _initSelection(sessions));
                  }
                });

                final hourlyRate = project?.hourlyRate ?? 0;
                final currency = project?.currency ?? 'EUR';
                final total = _computeTotal(sessions, hourlyRate);
                final profile = profileAsync.valueOrNull;

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Bandeau profil vendeur
                          _SellerBanner(profile: profile),
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
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),

                    // Bouton Générer
                    _ActionBar(
                      enabled: _selected.isNotEmpty &&
                          !_generating &&
                          _isProfileComplete(profile),
                      generating: _generating,
                      onGenerate: () {
                        if (profile == null) return;
                        _generate(
                          sessions: sessions,
                          profile: profile,
                          clientId: project?.clientId ?? '',
                          hourlyRate: hourlyRate,
                          currency: currency,
                          buyerName: client?.name ?? 'Client',
                          buyerAddress: client?.fullAddress,
                          buyerSiret: client?.siret,
                          buyerEmail: client?.email,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }

  bool _isProfileComplete(Profile? p) =>
      p != null &&
      (p.displayName?.isNotEmpty ?? false) &&
      (p.siret?.isNotEmpty ?? false);
}

// ─── Bandeau profil vendeur ───────────────────────────────────────────────

class _SellerBanner extends StatelessWidget {
  final Profile? profile;

  const _SellerBanner({required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final complete = p != null &&
        (p.displayName?.isNotEmpty ?? false) &&
        (p.siret?.isNotEmpty ?? false);

    if (complete) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.checkCircle,
                color: Color(0xFF22C55E), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${p.displayName} · SIRET ${p.siret}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Profil vendeur incomplet',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF991B1B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/profile'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Compléter mon profil',
              style: TextStyle(fontWeight: FontWeight.w600),
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
    final hours = session.workedSeconds / 3600.0;
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
              Flexible(
                child: Text(euroFmt.format(total),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('$sessionCount session(s)',
                  style: const TextStyle(
                      color: Colors.white60, fontSize: 11)),
              const Spacer(),
              const Flexible(
                child: Text('TVA non applicable — art. 293 B CGI',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
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
  final VoidCallback onGenerate;

  const _ActionBar({
    required this.enabled,
    required this.generating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
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
      child: FilledButton(
        onPressed: enabled ? onGenerate : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: generating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Text('Générer'),
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
