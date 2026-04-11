import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client.dart';
import 'supabase_provider.dart';

class ClientsNotifier extends AsyncNotifier<List<Client>> {
  Future<List<Client>> _fetch() async {
    final supabase = ref.read(supabaseClientProvider);
    final data = await supabase
        .from('clients')
        .select()
        .order('name');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  @override
  Future<List<Client>> build() => _fetch();

  Future<void> create({
    required String name,
    String? siret,
    String? address,
    String? email,
  }) async {
    state = const AsyncLoading();
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser!.id;
    state = await AsyncValue.guard(() async {
      await supabase.from('clients').insert({
        'user_id': userId,
        'name': name,
        if (siret != null && siret.isNotEmpty) 'siret': siret,
        if (address != null && address.isNotEmpty) 'address': address,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      return _fetch();
    });
  }

  Future<void> edit({
    required String id,
    required String name,
    String? siret,
    String? address,
    String? email,
  }) async {
    state = const AsyncLoading();
    final supabase = ref.read(supabaseClientProvider);
    state = await AsyncValue.guard(() async {
      await supabase.from('clients').update({
        'name': name,
        'siret': (siret?.isNotEmpty ?? false) ? siret : null,
        'address': (address?.isNotEmpty ?? false) ? address : null,
        'email': (email?.isNotEmpty ?? false) ? email : null,
      }).eq('id', id);
      return _fetch();
    });
  }

  Future<void> delete(String id) async {
    state = const AsyncLoading();
    final supabase = ref.read(supabaseClientProvider);
    state = await AsyncValue.guard(() async {
      await supabase.from('clients').delete().eq('id', id);
      return _fetch();
    });
  }
}

final clientsProvider =
    AsyncNotifierProvider<ClientsNotifier, List<Client>>(ClientsNotifier.new);
