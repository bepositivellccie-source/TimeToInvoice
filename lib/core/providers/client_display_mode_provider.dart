import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── SharedPreferences singleton — overridé dans main.dart ────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('Override sharedPreferencesProvider in main'),
);

// ─── Mode d'affichage des clients ─────────────────────────────────────────────
//
//  'company'          → entreprise en priorité, sinon prénom + nom
//  'firstname_lastname' → prénom + nom, sinon entreprise
//  'lastname'         → nom seul, sinon entreprise

class ClientDisplayModeNotifier extends Notifier<String> {
  static const _key = 'client_display_mode';
  static const defaultMode = 'company';

  @override
  String build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_key) ?? defaultMode;
  }

  Future<void> setMode(String mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_key, mode);
  }

  /// Bascule entre 'company' et 'firstname_lastname'
  Future<void> toggle() async {
    await setMode(
      state == 'company' ? 'firstname_lastname' : 'company',
    );
  }
}

final clientDisplayModeProvider =
    NotifierProvider<ClientDisplayModeNotifier, String>(
  ClientDisplayModeNotifier.new,
);
