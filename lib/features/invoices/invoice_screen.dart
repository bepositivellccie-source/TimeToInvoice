import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/invoice.dart';
import '../../core/models/invoice_data.dart';
import '../../core/models/profile.dart';
import '../../core/models/session.dart';
import '../../core/providers/clients_provider.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/project_billing_status_provider.dart';
import '../../core/providers/projects_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/test_mode_provider.dart';
import '../../core/theme/cf_palette.dart';
import '../../core/utils/invoice_number.dart';
import '../../core/utils/invoice_pdf.dart';
import '../../core/utils/paywall_gate.dart';
import 'pdf_viewer_screen.dart';

const bool kAdminMode = false;

/// Flow facturation — 3 étapes : Sessions → Échéance → Récap.
/// Header custom + progress bar 3 segments.
class InvoiceScreen extends ConsumerStatefulWidget {
  final String projectId;

  const InvoiceScreen({super.key, required this.projectId});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  // ── Wizard state ──────────────────────────────────────────────────────────
  int _step = 0;
  final Set<String> _selected = {};
  bool _allInitialized = false;

  DateTime _billingDate = DateTime.now();
  int _paymentDelay = 30; // 15 | 30 | 60

  bool _generating = false;

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _initSelection(List<WorkSession> sessions) {
    if (!_allInitialized && sessions.isNotEmpty) {
      _selected.addAll(sessions.map((s) => s.id));
      _allInitialized = true;
    }
  }

  double _computeTotal(List<WorkSession> sessions, double hourlyRate) =>
      sessions
          .where((s) => _selected.contains(s.id))
          .fold(0.0, (sum, s) => sum + (s.workedSeconds / 3600.0) * hourlyRate);

  int _computeSelectedSeconds(List<WorkSession> sessions) =>
      sessions
          .where((s) => _selected.contains(s.id))
          .fold(0, (sum, s) => sum + s.workedSeconds);

  static String _fmtHHMMSS(int secs) {
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String _fmtAmount(double v, String currency) {
    final fmt = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: currency == 'EUR' ? '€' : currency,
      decimalDigits: 2,
    );
    return fmt.format(v);
  }

  bool _isProfileComplete(Profile? p) =>
      p != null &&
      (p.displayName?.isNotEmpty ?? false) &&
      (p.siret?.isNotEmpty ?? false);

  DateTime get _dueDate => _billingDate.add(Duration(days: _paymentDelay));

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final sessionsAsync =
        ref.watch(unbilledSessionsByProjectProvider(widget.projectId));
    final project = ref
        .watch(projectsProvider)
        .valueOrNull
        ?.where((p) => p.id == widget.projectId)
        .firstOrNull;
    final client = project != null
        ? ref
            .watch(clientsProvider)
            .valueOrNull
            ?.where((c) => c.id == project.clientId)
            .firstOrNull
        : null;

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: profileAsync.isLoading
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
                  final selectedSecs = _computeSelectedSeconds(sessions);

                  return Column(
                    children: [
                      _Header(step: _step, totalSteps: 3, onBack: _onBack),
                      Expanded(
                        child: _StepBody(
                          step: _step,
                          sessions: sessions,
                          selected: _selected,
                          onToggle: (id, value) => setState(() {
                            if (value) {
                              _selected.add(id);
                            } else {
                              _selected.remove(id);
                            }
                          }),
                          hourlyRate: hourlyRate,
                          currency: currency,
                          clientName: client?.name ?? 'Client',
                          totalSecs: selectedSecs,
                          totalAmount: total,
                          billingDate: _billingDate,
                          paymentDelay: _paymentDelay,
                          dueDate: _dueDate,
                          projectName: project?.name ?? '',
                          onPickBillingDate: _pickBillingDate,
                          onSelectDelay: (d) =>
                              setState(() => _paymentDelay = d),
                          profile: profile,
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
                          isProfileComplete: _isProfileComplete(profile),
                        ),
                      ),
                      _StepActions(
                        step: _step,
                        canAdvance: _canAdvance(sessions),
                        generating: _generating,
                        onNext: _onNext,
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
      ),
    );
  }

