/// Statut de facturation d'un projet — lecture depuis la vue Postgres
/// `project_billing_status`. Source de vérité côté serveur : NE JAMAIS
/// recalculer ces valeurs côté client.
class ProjectBillingStatus {
  final String projectId;
  final String projectName;
  final String? projectStatus; // en_cours / en_attente / termine
  final String clientId;
  final double hourlyRate;
  final String? clientName;
  final String? clientCompany;
  final int totalSeconds;
  final int totalSessions;
  final int unbilledSessions;
  final int unbilledSeconds;
  final int invoiceCount;
  final int draftCount;
  final int sentCount;
  final int paidCount;
  final int overdueCount;
  final double amountPaid;
  final double amountPending;

  /// unbilled | draft | pending | overdue | partially_billed | fully_billed
  final String billingStatus;

  const ProjectBillingStatus({
    required this.projectId,
    required this.projectName,
    required this.projectStatus,
    required this.clientId,
    required this.hourlyRate,
    required this.clientName,
    required this.clientCompany,
    required this.totalSeconds,
    required this.totalSessions,
    required this.unbilledSessions,
    required this.unbilledSeconds,
    required this.invoiceCount,
    required this.draftCount,
    required this.sentCount,
    required this.paidCount,
    required this.overdueCount,
    required this.amountPaid,
    required this.amountPending,
    required this.billingStatus,
  });

  factory ProjectBillingStatus.fromJson(Map<String, dynamic> json) {
    return ProjectBillingStatus(
      projectId: json['project_id'] as String,
      projectName: json['project_name'] as String? ?? '',
      projectStatus: json['project_status'] as String?,
      clientId: json['client_id'] as String,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      clientName: json['client_name'] as String?,
      clientCompany: json['client_company'] as String?,
      totalSeconds: (json['total_seconds'] as num?)?.toInt() ?? 0,
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      unbilledSessions: (json['unbilled_sessions'] as num?)?.toInt() ?? 0,
      unbilledSeconds: (json['unbilled_seconds'] as num?)?.toInt() ?? 0,
      invoiceCount: (json['invoice_count'] as num?)?.toInt() ?? 0,
      draftCount: (json['draft_count'] as num?)?.toInt() ?? 0,
      sentCount: (json['sent_count'] as num?)?.toInt() ?? 0,
      paidCount: (json['paid_count'] as num?)?.toInt() ?? 0,
      overdueCount: (json['overdue_count'] as num?)?.toInt() ?? 0,
      amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
      amountPending: (json['amount_pending'] as num?)?.toDouble() ?? 0.0,
      billingStatus: json['billing_status'] as String? ?? 'unbilled',
    );
  }
}
