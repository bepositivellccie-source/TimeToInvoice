import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice_data.dart';

// ─── Couleurs ─────────────────────────────────────────────────────────────────
const _blue = PdfColor.fromInt(0xFF1A56DB);
const _gray50 = PdfColor.fromInt(0xFFF8FAFC);
const _gray100 = PdfColor.fromInt(0xFFF3F4F6);
const _gray200 = PdfColor.fromInt(0xFFE5E7EB);
const _gray500 = PdfColor.fromInt(0xFF6B7280);
const _gray700 = PdfColor.fromInt(0xFF374151);
const _gray900 = PdfColor.fromInt(0xFF111827);

/// Génère un PDF de facture conforme au droit français.
/// Mentions légales incluses :
///  – Numéro séquentiel unique YYYY-NNN
///  – Date d'émission, infos vendeur/acheteur, SIRET
///  – Détail des prestations (date, durée, taux, montant HT)
///  – Total HT / TVA / TTC
///  – "TVA non applicable, art. 293 B du CGI"
///  – Conditions de règlement + pénalités de retard (art. L. 441-10 C. Com.)
Future<Uint8List> buildInvoicePdf(InvoiceData inv) async {
  final doc = pw.Document(
    title: 'Facture ${inv.invoiceNumber}',
    author: inv.sellerName,
  );

  // Fonts — Noto Sans supporte tous les caractères FR
  final regular = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final italic = await PdfGoogleFonts.notoSansItalic();

  // Formatters
  final euro = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
  final dateFmt = DateFormat('dd/MM/yyyy', 'fr_FR');

  // Styles helpers
  pw.TextStyle r(double sz, {PdfColor c = _gray900}) =>
      pw.TextStyle(font: regular, fontSize: sz, color: c);
  pw.TextStyle b(double sz, {PdfColor c = _gray900}) =>
      pw.TextStyle(font: bold, fontSize: sz, color: c);
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 48),
      footer: (ctx) => _footer(ctx, regular, _gray500),
      build: (ctx) => [
        // ── BANDE BLEUE TITRE ────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          color: _blue,
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('FACTURE', style: b(22, c: PdfColors.white)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('N° ${inv.invoiceNumber}',
                      style: b(12, c: PdfColors.white)),
                  pw.Text('Date : ${dateFmt.format(inv.issueDate)}',
                      style: r(10, c: PdfColors.white)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 20),

        // ── BLOC VENDEUR / ACHETEUR ───────────────────────────────────────
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Vendeur
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('ÉMETTEUR', style: b(8, c: _blue)),
                  pw.SizedBox(height: 4),
                  pw.Text(inv.sellerName, style: b(11)),
                  if (inv.sellerAddress != null)
                    pw.Text(inv.sellerAddress!, style: r(9, c: _gray700)),
                  if (inv.sellerSiret != null)
                    pw.Text('SIRET : ${inv.sellerSiret}',
                        style: r(9, c: _gray700)),
                ],
              ),
            ),
            pw.SizedBox(width: 24),
            // Acheteur
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(
                  color: _gray50,
                  border: pw.Border(left: pw.BorderSide(color: _blue, width: 3)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FACTURÉ À', style: b(8, c: _blue)),
                    pw.SizedBox(height: 4),
                    pw.Text(inv.buyerName, style: b(11)),
                    if (inv.buyerAddress != null)
                      pw.Text(inv.buyerAddress!, style: r(9, c: _gray700)),
                    if (inv.buyerSiret != null)
                      pw.Text('SIRET : ${inv.buyerSiret}',
                          style: r(9, c: _gray700)),
                    if (inv.buyerEmail != null)
                      pw.Text(inv.buyerEmail!, style: r(9, c: _gray700)),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),

        // ── TABLE DES PRESTATIONS ─────────────────────────────────────────
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(5),   // Description
            1: pw.FlexColumnWidth(1.5), // Qté (h)
            2: pw.FlexColumnWidth(2),   // Taux HT
            3: pw.FlexColumnWidth(2),   // Montant HT
          },
          children: [
            // En-tête
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _blue),
              children: [
                _cell('DESCRIPTION', bold: bold, hd: true),
                _cell('QTÉ (h)', bold: bold, hd: true, align: pw.Alignment.centerRight),
                _cell('TAUX HT', bold: bold, hd: true, align: pw.Alignment.centerRight),
                _cell('MONTANT HT', bold: bold, hd: true, align: pw.Alignment.centerRight),
              ],
            ),
            // Lignes
            ...inv.lines.asMap().entries.map((e) {
              final idx = e.key;
              final line = e.value;
              final bg = idx.isEven ? _gray50 : PdfColors.white;
              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  _cell(line.description, regular: regular),
                  _cell(_fmtHours(line.hours),
                      regular: regular, align: pw.Alignment.centerRight),
                  _cell(euro.format(line.hourlyRate),
                      regular: regular, align: pw.Alignment.centerRight),
                  _cell(euro.format(line.amount),
                      regular: regular,
                      align: pw.Alignment.centerRight,
                      isBold: true,
                      boldFont: bold),
                ],
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),

        // ── TOTAUX ────────────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Container(
              width: 220,
              child: pw.Column(
                children: [
                  _totalRow('Total HT', euro.format(inv.totalHT),
                      regular: regular, bold: bold),
                  pw.Divider(color: _gray200, height: 1),
                  _totalRow(
                    'TVA (0 %)',
                    euro.format(inv.tva),
                    regular: regular,
                    bold: bold,
                    note: 'Art. 293 B CGI',
                    italic: italic,
                  ),
                  pw.Container(
                    color: _blue,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total TTC', style: b(11, c: PdfColors.white)),
                        pw.Text(euro.format(inv.totalTTC),
                            style: b(13, c: PdfColors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),

        // ── MENTIONS LÉGALES ──────────────────────────────────────────────
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _gray100,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            border: pw.Border.all(color: _gray200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('MENTIONS LÉGALES', style: b(8, c: _blue)),
              pw.SizedBox(height: 6),
              // TVA
              pw.Text(
                'TVA non applicable — art. 293 B du CGI',
                style: b(9),
              ),
              pw.SizedBox(height: 4),
              // Conditions de règlement
              pw.Text(
                'Conditions de règlement : paiement sous ${inv.paymentDays} jours à réception de facture.'
                ' Pas d\'escompte pour règlement anticipé.',
                style: r(8, c: _gray700),
              ),
              pw.SizedBox(height: 4),
              // Pénalités de retard — obligatoire art. L. 441-10 C. Com.
              pw.Text(
                'En cas de retard de paiement, des pénalités de retard calculées au taux de 3 fois le taux '
                'd\'intérêt légal en vigueur seront exigibles dès le lendemain de la date d\'échéance, '
                'sans qu\'un rappel soit nécessaire. Une indemnité forfaitaire pour frais de recouvrement '
                'de 40 € sera également due (art. L. 441-10 et D. 441-5 du Code de Commerce).',
                style: r(8, c: _gray700),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  return doc.save();
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

pw.Widget _cell(
  String text, {
  pw.Font? regular,
  pw.Font? bold,
  pw.Alignment align = pw.Alignment.centerLeft,
  bool hd = false,
  bool isBold = false,
  pw.Font? boldFont,
}) {
  final style = hd
      ? pw.TextStyle(
          font: bold,
          fontSize: 9,
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold)
      : (isBold
          ? pw.TextStyle(font: boldFont ?? bold, fontSize: 9, color: _gray900)
          : pw.TextStyle(font: regular, fontSize: 9, color: _gray700));
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    alignment: align,
    child: pw.Text(text, style: style),
  );
}

pw.Widget _totalRow(
  String label,
  String value, {
  required pw.Font regular,
  required pw.Font bold,
  String? note,
  pw.Font? italic,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label,
                style: pw.TextStyle(font: regular, fontSize: 9, color: _gray700)),
            if (note != null)
              pw.Text(note,
                  style: pw.TextStyle(font: italic, fontSize: 7, color: _gray500)),
          ],
        ),
        pw.Text(value,
            style: pw.TextStyle(font: bold, fontSize: 9, color: _gray900)),
      ],
    ),
  );
}

pw.Widget _footer(
    pw.Context ctx, pw.Font font, PdfColor color) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _gray200))),
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Document généré par TimeToInvoice',
            style: pw.TextStyle(font: font, fontSize: 7, color: color)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 7, color: color)),
      ],
    ),
  );
}

String _fmtHours(double h) {
  final total = (h * 60).round();
  final hh = total ~/ 60;
  final mm = total % 60;
  if (hh == 0) return '${mm}min';
  if (mm == 0) return '${hh}h';
  return '${hh}h${mm.toString().padLeft(2, '0')}';
}
