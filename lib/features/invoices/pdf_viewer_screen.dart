import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/invoice.dart';
import '../../core/providers/invoices_provider.dart';

class PdfViewerScreen extends ConsumerWidget {
  final String filePath;
  final Invoice invoice;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    required this.invoice,
  });

  Invoice _currentInvoice(WidgetRef ref) {
    final all = ref.watch(invoicesProvider).valueOrNull;
    return all?.where((i) => i.id == invoice.id).firstOrNull ?? invoice;
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: 'Facture ${invoice.invoiceNumber}',
        text: 'Facture ${invoice.invoiceNumber}',
      );
      await ref.read(invoicesProvider.notifier).markAsSentByNumber(
            invoice.invoiceNumber,
            via: 'shared',
          );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur envoi : $e')));
    }
  }

  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(invoicesProvider.notifier)
          .updateStatus(invoice.id, 'paid');
      messenger.showSnackBar(
        const SnackBar(content: Text('Facture marquée comme payée')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  String _formatDate(DateTime d) {
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(d.toLocal());
  }

  /// Libellé d'envoi affiché à l'utilisateur. Le canal stocké en base
  /// (sent_via) reste en anglais ; seul l'affichage est francisé.
  String _sentLabel(String? sentVia) {
    return switch (sentVia) {
      'email' => 'Envoyée par email',
      'whatsapp' => 'Envoyée par WhatsApp',
      _ => 'Partagée',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = _currentInvoice(ref);
    final isPaid = inv.status == 'paid';

    return Scaffold(
      appBar: AppBar(
        title: Text('Facture ${inv.invoiceNumber}'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: SvgPicture.asset(
              'assets/icons/Facture-actif.svg',
              width: 22,
              height: 22,
            ),
            onPressed: () => _share(context, ref),
            tooltip: 'Partager',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PDFView(filePath: filePath),
          ),
          if (inv.sentAt != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: const Color(0xFFF3F4F6),
              child: Row(
                children: [
                  const Icon(LucideIcons.checkCircle,
                      size: 16, color: Color(0xFF22C55E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_sentLabel(inv.sentVia)} le ${_formatDate(inv.sentAt!)}'
                      '${inv.sentTo != null ? ' · ${inv.sentTo}' : ''}',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 64,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _share(context, ref),
                  icon: const Icon(LucideIcons.share2, size: 18),
                  label: const Text('Partager'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF305DA8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (!isPaid) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _markAsPaid(context, ref),
                    icon: const Icon(LucideIcons.checkCircle, size: 18),
                    label: const Text('Marquer payée'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
}
