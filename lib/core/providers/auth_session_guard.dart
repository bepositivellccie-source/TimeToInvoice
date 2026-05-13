import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/timer/timer_notifier.dart';
import 'clients_provider.dart';
import 'invoices_provider.dart';
import 'profile_provider.dart';
import 'project_billing_status_provider.dart';
import 'projects_provider.dart';
import 'session_bar_provider.dart';
import 'sessions_provider.dart';
import 'subscription_provider.dart';
import 'supabase_provider.dart';

/// Listener auth qui purge les caches Riverpod liés à l'utilisateur
/// quand l'`user.id` change (sign-in, sign-out, switch de compte Google).
///
/// Sans ça, la liste de clients, projets et sessions du compte précédent
/// reste affichée à l'écran d'accueil après reconnexion avec un autre
/// compte. C'est une fuite de données entre comptes.
///
/// Doit être maintenu vivant via `ref.watch(authSessionGuardProvider)`
/// au plus haut niveau (ex : `ChronoFactureApp`).
final authSessionGuardProvider = Provider<void>((ref) {
  String? lastUserId =
      ref.read(supabaseClientProvider).auth.currentUser?.id;

  ref.listen(authStateProvider, (prev, next) {
    final newUserId = next.valueOrNull?.session?.user.id;
    if (newUserId == lastUserId) return;
    lastUserId = newUserId;

    // ── Listes principales ────────────────────────────────────────────
    ref.invalidate(clientsProvider);
    ref.invalidate(projectsProvider);
    ref.invalidate(invoicesProvider);
    ref.invalidate(profileProvider);

    // ── Vues dérivées ────────────────────────────────────────────────
    ref.invalidate(projectsByClientProvider);
    ref.invalidate(timerProjectsProvider);
    ref.invalidate(projectBillingStatusProvider);

    // ── Sessions (FutureProviders + families) ────────────────────────
    ref.invalidate(recentSessionsProvider);
    ref.invalidate(weeklyStatsProvider);
    ref.invalidate(projectsTotalSecondsProvider);
    ref.invalidate(sessionsByProjectProvider);
    ref.invalidate(unbilledSessionsByProjectProvider);

    // ── Quotas et méta ───────────────────────────────────────────────
    ref.invalidate(monthlyInvoiceCountProvider);
    ref.invalidate(accountCreatedAtProvider);

    // ── Mini-player session-bar : reset state ────────────────────────
    ref.read(sessionBarProvider.notifier).state = null;

    // ── Timer : reset complet de l'état (chrono, projet sélectionné,
    //    session active) pour éviter qu'un projet/timer du compte A
    //    leak sur l'écran chrono du compte B.
    ref.invalidate(timerProvider);
  });
});
