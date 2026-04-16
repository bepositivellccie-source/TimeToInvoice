import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client.dart';
import 'supabase_provider.dart';

class ClientsNotifier extends AsyncNotifier<List<Client>> {
  Future<List<Client>> _fetch() async {
    final supabase = ref.read(supabaseClientProvider);
    final data =
        await supabase.from('client_status').select().order('name');
    return (data as List).map((e) => Client.fromJson(e)).toList();
  }

  @override
  Future<List<Client>> build() => _fetch();

  Future<void> create({
    required String name,
    String? firstName,
    String? company,
    String? siret,
    String? street,
    String? zipCode,
    String? city,
    String? phone,
    String? whatsapp,
    String? email,
  }) async {
    state = const AsyncLoading();
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser!.id;
    state = await AsyncValue.guard(() async {
      await supabase.from('clients').insert({
        'user_id': userId,
        'name': name,
        if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
        if (company != null && company.isNotEmpty) 'company': company,
        if (siret != null && siret.isNotEmpty) 'siret': siret,
        if (street != null && street.isNotEmpty) 'street': street,
        if (zipCode != null && zipCode.isNotEmpty) 'zip_code': zipCode,
        if (city != null && city.isNotEmpty) 'city': city,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (whatsapp != null && whatsapp.isNotEmpty) 'whatsapp': whatsapp,
        if (email != null && email.isNotEmpty) 'email': email,
      });
      return _fetch();
    });
  }

  Future<void> edit({
    required String id,
    required String name,
    String? firstName,
    String? company,
    String? siret,
    String? street,
    String? zipCode,
    String? city,
    String? phone,
    String? whatsapp,
    String? email,
  }) async {
    state = const AsyncLoading();
    final supabase = ref.read(supabaseClientProvider);
    state = await AsyncValue.guard(() async {
      await supabase.from('clients').update({
        'name': name,
        'first_name': (firstName?.isNotEmpty ?? false) ? firstName : null,
        'company': (company?.isNotEmpty ?? false) ? company : null,
        'siret': (siret?.isNotEmpty ?? false) ? siret : null,
        'street': (street?.isNotEmpty ?? false) ? street : null,
        'zip_code': (zipCode?.isNotEmpty ?? false) ? zipCode : null,
        'city': (city?.isNotEmpty ?? false) ? city : null,
        'phone': (phone?.isNotEmpty ?? false) ? phone : null,
        'whatsapp': (whatsapp?.isNotEmpty ?? false) ? whatsapp : null,
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
