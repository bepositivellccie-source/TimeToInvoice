import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/models/invoice.dart';
import '../../core/providers/invoices_provider.dart';
import '../../core/theme/cf_palette.dart';
import 'invoice_detail_screen.dart';

/// Liste des factures — refonte ChronoFacture v2.
///
/// - Header maison (pas d'AppBar)
/// - Recherche + filtres statut (chips inline)
/// - Liste groupée par mois (Inter + JetBrainsMono)
/// - Tap → push InvoiceDetailScreen plein écran
class InvoicesHistoryScreen extends ConsumerStatefulWidget {
  const InvoicesHistoryScreen({super.key});

  @override
  ConsumerState<InvoicesHistoryScreen> createState() =>
      _InvoicesHistoryScreenState();
}

class _InvoicesHistoryScreenState
    extends ConsumerState<InvoicesHistoryScreen> {
  /// null = tous statuts, sinon 'pending' (draft+sent non overdue) | 'overdue' | 'paid'
  String? _statusFilter;

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

  bool _matchesStatus(Invoice inv) {
    switch (_statusFilter) {
      case null:
        return true;
      case 'pending':
        return !inv.isOverdue && (inv.status == 'draft' || inv.status == 'sent');
      case 'overdue':
        return inv.isOverdue;
      case 'paid':
        return inv.status == 'paid';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);

    return Scaffold(
      backgroundColor: CF.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _SearchField(controller: _searchCtrl),
            ),
            _FilterRow(
              current: _statusFilter,
              onChanged: (v) => setState(() => _statusFilter = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: invoicesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: CF.primary)),
                error: (e, _) => Center(
                  child: Text(
                    'Erreur : $e',
                    style: GoogleFonts.inter(color: CF.muted(context)),
                  ),
                ),
                data: (all) {
                  if (all.isEmpty) return const _EmptyInvoices();

                  final filtered = all.where((inv) {
                    if (_searchQuery.isNotEmpty) {
                      final n = (inv.clientName ?? '').toLowerCase();
                      final num = inv.invoiceNumber.toLowerCase();
                      if (!n.contains(_searchQuery) &&
                          !num.contains(_searchQuery)) {
                        return false;
                      }
                    }
                    return _matchesStatus(inv);
                  }).toList();

                  if (filtered.isEmpty) return const _EmptyFiltered();

                  return RefreshIndicator(
                    color: CF.primary,
                    onRefresh: () async {
                      ref.invalidate(invoicesProvider);
                      await ref.read(invoicesProvider.future);
                    },
                    child: _GroupedList(
                      invoices: filtered,
                      onTap: (inv) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              InvoiceDetailScreen(invoiceId: inv.id),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Mes factures',
              style: GoogleFonts.inter(
                fontSize: CFType.h1,
                fontWeight: FontWeight.w700,
                color: CF.text(context),
                letterSpacing: -0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search ─────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CF.surfaceAlt(context),
        borderRadius: BorderRadius.circular(CFRadius.md),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.inter(fontSize: CFType.body, color: CF.text(context)),
        decoration: InputDecoration(
          hintText: 'Rechercher un client ou un n°…',
          hintStyle: GoogleFonts.inter(
            fontSize: CFType.body,
            color: CF.faint(context),
          ),
          prefixIcon:
              Icon(LucideIcons.search, size: 18, color: CF.faint(context)),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(LucideIcons.x, size: 16, color: CF.faint(context)),
                  onPressed: controller.clear,
                  splashRadius: 18,
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }
}

// ─── Filter row ─────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final String? current;
  final ValueChanged<String?> onChanged;

  const _FilterRow({required this.current, required this.onChanged});

  static const _items = <(String?, String)>[
    (null, 'Toutes'),
    ('pending', 'À encaisser'),
    ('overdue', 'En retard'),
    ('paid', 'Payées'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final item = _items[i];
          final selected = current == item.$1;
          return _Chip(
            label: item.$2,
            selected: selected,
            onTap: () => onChanged(item.$1),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? CF.primary : CF.surfaceAlt(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : CF.muted(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Grouped list ──────────────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  final List<Invoice> invoices;
  final ValueChanged<Invoice> onTap;

  const _GroupedList({required this.invoices, required this.onTap});

  Map<String, List<Invoice>> _group() {
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

  String _label(String key) {
    final p = key.split('-');
    final y = int.parse(p[0]);
    final m = int.parse(p[1]);
    final raw = DateFormat('MMMM yyyy', 'fr_FR').format(DateTime(y, m));
    return raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _group();
    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      itemCount: keys.length,
      itemBuilder: (context, gi) {
        final key = keys[gi];
        final list = grouped[key]!;
        return Padding(
          padding: EdgeInsets.only(top: gi == 0 ? 0 : 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  _label(key).toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: CF.faint(context),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: CF.surface(context),
                  borderRadius: BorderRadius.circular(CFRadius.xl),
                  border: Border.all(color: CF.border(context), width: 0.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (int i = 0; i < list.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 0.5,
                          thickness: 0.5,
                          color: CF.border(context),
                        ),
                      _InvoiceRow(
                        invoice: list[i],
                        onTap: () => onTap(list[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Invoice row ───────────────────────────────────────────────────────────

class _InvoiceRow extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const _InvoiceRow({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM', 'fr_FR');
    final amount = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: '€',
      decimalDigits: 2,
    ).format(invoice.totalAmount);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StatusDot(invoice: invoice),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.clientName ?? '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: CFType.subtitle,
                      fontWeight: FontWeight.w600,
                      color: CF.text(context),
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: CF.faint(context),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        '  ·  ${dateFmt.format(invoice.createdAt.toLocal())}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: CF.muted(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: CFType.subtitle,
                    fontWeight: FontWeight.w600,
                    color: CF.text(context),
                    letterSpacing: -0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                StatusPill(invoice: invoice),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status dot (left of row) ──────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final Invoice invoice;
  const _StatusDot({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(invoice);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

Color _statusColor(Invoice inv) {
  if (inv.isOverdue) return CF.bordeaux;
  return switch (inv.status) {
    'paid' => CF.accentB,
    'sent' => CF.primary,
    'draft' => CF.g400,
    'cancelled' => CF.g400,
    _ => CF.g400,
  };
}

// ─── Status pill (used in row + reused elsewhere) ──────────────────────────

class StatusPill extends StatelessWidget {
  final Invoice invoice;
  final bool large;

  const StatusPill({
    super.key,
    required this.invoice,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _pillConfig(invoice);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 12 : 8,
        vertical: large ? 5 : 2,
      ),
      decoration: BoxDecoration(
        color: config.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.label,
        style: GoogleFonts.inter(
          fontSize: large ? 12 : 10.5,
          fontWeight: FontWeight.w700,
          color: config.fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

({String label, Color bg, Color fg}) _pillConfig(Invoice inv) {
  if (inv.isOverdue) {
    return (label: 'En retard', bg: CF.overdueBg, fg: CF.overdueFg);
  }
  switch (inv.status) {
    case 'paid':
      return (label: 'Payée', bg: CF.paidBg, fg: CF.paidFg);
    case 'sent':
      return (
        label: 'À encaisser',
        bg: CF.primary.withValues(alpha: 0.10),
        fg: CF.primary,
      );
    case 'draft':
      return (label: 'À envoyer', bg: CF.pendingBg, fg: CF.pendingFg);
    case 'cancelled':
      return (label: 'Annulée', bg: CF.pendingBg, fg: CF.pendingFg);
    default:
      return (label: inv.status, bg: CF.pendingBg, fg: CF.pendingFg);
  }
}

// ─── Empty states ──────────────────────────────────────────────────────────

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: CF.surfaceAlt(context),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.fileText, size: 26, color: CF.faint(context)),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune facture',
              style: GoogleFonts.inter(
                fontSize: CFType.h3,
                fontWeight: FontWeight.w700,
                color: CF.text(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Génère ta première facture depuis un projet ou l\'accueil.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: CF.muted(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFiltered extends StatelessWidget {
  const _EmptyFiltered();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.searchX, size: 32, color: CF.faint(context)),
            const SizedBox(height: 12),
            Text(
              'Aucune facture ne correspond',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: CF.muted(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
