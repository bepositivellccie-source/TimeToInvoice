import 'package:flutter/material.dart';

/// Badge affichant le statut de facturation d'un projet.
///
/// Valeurs attendues (vue Postgres `project_billing_status.billing_status`) :
/// `unbilled`, `draft`, `pending`, `overdue`, `partially_billed`, `fully_billed`.
///
/// Source de vérité côté serveur : ne jamais recalculer ce statut côté client.
class ProjectBillingBadge extends StatelessWidget {
  final String status;

  const ProjectBillingBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    // unbilled → aucun badge (pas de bruit visuel sur projet neuf).
    if (status == 'unbilled') return const SizedBox.shrink();

    final config = switch (status) {
      'overdue' => (label: 'Impayé', color: const Color(0xFFEF4444)),
      'pending' => (label: 'En attente', color: const Color(0xFFF97316)),
      'draft' => (label: 'À envoyer', color: const Color(0xFF6B7280)),
      'partially_billed' =>
        (label: 'Partiellement', color: const Color(0xFFF59E0B)),
      'fully_billed' => (label: 'Facturé', color: const Color(0xFF22C55E)),
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
