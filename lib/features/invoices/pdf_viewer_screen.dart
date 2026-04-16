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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.mail, color: Color(0xFF2563EB)),
                title: const Text('Envoyer par email'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareByEmail(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.messageCircle,
                    color: Color(0xFF25D366)),
                title: const Text('Envoyer par WhatsApp'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareWhatsApp(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.share2, color: Color(0xFF6B7280)),
                title: const Text('Autres options'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareGeneric(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareByEmail(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: 'Facture ${invoice.invoiceNumber}',
        text: 'Bonjour,\n\n'
            'Veuillez trouver ci-joint la facture ${invoice.invoiceNumber}.\n\n'
            'Cordialement',
      );
      await ref.read(invoicesProvider.notifier).markAsSentByNumber(
            invoice.invoiceNumber,
            via: 'email',
            to: invoice.clientEmail,
          );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur envoi : $e')));
    }
  }

  Future<void> _shareWhatsApp(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        text: 'Facture ${invoice.invoiceNumber}',
      );
      await ref.read(invoicesProvider.notifier).markAsSentByNumber(
            invoice.invoiceNumber,
            via: 'WhatsApp',
          );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur envoi : $e')));
    }
  }

  Future<void> _shareGeneric(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/pdf')],
        subject: 'Facture ${invoice.invoiceNumber}',
      );
      await ref.read(invoicesProvider.notifier).markAsSentByNumber(
            invoice.invoiceNumber,
            via: 'autre',
          );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur envoi : $e')));
    }
  }

  String _formatDate(DateTime d) {
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = _currentInvoice(ref);

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
            tooltip: 'Renvoyer',
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
                      'Envoyée${inv.sentVia != null ? ' par ${inv.sentVia}' : ''} '
                      'le ${_formatDate(inv.sentAt!)}'
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
    );
  }
}
