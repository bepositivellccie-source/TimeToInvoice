import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/models/invoice.dart';
import '../../core/providers/invoices_provider.dart';
import 'pdf_viewer_screen.dart';

class PdfGalleryScreen extends ConsumerStatefulWidget {
  const PdfGalleryScreen({super.key});

  @override
  ConsumerState<PdfGalleryScreen> createState() => _PdfGalleryScreenState();
}

class _PdfGalleryScreenState extends ConsumerState<PdfGalleryScreen> {
  int _columns = 1;
  String _searchQuery = '';
  bool _loadingPdf = false;
  int? _selectedYear;
  int? _selectedMonth;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Invoice> _filterInvoices(List<Invoice> all) {
    var result = all.where((i) => i.pdfPath != null).toList();

    if (_selectedYear != null) {
      result =
          result.where((i) => i.createdAt.year == _selectedYear).toList();
    }
    if (_selectedMonth != null) {
      result =
          result.where((i) => i.createdAt.month == _selectedMonth).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((i) {
        final name = (i.clientName ?? '').toLowerCase();
        final num = i.invoiceNumber.toLowerCase();
        return name.contains(q) || num.contains(q);
      }).toList();
    }

    return result;
  }

  List<int> _extractYears(List<Invoice> invoices) {
    final years = invoices
        .where((i) => i.pdfPath != null)
        .map((i) => i.createdAt.year)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    return years;
  }

  List<int> _monthsForYear(List<Invoice> invoices, int year) {
    final months = invoices
        .where((i) => i.pdfPath != null && i.createdAt.year == year)
        .map((i) => i.createdAt.month)
        .toSet()
        .toList()
      ..sort();
    return months;
  }

  String _monthName(int m) {
    const names = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return names[m - 1];
  }

  Future<void> _openPdf(Invoice inv) async {
    if (inv.pdfPath == null || _loadingPdf) return;

    setState(() => _loadingPdf = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final bytes = await Supabase.instance.client.storage
          .from('invoices')
          .download(inv.pdfPath!);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${inv.invoiceNumber}.pdf');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() => _loadingPdf = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: file.path,
            invoice: inv,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loadingPdf = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mes factures',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() => _columns = 1),
            icon: SvgPicture.asset(
              'assets/icons/pdf.actif.svg',
              width: 22,
              height: 22,
              colorFilter: ColorFilter.mode(
                _columns == 1
                    ? const Color(0xFF305DA8)
                    : const Color(0xFF9CA3AF),
                BlendMode.srcIn,
              ),
            ),
            tooltip: '1 colonne',
          ),
          IconButton(
            onPressed: () => setState(() => _columns = 2),
            icon: Icon(
              LucideIcons.layoutGrid,
              color: _columns == 2 ? primary : const Color(0xFF9CA3AF),
              size: 20,
            ),
            tooltip: '2 colonnes',
          ),
          IconButton(
            onPressed: () => setState(() => _columns = 3),
            icon: Icon(
              LucideIcons.grid,
              color: _columns == 3 ? primary : const Color(0xFF9CA3AF),
              size: 20,
            ),
            tooltip: '3 colonnes',
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Barre de recherche ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un client...',
                    hintStyle: const TextStyle(
                        fontSize: 14, color: Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(LucideIcons.search, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withAlpha(10)
                            : const Color(0xFFF3F4F6),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // ── Contenu ────────────────────────────────────────────
              Expanded(
                child: invoicesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Erreur : $e',
                        style: const TextStyle(color: Color(0xFFDC2626))),
                  ),
                  data: (all) {
                    final years = _extractYears(all);
                    final months = _selectedYear != null
                        ? _monthsForYear(all, _selectedYear!)
                        : const <int>[];
                    final invoices = _filterInvoices(all);

                    return Column(
                      children: [
                        if (years.length > 1)
                          _FilterRow(
                            children: [
                              _YearChip(
                                label: 'Tout',
                                selected: _selectedYear == null,
                                onTap: () => setState(() {
                                  _selectedYear = null;
                                  _selectedMonth = null;
                                }),
                              ),
                              for (final y in years)
                                _YearChip(
                                  label: '$y',
                                  selected: _selectedYear == y,
                                  onTap: () => setState(() {
                                    _selectedYear = y;
                                    _selectedMonth = null;
                                  }),
                                ),
                            ],
                          ),
                        if (_selectedYear != null && months.isNotEmpty)
                          _FilterRow(
                            children: [
                              _MonthChip(
                                label: 'Tout',
                                selected: _selectedMonth == null,
                                onTap: () => setState(
                                    () => _selectedMonth = null),
                              ),
                              for (final m in months)
                                _MonthChip(
                                  label: _monthName(m),
                                  selected: _selectedMonth == m,
                                  onTap: () => setState(
                                      () => _selectedMonth = m),
                                ),
                            ],
                          ),
                        Expanded(
                          child: invoices.isEmpty
                              ? _EmptyState(
                                  hasSearch: _searchQuery.isNotEmpty ||
                                      _selectedYear != null ||
                                      _selectedMonth != null,
                                )
                              : _columns == 1
                                  ? _buildList(invoices)
                                  : _buildGrid(invoices),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          if (_loadingPdf)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x80000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<Invoice> invoices) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PdfListTile(
        invoice: invoices[i],
        onTap: () => _openPdf(invoices[i]),
      ),
    );
  }

  Widget _buildGrid(List<Invoice> invoices) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: _columns == 2 ? 0.85 : 0.75,
      ),
      itemCount: invoices.length,
      itemBuilder: (context, i) => _PdfGridCard(
        invoice: invoices[i],
        onTap: () => _openPdf(invoices[i]),
      ),
    );
  }
}

// ─── Filter row (scroll horizontal) ────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  final List<Widget> children;
  const _FilterRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Year chip ─────────────────────────────────────────────────────────────

class _YearChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _YearChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF305DA8)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Month chip ────────────────────────────────────────────────────────────

