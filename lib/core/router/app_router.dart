import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supabase_provider.dart';
import '../providers/onboarding_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/timer/timer_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/clients/client_detail_screen.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/invoices/invoice_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Watchers réactifs — tout changement reconstruit le router
  final authState = ref.watch(authStateProvider);
  final onboardingAsync = ref.watch(onboardingProvider);

  return GoRouter(
    initialLocation: '/timer',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.session != null;
      final loc = state.matchedLocation;

      // ── Non authentifié → login ──────────────────────────────────────────
      if (!isLoggedIn) {
        return loc == '/login' ? null : '/login';
      }

      // ── Authentifié sur /login → rediriger ───────────────────────────────
      if (loc == '/login') {
        // Attend que onboarding soit résolu avant de choisir la destination
        final done = onboardingAsync.valueOrNull;
        if (done == null) return null; // encore en chargement
        return done ? '/timer' : '/onboarding';
      }

      // ── Vérification onboarding (après connexion) ────────────────────────
      final done = onboardingAsync.valueOrNull;
      if (done == null) return null; // encore en chargement — ne pas bloquer

      if (!done && loc != '/onboarding') return '/onboarding';
      if (done && loc == '/onboarding') return '/timer';

      return null;
    },
    routes: [
      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // ── Onboarding (hors shell) ───────────────────────────────────────────
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // ── Facture (hors shell — écran focalisé) ─────────────────────────────
      GoRoute(
        path: '/invoices/new/:projectId',
        builder: (context, state) => InvoiceScreen(
          projectId: state.pathParameters['projectId']!,
        ),
      ),

      // ── Shell avec bottom nav ─────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Timer
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timer',
                builder: (context, state) => const TimerScreen(),
              ),
            ],
          ),

          // Branch 1 — Clients → Client detail → Sessions
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/clients',
                builder: (context, state) => const ClientsScreen(),
                routes: [
                  GoRoute(
                    path: ':clientId',
                    builder: (context, state) => ClientDetailScreen(
                      clientId: state.pathParameters['clientId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'projects/:projectId/sessions',
                        builder: (context, state) => SessionsScreen(
                          projectId: state.pathParameters['projectId']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