  bool _canAdvance(List<WorkSession> sessions) {
    if (_step == 0) return _selected.isNotEmpty;
    return true;
  }

  void _onNext() {
    if (_step < 2) setState(() => _step++);
  }

  void _onBack() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _pickBillingDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _billingDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 30)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null) setState(() => _billingDate = picked);
  }

  // ── Génération PDF + insert DB (préservé) ─────────────────────────────────

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
    final isTest = ref.read(testModeProvider);

    // Mode test : exclu du quota freemium (chantier 8)
    if (!kAdminMode && !isTest) {
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
        isTest: isTest,
      );

      final bytes = await buildInvoicePdf(data);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Facture_$invoiceNumber.pdf');
      await file.writeAsBytes(bytes);

      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now();

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

      final inserted = await supabase
          .from('invoices')
          .insert({
            'user_id': userId,
            'client_id': clientId,
            'project_id': widget.projectId,
            'invoice_number': invoiceNumber,
            'total_amount': data.totalTTC,
            'status': 'draft',
            'pdf_path': storagePath,
            'issued_at': _billingDate.toIso8601String(),
            'due_at': _dueDate.toIso8601String(),
            'client_name': buyerName,
            'is_test': isTest,
          })
          .select()
          .single();

      final invoice = Invoice.fromJson(inserted);

      final invoiceId = inserted['id'] as String;
      final sessionRows = _selected
          .map((sessionId) => {
                'invoice_id': invoiceId,
                'session_id': sessionId,
              })
          .toList();
      if (sessionRows.isNotEmpty) {
        await supabase.from('invoice_sessions').insert(sessionRows);
      }

      // Refs pour éviter `use_build_context_synchronously` après gap async
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: file.path,
            invoice: invoice,
          ),
        ),
      );

      ref.invalidate(invoicesProvider);
      ref.invalidate(unbilledSessionsByProjectProvider(widget.projectId));
      ref.invalidate(sessionsByProjectProvider(widget.projectId));
      ref.invalidate(projectBillingStatusProvider);

      // Émission immédiate aussi : créé `now` (utile pour le rappel optimistic)
      debugPrint('Invoice generated at $now');
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
    bool isTest = false,
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
      issueDate: _billingDate,
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
      isTest: isTest,
    );
  }
}

// ─── Header (back + caption + progress) ────────────────────────────────────

