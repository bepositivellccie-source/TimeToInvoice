import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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

          // Filtre par mois
          final displayed = _filterMonth == null
              ? invoices
              : invoices.where((inv) {
                  final d = inv.createdAt.toLocal();
                  return d.year == _filterMonth!.year &&
                      d.month == _filterMonth!.month;
                }).toList();

          return Column(
            children: [
              // ── Chips filtre mois ──────────────────────────────
              _MonthFilterBar(
                months: months,
                selected: _filterMonth,
                onSelected: (m) => setState(() => _filterMonth = m),
              ),

              // ── Liste ─────────────────────────────────────────
              Expanded(
                child: displayed.isEmpty
                    ? const Center(
                        child: Text('Aucune facture ce mois',
                            style: TextStyle(color: Color(0xFF9CA3AF))))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: displayed.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) => _InvoiceTile(
                          invoice: displayed[i],
                          onTap: () =>
                              _showDetail(context, displayed[i]),
                          onDelete: () => _confirmDelete(displayed[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
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
    final dateFmt = DateFormat('dd/MM/yyyy', 'fr_FR');
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
                  child: const Icon(Icons.delete_outline,
                      color: Colors.white, size: 26),
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
                      children: [
                        // ── Icône facture ────────────────────────
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.receipt_long_outlined,
                              color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        // ── Infos ───────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                inv.invoiceNumber,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${inv.clientName ?? 'Client'} · ${dateFmt.format(inv.createdAt.toLocal())}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // ── Montant + statut ────────────────────
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              euroFmt.format(inv.totalAmount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                inv.displayStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right,
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

class _InvoiceDetailSheet extends ConsumerWidget {
  final Invoice invoice;

  const _InvoiceDetailSheet({required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            invoice.invoiceNumber,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${invoice.clientName ?? 'Client'} · ${dateFmt.format(invoice.createdAt.toLocal())}',
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
                  euroFmt.format(invoice.totalAmount),
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
          if (invoice.status == 'draft')
            _actionButton(
              context: context,
              icon: Icons.send_outlined,
              label: 'Marquer comme envoyée',
              color: const Color(0xFF2563EB),
              onTap: () {
                ref
                    .read(invoicesProvider.notifier)
                    .updateStatus(invoice.id, 'sent');
                Navigator.pop(context);
              },
            ),
          if (invoice.status == 'draft' || invoice.status == 'sent') ...[
            const SizedBox(height: 10),
            _actionButton(
              context: context,
              icon: Icons.check_circle_outline,
              label: 'Marquer comme payée',
              color: const Color(0xFF16A34A),
              onTap: () {
                ref
                    .read(invoicesProvider.notifier)
                    .updateStatus(invoice.id, 'paid');
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
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
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
            Icon(Icons.receipt_long_outlined,
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
