/// Modèle local utilisé pour la génération PDF — non persisté tel quel.
/// La ligne en DB (table invoices) est insérée séparément après génération.
class InvoiceLine {
  final String description; // "Prestation du 01/01/2026 — 2h30"
  final double hours;       // 2.5
  final double hourlyRate;  // 80.00
  final String currency;

  const InvoiceLine({
    required this.description,
    required this.hours,
    required this.hourlyRate,
    required this.currency,
  });

  double get amount => hours * hourlyRate;
}

class InvoiceData {
  final String invoiceNumber;    // "2026-001"
  final DateTime issueDate;

  // Vendeur (auto-entrepreneur)
  final String sellerName;
  final String? sellerAddress;
  final String? sellerSiret;
  final String? sellerVatNumber;

  // Acheteur
  final String buyerName;
  final String? buyerAddress;
  final String? buyerSiret;
  final String? buyerEmail;

  // Lignes de prestations
  final List<InvoiceLine> lines;

  // Paramètres de règlement
  final int paymentDays;       // 30 par défaut
  final String currency;       // "EUR"

  const InvoiceData({
    required this.invoiceNumber,
    required this.issueDate,
    required this.sellerName,
    this.sellerAddress,
    this.sellerSiret,
    this.sellerVatNumber,
    required this.buyerName,
    this.buyerAddress,
    this.buyerSiret,
    this.buyerEmail,
    required this.lines,
    this.paymentDays = 30,
    this.currency = 'EUR',
  });

  double get totalHT => lines.fold(0.0, (s, l) => s + l.amount);
  // Auto-entrepreneur : TVA non applicable
  double get tva => 0.0;
  double get totalTTC => totalHT;
}
