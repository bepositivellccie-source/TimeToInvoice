import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import 'supabase_provider.dart';

class ProfileNotifier extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    final supabase = ref.watch(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await supabase
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> save(Profile profile) async {
    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('profiles').upsert(
      {
        'user_id': userId,
        'display_name': profile.displayName,
        'street': profile.street,
        'zip_code': profile.zipCode,
        'city': profile.city,
        'siret': profile.siret,
        'tva_number': profile.tvaNumber,
        'email': profile.email,
        'phone': profile.phone,
        'iban': profile.iban,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id',
    );

    state = AsyncData(profile);
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);
