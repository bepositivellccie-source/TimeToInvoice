import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/invoice.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/theme/app_colors.dart';

class InvoicesHistoryScreen extends ConsumerStatefulWidget {
  const InvoicesHistoryScreen({super.key});

  @override
  ConsumerState<InvoicesHistoryScreen> createState() =>
      _InvoicesHistoryScreenState();
}

class _InvoicesHistoryScreenState
    extends ConsumerState<InvoicesHistoryScreen> {
  /// null = tous les mois
  DateTime? _filterMonth;

  /// null = tous les statuts, 'sent' | 'overdue' | 'paid'
  String? _filterStatus;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _searchQuery) setState(() => _searchQuery = q);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Factures')),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (invoices) {
          if (invoices.isEmpty) return const _EmptyInvoices();

          // Mois disponibles pour le filtre
          final months = _availableMonths(invoices);

          // Filtre combiné : recherche + statut + mois
          final displayed = invoices.where((inv) {
            // Filtre recherche
            if (_searchQuery.isNotEmpty) {
              final name = (inv.clientName ?? '').toLowerCase();
              if (!name.contains(_searchQuery)) {
                return false;
              }
            }
            // Filtre statut
            if (_filterStatus == 'sent' &&
                !(inv.status == 'sent' && !inv.isOverdue)) {
              return false;
            }
            if (_filterStatus == 'overdue' && !inv.isOverdue) {
              return false;
            }
            if (_filterStatus == 'paid' && inv.status != 'paid') {
              return false;
            }
            // Filtre mois
            if (_filterMonth != null) {
              final d = inv.createdAt.toLocal();
              if (d.year != _filterMonth!.year ||
                  d.month != _filterMonth!.month) {
                return false;
              }
            }
            return true;
          }).toList();

          // Regrouper par mois
          final grouped = _groupByMonth(displayed);

          return Column(
            children: [
              // ── Barre de recherche ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client…',
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFBDBDBD),
                    ),
                    prefixIcon: const Icon(LucideIcons.search,
                        size: 18, color: Color(0xFF9CA3AF)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () => _searchCtrl.clear(),
                            child: const Icon(LucideIcons.x,
                                size: 16, color: Color(0xFF9CA3AF)),
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).brightness ==
                            Brightness.dark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFF3F4F6),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              // ── Chips filtre statut ─────────────────────────────
              _StatusFilterBar(
                selected: _filterStatus,
                onSelected: (s) => setState(() => _filterStatus = s),
              ),

              // ── Chips filtre mois ──────────────────────────────
              _MonthFilterBar(
                months: months,
                selected: _filterMonth,
                onSelected: (m) => setState(() => _filterMonth = m),
              ),

              // ── Liste groupée par mois ────────────────────────
              Expanded(
                child: displayed.isEmpty
                    ? const Center(
                        child: Text('Aucune facture ce mois',
                            style: TextStyle(color: Color(0xFF9CA3AF))))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                        itemCount: grouped.length,
                        itemBuilder: (context, gi) {
                          final key = grouped.keys.elementAt(gi);
                          final monthInvoices = grouped[key]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (gi > 0) const SizedBox(height: 16),
                              // ── En-tête mois ────────────────────
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 4, bottom: 8),
                                child: Text(
                                  _monthLabel(key),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary(context),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              // ── Factures du mois ────────────────
                              for (int i = 0;
                                  i < monthInvoices.length;
                                  i++) ...[
                                _InvoiceTile(
                                  invoice: monthInvoices[i],
                                  onTap: () => _showDetail(
                                      context, monthInvoices[i]),
                                  onDelete: () =>
                                      _confirmDelete(monthInvoices[i]),
                                ),
                                if (i < monthInvoices.length - 1)
                                  const SizedBox(height: 8),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, List<Invoice>> _groupByMonth(List<Invoice> invoices) {
    final map = <String, List<Invoice>>{};
    for (final inv in invoices) {
      final d = inv.createdAt.toLocal();
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      (map[key] ??= []).add(inv);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final dt = DateTime(year, month);
    final raw = DateFormat('MMMM yyyy', 'fr_FR').format(dt);
    return raw[0].toUpperCase() + raw.substring(1);
  }

  List<DateTime> _availableMonths(List<Invoice> invoices) {
    final set = <String, DateTime>{};
    for (final inv in invoices) {
      final d = inv.createdAt.toLocal();
      final key = '${d.year}-${d.month}';
      set.putIfAbsent(key, () => DateTime(d.year, d.month));
    }
    final list = set.values.toList()
      ..sort((a, b) => b.compareTo(a));
    return list;
  }

  Future<void> _confirmDelete(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette facture ?'),
        content: Text(
            'La facture ${invoice.invoiceNumber} sera supprimée définitivement.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(invoicesProvider.notifier).delete(invoice.id);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Facture supprimée'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }

  void _showDetail(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InvoiceDetailSheet(invoice: invoice),
    );
  }
}

// ─── Status filter bar ─────────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _StatusFilterBar({
    required this.selected,
    required this.onSelected,
  });

  static const _items = <(String?, String, Color)>[
    (null, 'Tout', Color(0xFF6B7280)),
    ('sent', 'À encaisser', Color(0xFF2563EB)),
    ('overdue', 'En retard', Color(0xFFDC2626)),
    ('paid', 'Payées', Color(0xFF16A34A)),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          for (int i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildChip(_items[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildChip((String?, String, Color) item) {
    final (value, label, color) = item;
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Month filter bar ──────────────────────────────────────────────────────

class _MonthFilterBar extends StatelessWidget {
  final List<DateTime> months;
  final DateTime? selected;
  final ValueChanged<DateTime?> onSelected;

  const _MonthFilterBar({
    required this.months,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final fmt = DateFormat('MMM yyyy', 'fr_FR');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _chip(
            label: 'Tout',
            isSelected: selected == null,
            color: primary,
            onTap: () => onSelected(null),
          ),
          for (final m in months) ...[
            const SizedBox(width: 8),
            _chip(
              label: fmt.format(m),
              isSelected: selected != null &&
                  selected!.year == m.year &&
                  selected!.month == m.month,
              color: primary,
              onTap: () => onSelected(m),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(25) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? color : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Invoice tile — swipe gauche → delete ──────────────────────────────────

class _InvoiceTile extends StatefulWidget {
  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _InvoiceTile({
    required this.invoice,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_InvoiceTile> createState() => _InvoiceTileState();
}

class _InvoiceTileState extends State<_InvoiceTile> {
  double _dragOffset = 0;

  static const _statusColors = {
    'draft': Color(0xFF6B7280),
    'sent': Color(0xFF2563EB),
    'paid': Color(0xFF16A34A),
    'cancelled': Color(0xFF9CA3AF),
  };

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final dateFmt = DateFormat('dd MMMM yyyy', 'fr_FR');
    final euroFmt = NumberFormat.currency(
        locale: 'fr_FR',
        symbol: '€',
        decimalDigits: 2);
    final screenWidth = MediaQuery.sizeOf(context).width;

    final statusColor = inv.isOverdue
        ? AppColors.danger
        : _statusColors[inv.status] ?? const Color(0xFF6B7280);

    final deleteOpacity = (_dragOffset.abs() / 80).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          // ── Fond rouge delete ─────────────────────────────────
          if (_dragOffset < 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: Opacity(
                  opacity: deleteOpacity,
                  child: const Icon(LucideIcons.trash2,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          // ── Card glissante ────────────────────────────────────
          AnimatedContainer(
            duration: Duration(milliseconds: _dragOffset == 0 ? 200 : 0),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: (d) {
                setState(() {
                  _dragOffset =
                      (_dragOffset + d.delta.dx).clamp(-screenWidth, 0.0);
                });
              },
              onHorizontalDragEnd: (d) {
                final velocity = d.primaryVelocity ?? 0;
                if (_dragOffset < -screenWidth * 0.30 || velocity < -800) {
                  widget.onDelete();
                  setState(() => _dragOffset = 0);
                } else {
                  setState(() => _dragOffset = 0);
                }
              },
              child: Material(
                color: Theme.of(context).cardTheme.color ??
                    Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Icône statut
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(LucideIcons.fileText,
                              color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        // 2. Colonne centrale
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.clientName ?? '—',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111827),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    dateFmt.format(
                                        inv.createdAt.toLocal()),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withAlpha(20),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      inv.displayStatus,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'N° ${inv.invoiceNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 3. Montant aligné haut droite
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              euroFmt.format(inv.totalAmount),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        // 4. Chevron
                        const Icon(LucideIcons.chevronRight,
                            color: Color(0xFF9CA3AF), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Invoice detail bottom sheet ───────────────────────────────────────────

class _InvoiceDetailSheet extends ConsumerStatefulWidget {
  final Invoice invoice;

  const _InvoiceDetailSheet({required this.invoice});

  @override
  ConsumerState<_InvoiceDetailSheet> createState() =>
      _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends ConsumerState<_InvoiceDetailSheet> {
  bool _sending = false;

  /// Construit le corps d'email standard.
  String _emailBody(Invoice inv, String formattedAmount) {
    return 'Bonjour,\n\n'
        'Veuillez trouver ci-joint la facture ${inv.invoiceNumber} '
        'd\'un montant de $formattedAmount.\n\n'
        'Date d\'émission : ${DateFormat('dd/MM/yyyy', 'fr_FR').format(inv.createdAt.toLocal())}\n'
        'Échéance : 30 jours\n\n'
        'Merci de votre confiance.\n\n'
        'Cordialement';
  }

  /// Envoie la facture par email (PDF en pièce jointe via share sheet,
  /// ou mailto: si le PDF n'est plus disponible localement).
  Future<void> _sendEmail(Invoice inv) async {
    setState(() => _sending = true);

    final euroFmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: '€', decimalDigits: 2);
    final amount = euroFmt.format(inv.totalAmount);
    final subject = 'Facture ${inv.invoiceNumber} — ${inv.clientName ?? ""}';
    final body = _emailBody(inv, amount);

    try {
      // 1. Fichier local ?
      final dir = await getApplicationDocumentsDirectory();
      final localFile = File('${dir.path}/Facture_${inv.invoiceNumber}.pdf');

      if (await localFile.exists()) {
        // Partage depuis le fichier local
        await Share.shareXFiles(
          [XFile(localFile.path, mimeType: 'application/pdf')],
          subject: subject,
          text: body,
        );
      } else if (inv.pdfPath != null) {
        // 2. Télécharger depuis Supabase Storage
        final bytes = await Supabase.instance.client.storage
            .from('invoices')
            .download(inv.pdfPath!);
        final tmpDir = await getTemporaryDirectory();
        final tmpFile =
            File('${tmpDir.path}/Facture_${inv.invoiceNumber}.pdf');
        await tmpFile.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(tmpFile.path, mimeType: 'application/pdf')],
          subject: subject,
          text: body,
        );
      } else {
        // 3. Fallback : mailto sans pièce jointe
        final uri = Uri(
          scheme: 'mailto',
          path: inv.clientEmail ?? '',
          queryParameters: {'subject': subject, 'body': body},
        );
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }

      // Mettre à jour le statut → envoyée
      if (inv.status == 'draft' && mounted) {
        await ref
            .read(invoicesProvider.notifier)
            .updateStatus(inv.id, 'sent');
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text('Facture envoyée'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur envoi : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    final dateFmt = DateFormat('dd MMMM yyyy', 'fr_FR');
    final euroFmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: '€', decimalDigits: 2);
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Numéro facture ──
          Text(
            inv.invoiceNumber,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${inv.clientName ?? 'Client'} · ${dateFmt.format(inv.createdAt.toLocal())}',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),

          // ── Montant ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primary.withAlpha(15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('Total HT',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                const SizedBox(height: 4),
                Text(
                  euroFmt.format(inv.totalAmount),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: primary),
                ),
                const SizedBox(height: 4),
                const Text('TVA non applicable — art. 293 B CGI',
                    style: TextStyle(fontSize: 10, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Actions ──

          // Envoyer par email (draft ou sent — relance)
          if (inv.status != 'paid' && inv.status != 'cancelled')
            _actionButton(
              context: context,
              icon: _sending
                  ? null
                  : (inv.status == 'sent'
                      ? LucideIcons.forward
                      : LucideIcons.mail),
              label: inv.status == 'sent' ? 'Relancer par email' : 'Envoyer par email',
              color: const Color(0xFF2563EB),
              loading: _sending,
              onTap: _sending ? null : () => _sendEmail(inv),
            ),

          if (inv.status == 'draft') ...[
            const SizedBox(height: 10),
            _actionButton(
              context: context,
              icon: LucideIcons.send,
              label: 'Marquer comme envoyée',
              color: const Color(0xFF6B7280),
              onTap: () {
                ref
                    .read(invoicesProvider.notifier)
                    .updateStatus(inv.id, 'sent');
                Navigator.pop(context);
              },
            ),
          ],
          if (inv.status == 'draft' || inv.status == 'sent') ...[
            const SizedBox(height: 10),
            _actionButton(
              context: context,
              icon: LucideIcons.checkCircle,
              label: 'Marquer comme payée',
              color: const Color(0xFF16A34A),
              onTap: () {
                ref
                    .read(invoicesProvider.notifier)
                    .updateStatus(inv.id, 'paid');
                Navigator.pop(context);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required IconData? icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: color),
              )
            : Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(80)),
          minimumSize: const Size(0, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.fileText,
                size: 64, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text('Aucune facture',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'Générez votre première facture depuis l\'écran Sessions d\'un projet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
