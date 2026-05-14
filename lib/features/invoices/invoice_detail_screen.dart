import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/invoice.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/theme/cf_palette.dart';
import 'invoices_history_screen.dart' show StatusPill;
import 'pdf_viewer_screen.dart';

/// Détail facture en plein écran — ChronoFacture v2.
///
/// - Header maison (back + invoice number + status pill)
/// - Hero card client + montant
/// - Récap (émise / échéance / envoi)
/// - Sticky bottom : "Voir le PDF" + "Encaisser"
class InvoiceDetailScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<InvoiceDetailScreen> createState() =>
      _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends ConsumerState<InvoiceDetailScreen> {
  bool _loadingPdf = false;
  bool _sharing = false;
  bool _paying = false;

  Invoice? _resolve(WidgetRef ref) {
    final all = ref.watch(invoicesProvider).valueOrNull;
    return all?.where((i) => i.id == widget.invoiceId).firstOrNull;
  }

  Future<File?> _downloadPdf(Invoice inv) async {
    if (inv.pdfPath == null) return null;
    final bytes = await Supabase.instance.client.storage
        .from('invoices')
        .download(inv.pdfPath!);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${inv.invoiceNumber}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _viewPdf(Invoice inv) async {
    setState(() => _loadingPdf = true);
    try {
      final file = await _downloadPdf(inv);
      if (file == null) {
        if (mounted) {
          _showSnack('PDF non disponible pour cette facture');
        }
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(filePath: file.path, invoice: inv),
        ),
      );
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _loadingPdf = false);
    }
  }

  Future<void> _share(Invoice inv) async {
    if (_sharing) return;
    // Idempotency : si déjà envoyée, demander confirmation avant renvoi.
    if (inv.sentAt != null) {
      final shouldResend = await _confirmResend(inv);
      if (shouldResend != true || !mounted) return;
    }
    setState(() => _sharing = true);
    try {
      final file = await _downloadPdf(inv);
      if (file == null) {
        if (mounted) _showSnack('PDF non disponible.');
        return;
      }
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Facture ${inv.invoiceNumber}',
        text: 'Bonjour,\nVeuillez trouver ci-joint la facture ${inv.invoiceNumber}.',
      );

      if (result.status != ShareResultStatus.success) {
        // Utilisateur a annulé ou échec. Ne rien marquer en DB.
        if (mounted) _showSnack('Partage annulé.');
        return;
      }

      if (mounted) {
        await ref.read(invoicesProvider.notifier).markAsSentByNumber(
              inv.invoiceNumber,
              via: 'shared',
              to: inv.clientEmail,
            );
      }
      if (mounted) _showSnack('Facture envoyée.', success: true);
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<bool?> _confirmResend(Invoice inv) {
    final dt = inv.sentAt!.toLocal();
    final fmt = DateFormat('d MMM yyyy à HH:mm', 'fr_FR');
    final via = switch (inv.sentVia) {
      'email' => ' par email',
      'whatsapp' => ' par WhatsApp',
      _ => '',
    };
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CF.surface(context),
        title: Text(
          'Déjà envoyée',
          style: GoogleFonts.inter(
            fontSize: CFType.title,
            fontWeight: FontWeight.w700,
            color: CF.text(context),
          ),
        ),
        content: Text(
          'Cette facture a été envoyée$via le ${fmt.format(dt)}. La renvoyer ?',
          style: GoogleFonts.inter(color: CF.muted(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: GoogleFonts.inter(color: CF.muted(context))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CF.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Renvoyer'),
          ),
        ],
      ),
    );
  }

  Future<void> _markPaid(Invoice inv) async {
    if (_paying) return;
    if (inv.status == 'paid') {
      _showSnack('Déjà encaissée.');
      return;
    }
    setState(() => _paying = true);
    try {
      await ref.read(invoicesProvider.notifier).updateStatus(inv.id, 'paid');
      if (mounted) _showSnack('Facture encaissée.', success: true);
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _confirmDelete(Invoice inv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CF.surface(context),
        title: Text(
          'Supprimer cette facture ?',
          style: GoogleFonts.inter(
            fontSize: CFType.title,
            fontWeight: FontWeight.w700,
            color: CF.text(context),
          ),
        ),
        content: Text(
          '${inv.invoiceNumber} sera supprimée définitivement.',
          style: GoogleFonts.inter(color: CF.muted(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: GoogleFonts.inter(color: CF.muted(context))),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CF.bordeaux),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(invoicesProvider.notifier).delete(inv.id);
    if (mounted) {
      Navigator.of(context).pop();
      _showSnack('Facture supprimée');
    }
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: success ? CF.accentB : null,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final inv = _resolve(ref);

    if (inv == null) {
      return Scaffold(
        backgroundColor: CF.bg(context),
        body: SafeArea(
          child: Column(
            children: [
              _Header(invoice: null, onBack: () => Navigator.pop(context)),
              const Expanded(
                child: Center(child: CircularProgressIndicator(color: CF.primary)),
              ),
            ],
          ),
        ),
      );
    }

    final isPaid = inv.status == 'paid';
    final isCancelled = inv.status == 'cancelled';

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              invoice: inv,
              onBack: () => Navigator.pop(context),
              onDelete: () => _confirmDelete(inv),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  _ClientCard(invoice: inv),
                  const SizedBox(height: 16),
                  _AmountCard(invoice: inv),
                  const SizedBox(height: 18),
                  _DetailsBlock(invoice: inv),
                  if (inv.sentAt != null) ...[
                    const SizedBox(height: 18),
                    _SentBanner(invoice: inv),
                  ],
                ],
              ),
            ),
            if (!isCancelled)
              _StickyActions(
                invoice: inv,
                isPaid: isPaid,
                loadingPdf: _loadingPdf,
                sharing: _sharing,
                paying: _paying,
                onShare: () => _share(inv),
                onView: () => _viewPdf(inv),
                onPay: () => _markPaid(inv),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final Invoice? invoice;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  const _Header({
    required this.invoice,
    required this.onBack,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(LucideIcons.arrowLeft, color: CF.text(context)),
            splashRadius: 22,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'FACTURE',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CF.faint(context),
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      invoice?.invoiceNumber ?? '—',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CF.text(context),
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (invoice?.isTest == true) ...[
                      const SizedBox(width: 8),
                      const _TestBadge(),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon:
                  Icon(LucideIcons.trash2, size: 20, color: CF.faint(context)),
              splashRadius: 22,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// ─── Test badge ─────────────────────────────────────────────────────────────

class _TestBadge extends StatelessWidget {
  const _TestBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: CF.testBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'TEST',
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: CF.testFg,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─── Client + status card ──────────────────────────────────────────────────

class _ClientCard extends StatelessWidget {
  final Invoice invoice;
  const _ClientCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: CF.surface(context),
        borderRadius: BorderRadius.circular(CFRadius.xl),
        border: Border.all(color: CF.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invoice.clientName ?? 'Client',
                  style: GoogleFonts.inter(
                    fontSize: CFType.h2,
                    fontWeight: FontWeight.w700,
                    color: CF.text(context),
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(invoice: invoice, large: true),
            ],
          ),
          if (invoice.clientEmail != null && invoice.clientEmail!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              invoice.clientEmail!,
              style: GoogleFonts.inter(fontSize: 13, color: CF.muted(context)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Amount card ────────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final Invoice invoice;
  const _AmountCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.status == 'paid';
    final amount = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
      decimalDigits: 2,
    ).format(invoice.totalAmount);

    final gradient = isPaid
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [CF.accentA, CF.accentB],
          )
        : null;
    final fg = isPaid ? Colors.white : CF.text(context);
    final muted = isPaid
        ? Colors.white.withValues(alpha: 0.85)
        : CF.muted(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? CF.surface(context) : null,
        borderRadius: BorderRadius.circular(CFRadius.xxl),
        border: gradient == null
            ? Border.all(color: CF.border(context), width: 0.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPaid ? 'MONTANT ENCAISSÉ' : 'MONTANT FACTURÉ',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: GoogleFonts.inter(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: -1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'TVA non applicable — art. 293 B CGI',
            style: GoogleFonts.inter(fontSize: 11, color: muted),
          ),
        ],
      ),
    );
  }
}

// ─── Details block ─────────────────────────────────────────────────────────

class _DetailsBlock extends StatelessWidget {
  final Invoice invoice;
  const _DetailsBlock({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy', 'fr_FR');
    final issued = invoice.issuedAt ?? invoice.createdAt;

    final overdue = invoice.isOverdue;
    final dueLabel = invoice.dueAt != null
        ? dateFmt.format(invoice.dueAt!.toLocal())
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: CF.surface(context),
        borderRadius: BorderRadius.circular(CFRadius.xl),
        border: Border.all(color: CF.border(context), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _DetailRow(
            label: 'Émise le',
            value: dateFmt.format(issued.toLocal()),
          ),
          _Divider(),
          _DetailRow(
            label: 'Échéance',
            value: dueLabel,
            valueColor: overdue ? CF.bordeaux : null,
            trailing: overdue
                ? Text(
                    'En retard',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: CF.bordeaux,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: CF.muted(context)),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? CF.text(context),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      color: CF.border(context),
      indent: 18,
      endIndent: 18,
    );
  }
}

// ─── Sent banner ───────────────────────────────────────────────────────────

class _SentBanner extends StatelessWidget {
  final Invoice invoice;
  const _SentBanner({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final dt = invoice.sentAt!.toLocal();
    final fmt = DateFormat('d MMM yyyy à HH:mm', 'fr_FR');
    final via = switch (invoice.sentVia) {
      'email' => 'par email',
      'whatsapp' => 'par WhatsApp',
      _ => 'depuis l\'app',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: CF.paidBg,
        borderRadius: BorderRadius.circular(CFRadius.lg),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.send, size: 16, color: CF.paidFg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Envoyée $via le ${fmt.format(dt)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: CF.paidFg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sticky actions ────────────────────────────────────────────────────────

class _StickyActions extends StatelessWidget {
  final Invoice invoice;
  final bool isPaid;
  final bool loadingPdf;
  final bool sharing;
  final bool paying;
  final VoidCallback onShare;
  final VoidCallback onView;
  final VoidCallback onPay;

  const _StickyActions({
    required this.invoice,
    required this.isPaid,
    required this.loadingPdf,
    required this.sharing,
    required this.paying,
    required this.onShare,
    required this.onView,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
      decoration: BoxDecoration(
        color: CF.surface(context),
        border: Border(
          top: BorderSide(color: CF.border(context), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SecondaryButton(
              label: 'Voir le PDF',
              icon: LucideIcons.fileText,
              loading: loadingPdf,
              onTap: loadingPdf ? null : onView,
            ),
          ),
          const SizedBox(width: 10),
          if (isPaid)
            Expanded(
              child: _SecondaryButton(
                label: 'Envoyer',
                icon: LucideIcons.send,
                loading: sharing,
                onTap: sharing ? null : onShare,
              ),
            )
          else
            Expanded(
              child: _PrimaryButton(
                label: 'Encaisser',
                color: CF.accentB,
                icon: LucideIcons.checkCircle,
                loading: paying,
                onTap: paying ? null : onPay,
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? color.withValues(alpha: 0.55) : color,
      borderRadius: BorderRadius.circular(CFRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CFRadius.md),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CF.surfaceAlt(context),
      borderRadius: BorderRadius.circular(CFRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CFRadius.md),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CF.primary,
                  ),
                )
              else
                Icon(icon, size: 18, color: CF.text(context)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CF.text(context),
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
