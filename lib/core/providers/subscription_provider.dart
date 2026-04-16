import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'supabase_provider.dart';

// ── Entitlements & offering IDs ────────────────────────────────────────────
const _entitlementId = 'pro';
const _revenueCatApiKey = 'YOUR_REVENUECAT_API_KEY'; // TODO: Replace with real key

// ── Free tier limits ───────────────────────────────────────────────────────
const kFreeInvoicesPerMonth = 5;

// ── Subscription state ─────────────────────────────────────────────────────

@immutable
class SubscriptionState {
  final bool isPro;
  final Offerings? offerings;
  final bool isLoading;

  const SubscriptionState({
    this.isPro = false,
    this.offerings,
    this.isLoading = true,
  });

  SubscriptionState copyWith({
    bool? isPro,
    Offerings? offerings,
    bool? isLoading,
  }) =>
      SubscriptionState(
        isPro: isPro ?? this.isPro,
        offerings: offerings ?? this.offerings,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────

class SubscriptionNotifier extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() {
    _init();
    return const SubscriptionState();
  }

  Future<void> _init() async {
    try {
      await Purchases.configure(
        PurchasesConfiguration(_revenueCatApiKey),
      );

      final customerInfo = await Purchases.getCustomerInfo();
      final isPro =
          customerInfo.entitlements.active.containsKey(_entitlementId);

      final offerings = await Purchases.getOfferings();

      state = state.copyWith(
        isPro: isPro,
        offerings: offerings,
        isLoading: false,
      );

      // Écouter les changements en temps réel
      Purchases.addCustomerInfoUpdateListener((info) {
        state = state.copyWith(
          isPro: info.entitlements.active.containsKey(_entitlementId),
        );
      });
    } catch (e) {
      // RevenueCat non configuré → mode dev, débloquer tout
      debugPrint('RevenueCat init error: $e');
      state = state.copyWith(isPro: true, isLoading: false);
    }
  }

  /// Identifie l'utilisateur après login Supabase.
  Future<void> login(String userId) async {
    try {
      await Purchases.logIn(userId);
      final info = await Purchases.getCustomerInfo();
      state = state.copyWith(
        isPro: info.entitlements.active.containsKey(_entitlementId),
      );
    } catch (e) {
      debugPrint('RevenueCat login error: $e');
    }
  }

  /// Achète un package (mensuel ou annuel).
  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final isPro = result.customerInfo.entitlements.active
          .containsKey(_entitlementId);
      state = state.copyWith(isPro: isPro);
      return isPro;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  /// Restaure les achats existants.
  Future<void> restore() async {
    try {
      final info = await Purchases.restorePurchases();
      state = state.copyWith(
        isPro: info.entitlements.active.containsKey(_entitlementId),
      );
    } catch (e) {
      debugPrint('Restore error: $e');
    }
  }
}

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, SubscriptionState>(
        SubscriptionNotifier.new);

// ── Helper : nombre de factures du mois ────────────────────────────────────

final monthlyInvoiceCountProvider = FutureProvider<int>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final now = DateTime.now();
  final firstOfMonth =
      DateTime(now.year, now.month, 1).toUtc().toIso8601String();
  final firstOfNext =
      DateTime(now.year, now.month + 1, 1).toUtc().toIso8601String();

  final data = await supabase
      .from('invoices')
      .select('id')
      .gte('created_at', firstOfMonth)
      .lt('created_at', firstOfNext);

  return (data as List).length;
});

// ── Helper : date de création du compte ───────────────────────────────────

final accountCreatedAtProvider = FutureProvider<DateTime?>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return null;

  final data = await supabase
      .from('profiles')
      .select('created_at')
      .eq('user_id', userId)
      .maybeSingle();

  if (data == null || data['created_at'] == null) return null;
  return DateTime.parse(data['created_at'] as String);
});