class _Header extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  const _Header({
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(LucideIcons.arrowLeft,
                    size: 22, color: CF.text(context)),
                onPressed: onBack,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'NOUVELLE FACTURE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CF.faint(context),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (var i = 0; i < totalSteps; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= step
                            ? CF.primary
                            : CF.surfaceAlt(context),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (i < totalSteps - 1) const SizedBox(width: 8),
                ],
                const SizedBox(width: 10),
                Text(
                  '${step + 1}/$totalSteps',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CF.muted(context),
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

// ─── Step body switcher ────────────────────────────────────────────────────

class _StepBody extends StatelessWidget {
  final int step;
  final List<WorkSession> sessions;
  final Set<String> selected;
  final void Function(String, bool) onToggle;
  final double hourlyRate;
  final String currency;
  final String clientName;
  final int totalSecs;
  final double totalAmount;

  final DateTime billingDate;
  final int paymentDelay;
  final DateTime dueDate;
  final VoidCallback onPickBillingDate;
  final ValueChanged<int> onSelectDelay;

  final String projectName;
  final Profile? profile;
  final bool generating;
  final VoidCallback onGenerate;
  final bool isProfileComplete;

  const _StepBody({
    required this.step,
    required this.sessions,
    required this.selected,
    required this.onToggle,
    required this.hourlyRate,
    required this.currency,
    required this.clientName,
    required this.totalSecs,
    required this.totalAmount,
    required this.billingDate,
    required this.paymentDelay,
    required this.dueDate,
    required this.onPickBillingDate,
    required this.onSelectDelay,
    required this.projectName,
    required this.profile,
    required this.generating,
    required this.onGenerate,
    required this.isProfileComplete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: switch (step) {
        0 => _Step1Sessions(
            key: const ValueKey(0),
            sessions: sessions,
            selected: selected,
            onToggle: onToggle,
            hourlyRate: hourlyRate,
            currency: currency,
            clientName: clientName,
            totalSecs: totalSecs,
            totalAmount: totalAmount,
          ),
        1 => _Step2Echeance(
            key: const ValueKey(1),
            billingDate: billingDate,
            paymentDelay: paymentDelay,
            dueDate: dueDate,
            onPickBillingDate: onPickBillingDate,
            onSelectDelay: onSelectDelay,
          ),
        _ => _Step3Recap(
            key: const ValueKey(2),
            sessionCount: selected.length,
            totalSecs: totalSecs,
            totalAmount: totalAmount,
            currency: currency,
            billingDate: billingDate,
            dueDate: dueDate,
            clientName: clientName,
            projectName: projectName,
            profile: profile,
            isProfileComplete: isProfileComplete,
          ),
      },
    );
  }
}

// ─── Step 1 — Sessions ─────────────────────────────────────────────────────

class _Step1Sessions extends StatelessWidget {
  final List<WorkSession> sessions;
  final Set<String> selected;
  final void Function(String, bool) onToggle;
  final double hourlyRate;
  final String currency;
  final String clientName;
  final int totalSecs;
  final double totalAmount;

  const _Step1Sessions({
    super.key,
    required this.sessions,
    required this.selected,
    required this.onToggle,
    required this.hourlyRate,
    required this.currency,
    required this.clientName,
    required this.totalSecs,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE d MMM', 'fr_FR');
    final timeFmt = DateFormat('HH:mm', 'fr_FR');
    final hourlyLabel = hourlyRate % 1 == 0
        ? hourlyRate.toInt().toString()
        : hourlyRate.toStringAsFixed(2);

    return Column(
      children: [
        _StepTitle(
          title: 'Quelles sessions ?',
          subtitle: 'Décochez celles que vous ne voulez pas facturer.',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            children: [
              if (sessions.isEmpty)
                _Empty()
              else
                Container(
                  decoration: BoxDecoration(
                    color: CF.surface(context),
                    borderRadius: BorderRadius.circular(CFRadius.xl),
                    border:
                        Border.all(color: CF.border(context), width: 0.5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < sessions.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 0.5,
                              thickness: 0.5,
                              color: CF.border(context)),
                        _SessionRow(
                          session: sessions[i],
                          index: sessions.length - i,
                          dateLabel: dateFmt.format(
                              sessions[i].startedAt.toLocal()),
                          timeLabel: timeFmt.format(
                              sessions[i].startedAt.toLocal()),
                          selected: selected.contains(sessions[i].id),
                          onChanged: (v) =>
                              onToggle(sessions[i].id, v),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              if (sessions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text.rich(
                    TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: CF.faint(context),
                      ),
                      children: [
                        const TextSpan(text: 'Client · '),
                        TextSpan(
                          text: clientName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: CF.muted(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: ' · Tarif $hourlyLabel €/h'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (sessions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: CF.surface(context),
                borderRadius: BorderRadius.circular(CFRadius.lg),
                border: Border.all(color: CF.border(context), width: 0.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${selected.length} sessions'.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CF.faint(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _InvoiceScreenState._fmtHHMMSS(totalSecs),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: CF.text(context),
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'TOTAL',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CF.faint(context),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _InvoiceScreenState._fmtAmount(
                            totalAmount, currency),
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: CF.muted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final WorkSession session;
  final int index;
  final String dateLabel;
  final String timeLabel;
  final bool selected;
  final ValueChanged<bool> onChanged;

  const _SessionRow({
    required this.session,
    required this.index,
    required this.dateLabel,
    required this.timeLabel,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: selected ? CF.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? CF.primary : CF.border(context),
                  width: selected ? 0 : 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check,
                      size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Séance $index',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CF.text(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dateLabel · $timeLabel',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: CF.muted(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _InvoiceScreenState._fmtHHMMSS(session.workedSeconds),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CF.text(context),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2 — Échéance ─────────────────────────────────────────────────────

class _Step2Echeance extends StatelessWidget {
  final DateTime billingDate;
  final int paymentDelay;
  final DateTime dueDate;
  final VoidCallback onPickBillingDate;
  final ValueChanged<int> onSelectDelay;

  const _Step2Echeance({
    super.key,
    required this.billingDate,
    required this.paymentDelay,
    required this.dueDate,
    required this.onPickBillingDate,
    required this.onSelectDelay,
  });

  @override
  Widget build(BuildContext context) {
    final billingFmt = DateFormat('d MMMM y', 'fr_FR');
    final today = DateTime.now();
    final isToday = billingDate.year == today.year &&
        billingDate.month == today.month &&
        billingDate.day == today.day;
    final billingLabel = isToday
        ? "Aujourd'hui · ${billingFmt.format(billingDate)}"
        : billingFmt.format(billingDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      children: [
        _StepTitle(
          title: 'Quelle échéance ?',
          subtitle: 'Quand le paiement doit-il être encaissé ?',
        ),
        InkWell(
          onTap: onPickBillingDate,
          borderRadius: BorderRadius.circular(CFRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: CF.surface(context),
              borderRadius: BorderRadius.circular(CFRadius.lg),
              border: Border.all(color: CF.border(context), width: 0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: CF.surfaceAlt(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(LucideIcons.calendar,
                      size: 20, color: CF.chrono),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DATE DE FACTURATION',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CF.faint(context),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        billingLabel,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CF.text(context),
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight,
                    size: 16, color: CF.faint(context)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'DÉLAI DE PAIEMENT',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: CF.faint(context),
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: CF.surfaceAlt(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              for (final d in const [15, 30, 60])
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelectDelay(d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: paymentDelay == d
                            ? CF.surface(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: paymentDelay == d
                            ? const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$d jours',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: paymentDelay == d
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: paymentDelay == d
                              ? CF.text(context)
                              : CF.muted(context),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: CF.primary.withValues(alpha: 0.05),
            border:
                Border.all(color: CF.primary.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(CFRadius.lg),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.checkCircle,
                  size: 18, color: CF.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: CF.text(context),
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Échéance fixée au '),
                      TextSpan(
                        text: billingFmt.format(dueDate),
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: CF.text(context),
                          fontFeatures: const [
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 3 — Récap ────────────────────────────────────────────────────────

class _Step3Recap extends StatelessWidget {
  final int sessionCount;
  final int totalSecs;
  final double totalAmount;
  final String currency;
  final DateTime billingDate;
  final DateTime dueDate;
  final String clientName;
  final String projectName;
  final Profile? profile;
  final bool isProfileComplete;

  const _Step3Recap({
    super.key,
    required this.sessionCount,
    required this.totalSecs,
    required this.totalAmount,
    required this.currency,
    required this.billingDate,
    required this.dueDate,
    required this.clientName,
    required this.projectName,
    required this.profile,
    required this.isProfileComplete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMMM y', 'fr_FR');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      children: [
        _StepTitle(
          title: 'On y va ?',
          subtitle: 'Vérifiez avant de l\'envoyer.',
        ),
        if (!isProfileComplete) ...[
          _ProfileWarning(),
          const SizedBox(height: 12),
        ],

        // Mini PDF + résumé
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CF.surface(context),
            borderRadius: BorderRadius.circular(CFRadius.xl),
            border: Border.all(color: CF.border(context), width: 0.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MiniPdfThumb(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FACTURE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CF.faint(context),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'En attente de numéro',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CF.muted(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: CF.muted(context),
                          ),
                        ),
                        if (projectName.isNotEmpty)
                          Text(
                            projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: CF.faint(context),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Récap rows
        Container(
          decoration: BoxDecoration(
            color: CF.surface(context),
            borderRadius: BorderRadius.circular(CFRadius.xl),
            border: Border.all(color: CF.border(context), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _RecapRow(label: 'Sessions', value: '$sessionCount sessions'),
              _RecapDivider(),
              _RecapRow(
                label: 'Temps total',
                value: _InvoiceScreenState._fmtHHMMSS(totalSecs),
                tabular: true,
              ),
              _RecapDivider(),
              _RecapRow(
                  label: 'Émise le',
                  value: dateFmt.format(billingDate),
                  tabular: true),
              _RecapDivider(),
              _RecapRow(
                  label: 'Échéance',
                  value: dateFmt.format(dueDate),
                  tabular: true),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Total discret
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: CF.surfaceAlt(context),
            borderRadius: BorderRadius.circular(CFRadius.lg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total à encaisser',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: CF.muted(context),
                ),
              ),
              Text(
                _InvoiceScreenState._fmtAmount(totalAmount, currency),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CF.text(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniPdfThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CF.g200, width: 0.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(LucideIcons.fileText, size: 14, color: CF.chrono),
              Text(
                'F-2026',
                style: GoogleFonts.inter(
                  fontSize: 5,
                  color: CF.g400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 2, color: CF.g200),
          const SizedBox(height: 2),
          Container(height: 2, width: 50, color: CF.g200),
          const SizedBox(height: 8),
          for (var i = 0; i < 4; i++) ...[
            Row(
              children: [
                Expanded(child: Container(height: 1.5, color: CF.g100)),
                const SizedBox(width: 2),
                Container(width: 16, height: 1.5, color: CF.g100),
              ],
            ),
            const SizedBox(height: 2),
          ],
          const Spacer(),
          Container(
            height: 2,
            decoration: BoxDecoration(
              color: CF.accentB.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  final String label;
  final String value;
  final bool tabular;

  const _RecapRow({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              color: CF.muted(context),
            ),
          ),
          Text(
            value,
            style: tabular
                ? GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CF.text(context),
                    letterSpacing: 0.3,
                  )
                : GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CF.text(context),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RecapDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
        height: 0.5, thickness: 0.5, color: CF.border(context));
  }
}

class _ProfileWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle,
              size: 18, color: Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Profil vendeur incomplet (nom + SIRET requis).',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF991B1B),
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
              'Compléter',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step actions (sticky CTA) ─────────────────────────────────────────────

class _StepActions extends StatelessWidget {
  final int step;
  final bool canAdvance;
  final bool generating;
  final VoidCallback onNext;
  final VoidCallback onGenerate;

  const _StepActions({
    required this.step,
    required this.canAdvance,
    required this.generating,
    required this.onNext,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final isFinal = step == 2;
    final color = isFinal ? CF.accentB : CF.primary;
    final label = isFinal ? 'Générer la facture' : 'Suivant';

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: 54,
        child: FilledButton(
          onPressed: !canAdvance || generating
              ? null
              : (isFinal ? onGenerate : onNext),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: CF.surfaceAlt(context),
            disabledForegroundColor: CF.muted(context),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            elevation: 0,
            shadowColor: color.withValues(alpha: 0.4),
          ),
          child: generating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Step title ────────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StepTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: CF.text(context),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: CF.muted(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty session state ───────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: CF.surfaceAlt(context),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.clock,
                  size: 24, color: CF.muted(context)),
            ),
            const SizedBox(height: 14),
            Text(
              'Aucune session à facturer',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CF.text(context),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => context.go('/timer'),
              child: const Text('Démarrer le chrono'),
            ),
          ],
        ),
      ),
    );
  }
}
