import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
import 'project_billing_status_provider.dart';
import 'supabase_provider.dart';

final invoicesProvider =
    AsyncNotifierProvider<InvoicesNotifier, List<Invoice>>(
        InvoicesNotifier.new);

class InvoicesNotifier extends AsyncNotifier<List<Invoice>> {
  @override
  Future<List<Invoice>> build() async {
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase
        .from('invoices')
        .select('*, clients(name, email)')
        .order('created_at', ascending: false);
    return data.map((j) => Invoice.fromJson(j)).toList();
  }

  Future<void> updateStatus(String id, String newStatus) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase
        .from('invoices')
        .update({'status': newStatus})
        .eq('id', id);
    ref.invalidateSelf();
    // Vue Postgres `project_billing_status` à recalculer côté serveur.
    ref.invalidate(projectBillingStatusProvider);
  }

  Future<void> markAsSentByNumber(
    String invoiceNumber, {
    required String via,
    String? to,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    final payload = <String, dynamic>{
      'sent_at': DateTime.now().toUtc().toIso8601String(),
      'sent_via': via,
      'status': 'sent',
    };
    if (to != null && to.isNotEmpty) {
      payload['sent_to'] = to;
    }
    await supabase
        .from('invoices')
        .update(payload)
        .eq('invoice_number', invoiceNumber);
    ref.invalidateSelf();
    ref.invalidate(projectBillingStatusProvider);
  }

  Future<void> delete(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('invoices').delete().eq('id', id);
    ref.invalidateSelf();
    // Suppression facture → impacte aussi unbilled_sessions (via CASCADE
    // sur invoice_sessions) et tous les compteurs de la vue.
    ref.invalidate(projectBillingStatusProvider);
  }
}

/// Factures d'un client donné — dérivé du provider global pour éviter
/// un second round-trip Supabase.
final invoicesByClientProvider =
    Provider.family<AsyncValue<List<Invoice>>, String>((ref, clientId) {
  return ref.watch(invoicesProvider).whenData(
        (list) => list.where((inv) => inv.clientId == clientId).toList(),
      );
});
