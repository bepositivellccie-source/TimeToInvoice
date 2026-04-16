import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/invoice.dart';
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
  }

  Future<void> delete(String id) async {
    final supabase = ref.read(supabaseClientProvider);
    await supabase.from('invoices').delete().eq('id', id);
    ref.invalidateSelf();
  }
}
