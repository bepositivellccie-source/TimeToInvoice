import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'client_display_mode_provider.dart';

/// Mode test : factures marquées `is_test=true` (watermark + exclues quota).
/// Wired up visuellement au chantier 8 ; ce provider sert de source de vérité
/// dès le chantier 4 (toggle dans Menu > Outils).
class TestModeNotifier extends Notifier<bool> {
  static const _key = 'test_mode_enabled';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
  }

  Future<void> toggle() => setEnabled(!state);
}

final testModeProvider =
    NotifierProvider<TestModeNotifier, bool>(TestModeNotifier.new);