class _MonthChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MonthChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF305DA8)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Status badge ──────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = switch (status) {
      'paid' => (label: 'Payée', color: const Color(0xFF22C55E)),
      'sent' => (label: 'Envoyée', color: const Color(0xFF305DA8)),
      'draft' => (label: 'À envoyer', color: const Color(0xFF9CA3AF)),
      _ => null,
    };
    if (config == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: config.color.withAlpha(31),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          color: config.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─── Helper : détection facture en retard (via due_at, pas via status) ────

bool _isOverdue(Invoice invoice) {
  return invoice.status != 'paid' &&
      invoice.status != 'draft' &&
      invoice.dueAt != null &&
      invoice.dueAt!.isBefore(DateTime.now());
}

// ─── Helper icon SVG selon statut (overdue > paid > sent > draft) ─────────

({String asset, Color color}) _pdfIconConfig(Invoice invoice) {
  if (_isOverdue(invoice)) {
    return (
      asset: 'assets/icons/pdf.actif.svg',
      color: const Color(0xFFEF4444),
    );
  }
  switch (invoice.status) {
    case 'paid':
      return (
        asset: 'assets/icons/pdf.actif.svg',
        color: const Color(0xFF22C55E),
      );
    case 'sent':
      return (
        asset: 'assets/icons/pdf.actif.svg',
        color: const Color(0xFF305DA8),
      );
    default:
      return (
        asset: 'assets/icons/pdf-inactifs.svg',
        color: const Color(0xFF9CA3AF),
      );
  }
}

// ─── List tile (1 colonne) ─────────────────────────────────────────────────

class _PdfListTile extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const _PdfListTile({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy', 'fr_FR');
    final euroFmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: '\u20AC', decimalDigits: 2);
    final iconCfg = _pdfIconConfig(invoice);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Icone PDF ──
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SvgPicture.asset(
                    iconCfg.asset,
                    width: 32,
                    height: 32,
                    colorFilter:
                        ColorFilter.mode(iconCfg.color, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Infos ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne 1 : nom + montant + chevron
                    Row(
                      children: [
                        Text(
                          invoice.clientName ?? 'Client',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          euroFmt.format(invoice.totalAmount),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight,
                            size: 18, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Ligne 2 : date
                    Text(
                      dateFmt.format(invoice.createdAt.toLocal()),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Ligne 3 : N° + Spacer + badge statut
                    Row(
                      children: [
                        Text(
                          'N\u00B0 ${invoice.invoiceNumber}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const Spacer(),
                        _StatusBadge(status: invoice.status),
                      ],
                    ),
                    // Ligne 4 (overdue only) : date d'échéance alignée à droite
                    if (_isOverdue(invoice) && invoice.dueAt != null) ...[
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '\u00C9ch. ${DateFormat('d MMM', 'fr_FR').format(invoice.dueAt!.toLocal())}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Grid card (2 ou 3 colonnes) ───────────────────────────────────────────

class _PdfGridCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onTap;

  const _PdfGridCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yy', 'fr_FR');
    final euroFmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: '\u20AC', decimalDigits: 2);
    final iconCfg = _pdfIconConfig(invoice);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icone PDF ──
              SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: SvgPicture.asset(
                    iconCfg.asset,
                    width: 28,
                    height: 28,
                    colorFilter:
                        ColorFilter.mode(iconCfg.color, BlendMode.srcIn),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // ── Nom client ──
              Text(
                invoice.clientName ?? 'Client',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // ── Badge statut ──
              _StatusBadge(status: invoice.status),
              const SizedBox(height: 2),
              // ── Montant ──
              Text(
                euroFmt.format(invoice.totalAmount),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF305DA8)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              // ── Date ──
              Text(
                dateFmt.format(invoice.createdAt.toLocal()),
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF9CA3AF)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;

  const _EmptyState({this.hasSearch = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasSearch ? LucideIcons.searchX : LucideIcons.files,
            size: 48,
            color: const Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch
                ? 'Aucune facture trouv\u00E9e'
                : 'Aucun PDF disponible',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 4),
          Text(
            hasSearch
                ? 'Essayez d\'autres filtres'
                : 'G\u00E9n\u00E9rez votre premi\u00E8re facture\npour la retrouver ici',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}
