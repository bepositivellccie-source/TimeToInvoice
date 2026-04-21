class Invoice {
  final String id;
  final String userId;
  final String clientId;
  final String? projectId;
  final String invoiceNumber;
  final double totalAmount;
  final String status; // draft, sent, paid, cancelled
  final DateTime createdAt;
  final String? pdfPath;
  final DateTime? issuedAt;
  final DateTime? dueAt;
  final DateTime? sentAt;
  final String? sentVia; // 'email' | 'WhatsApp' | 'autre'
  final String? sentTo;

  // Joined from clients table OR stored denormalized
  final String? clientName;
  final String? clientEmail;

  const Invoice({
    required this.id,
    required this.userId,
    required this.clientId,
    this.projectId,
    required this.invoiceNumber,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.pdfPath,
    this.issuedAt,
    this.dueAt,
    this.sentAt,
    this.sentVia,
    this.sentTo,
    this.clientName,
    this.clientEmail,
  });

  /// Facture en retard : ni payée ni annulée et échéance dépassée
  bool get isOverdue {
    if (status == 'paid' || status == 'cancelled') return false;
    if (dueAt != null) return DateTime.now().isAfter(dueAt!);
    return DateTime.now().difference(createdAt).inDays > 30;
  }

  String get displayStatus {
    if (isOverdue) return 'En retard';
    return switch (status) {
      'draft' => 'À envoyer',
      'sent' => 'Envoyée',
      'paid' => 'Payée',
      'cancelled' => 'Annulée',
      _ => status,
    };
  }

  /// Facture en attente de paiement (draft ou sent, non expirée)
  bool get isPending => status == 'draft' || status == 'sent';

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // client name: stored denormalized OR from join
    final clientData = json['clients'];
    final joinedName =
        clientData is Map<String, dynamic> ? clientData['name'] as String? : null;
    final joinedEmail =
        clientData is Map<String, dynamic> ? clientData['email'] as String? : null;

    return Invoice(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      clientId: json['client_id'] as String,
      projectId: json['project_id'] as String?,
      invoiceNumber: json['invoice_number'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String? ?? 'draft',
      createdAt: DateTime.parse(json['created_at'] as String),
      pdfPath: json['pdf_path'] as String?,
      issuedAt: json['issued_at'] != null
          ? DateTime.parse(json['issued_at'] as String)
          : null,
      dueAt: json['due_at'] != null
          ? DateTime.parse(json['due_at'] as String)
          : null,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      sentVia: json['sent_via'] as String?,
      sentTo: json['sent_to'] as String?,
      clientName: json['client_name'] as String? ?? joinedName,
      clientEmail: joinedEmail,
    );
  }
}
