import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Invoice> _filterInvoices(List<Invoice> all) {
    final withPdf = all.where((i) => i.pdfPath != null).toList();
    if (_searchQuery.isEmpty) return withPdf;
    final q = _searchQuery.toLowerCase();
    return withPdf.where((i) {
      final name = (i.clientName ?? '').toLowerCase();
      final num = i.invoiceNumber.toLowerCase();
      return name.contains(q) || num.contains(q);
    }).toList();
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
            icon: Icon(
              LucideIcons.layoutList,
              color: _columns == 1 ? primary : const Color(0xFF9CA3AF),
              size: 20,
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
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withAlpha(10)
                    : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                final invoices = _filterInvoices(all);
                if (invoices.isEmpty) {
                  return _EmptyState(hasSearch: _searchQuery.isNotEmpty);
                }
                return _columns == 1
                    ? _buildList(invoices)
                    : _buildGrid(invoices);
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

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Icone PDF ──
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.fileText,
                    color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 12),
              // ── Infos ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.clientName ?? 'Client',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFmt.format(invoice.createdAt.toLocal()),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'N\u00B0 ${invoice.invoiceNumber}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
              // ── Montant ──
              Text(
                euroFmt.format(invoice.totalAmount),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: Color(0xFF9CA3AF)),
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

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Icone PDF ──
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.fileText,
                    color: Color(0xFFDC2626), size: 24),
              ),
              const SizedBox(height: 10),
              // ── Nom client ──
              Text(
                invoice.clientName ?? 'Client',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // ── Montant ──
              Text(
                euroFmt.format(invoice.totalAmount),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF305DA8)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // ── Date ──
              Text(
                dateFmt.format(invoice.createdAt.toLocal()),
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9CA3AF)),
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
                ? 'Essayez un autre terme de recherche'
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
