import 'package:supabase_flutter/supabase_flutter.dart';

/// Génère le prochain numéro de facture séquentiel pour l'utilisateur courant.
/// Format : YYYY-NNN (ex: 2026-001, 2026-002…)
/// Garantit l'unicité par user_id via la contrainte UNIQUE(user_id, invoice_number) en DB.
Future<String> nextInvoiceNumber(SupabaseClient supabase) async {
  final year = DateTime.now().year;
  final userId = supabase.auth.currentUser!.id;

  final data = await supabase
      .from('invoices')
      .select('invoice_number')
      .eq('user_id', userId)
      .like('invoice_number', '$year-%')
      .order('invoice_number', ascending: false)
      .limit(1);

  if ((data as List).isEmpty) return '$year-001';

  final last = data.first['invoice_number'] as String;
  final parts = last.split('-');
  if (parts.length == 2) {
    final seq = int.tryParse(parts[1]) ?? 0;
    return '$year-${(seq + 1).toString().padLeft(3, '0')}';
  }

  return '$year-001';
}
