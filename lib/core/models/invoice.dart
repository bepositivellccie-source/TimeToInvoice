class Invoice {
  final String id;
  final String userId;
  final String clientId;
  final String invoiceNumber;
  final double totalAmount;
  final String status; // draft, sent, paid, cancelled
  final DateTime createdAt;

  // Joined from clients table
  final String? clientName;

  const Invoice({
    required this.id,
    required this.userId,
    required this.clientId,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.clientName,
  });

  /// Facture en retard : ni payée ni annulée et > 30 jours
  bool get isOverdue =>
      status != 'paid' &&
      status != 'cancelled' &&
      DateTime.now().difference(createdAt).inDays > 30;

  String get displayStatus {
    if (isOverdue) return 'En retard';
    return switch (status) {
      'draft' => 'Brouillon',
      'sent' => 'Envoyée',
      'paid' => 'Payée',
      'cancelled' => 'Annulée',
      _ => status,
    };
  }

  /// Facture en attente de paiement (draft ou sent, non expirée)
  bool get isPending => status == 'draft' || status == 'sent';

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // client name from join: clients(name)
    final clientData = json['clients'];
    final clientName =
        clientData is Map<String, dynamic> ? clientData['name'] as String? : null;

    return Invoice(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      clientId: json['client_id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'draft',
      createdAt: DateTime.parse(json['created_at'] as String),
      clientName: clientName,
    );
  }
}
