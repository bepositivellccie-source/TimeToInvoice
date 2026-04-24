import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/invoice.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/theme/cf_palette.dart';
import 'invoices_history_screen.dart' show StatusPill;

/// Visualisation PDF — refonte ChronoFacture v2.
class PdfViewerScreen extends ConsumerStatefulWidget {
  final String filePath;
  final Invoice invoice;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.invoice,
  });

  @override
  ConsumerState<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends ConsumerState<PdfViewerScreen> {
  bool _sharing = false;

  Invoice _current() {
    final all = ref.watch(invoicesProvider).valueOrNull;
    return all?.where((i) => i.id == widget.invoice.id).firstOrNull ??
        widget.invoice;
  }

  Future<void> _share(Invoice inv) async {
    setState(() => _sharing = true);
    try {
      final result = await Share.shareXFiles(
        [XFile(widget.filePath, mimeType: 'application/pdf')],
        subject: 'Facture ${inv.invoiceNumber}',
        text: 'Facture ${inv.invoiceNumber}',
      );

      if (result.status != ShareResultStatus.success) {
        // Utilisateur a annulé ou échec — ne rien marquer en DB
        if (mounted) _showSnack('Partage annulé');
        return;
      }

      await ref.read(invoicesProvider.notifier).markAsSentByNumber(
            inv.invoiceNumber,
            via: 'shared',
          );
      if (mounted) _showSnack('Facture envoyée', success: true);
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _markPaid(Invoice inv) async {
    try {
      await ref.read(invoicesProvider.notifier).updateStatus(inv.id, 'paid');
      if (mounted) _showSnack('Facture encaissée', success: true);
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
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
    final inv = _current();
    final isPaid = inv.status == 'paid';
    final isCancelled = inv.status == 'cancelled';

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(invoice: inv, onBack: () => Navigator.pop(context)),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                decoration: BoxDecoration(
                  color: CF.surface(context),
                  borderRadius: BorderRadius.circular(CFRadius.xl),
                  border: Border.all(color: CF.border(context), width: 0.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: PDFView(filePath: widget.filePath),
              ),
            ),
            if (inv.sentAt != null) _SentChip(invoice: inv),
            if (!isCancelled)
              _BottomBar(
                invoice: inv,
                isPaid: isPaid,
                sharing: _sharing,
                onShare: () => _share(inv),
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
  final Invoice invoice;
  final VoidCallback onBack;

  const _Header({required this.invoice, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
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
                  'PDF',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CF.faint(context),
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  invoice.invoiceNumber,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CF.text(context),
                  ),
                ),
              ],
            ),
          ),
          StatusPill(invoice: invoice),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

// ─── Sent chip ─────────────────────────────────────────────────────────────

class _SentChip extends StatelessWidget {
  final Invoice invoice;
  const _SentChip({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final dt = invoice.sentAt!.toLocal();
    final fmt = DateFormat('d MMM · HH:mm', 'fr_FR');
    final via = switch (invoice.sentVia) {
      'email' => 'email',
      'whatsapp' => 'WhatsApp',
      _ => 'app',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CF.paidBg,
          borderRadius: BorderRadius.circular(CFRadius.md),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.send, size: 14, color: CF.paidFg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Envoyée ${fmt.format(dt)} · $via',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: CF.paidFg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom bar ────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final Invoice invoice;
  final bool isPaid;
  final bool sharing;
  final VoidCallback onShare;
  final VoidCallback onPay;

  const _BottomBar({
    required this.invoice,
    required this.isPaid,
    required this.sharing,
    required this.onShare,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + bottom),
      decoration: BoxDecoration(
        color: CF.surface(context),
        border: Border(top: BorderSide(color: CF.border(context), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Btn(
              label: 'Envoyer',
              icon: LucideIcons.send,
              color: CF.primary,
              loading: sharing,
              onTap: sharing ? null : onShare,
            ),
          ),
          if (!isPaid) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _Btn(
                label: 'Encaisser',
                icon: LucideIcons.checkCircle,
                color: CF.accentB,
                onTap: onPay,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;

  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    this.loading = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
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
