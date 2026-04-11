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
import '../../features/profile/profile_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_select_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final onboardingAsync = ref.watch(onboardingProvider);

  return GoRouter(
    initialLocation: '/timer',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.session != null;
      final loc = state.matchedLocation;

      if (!isLoggedIn) {
        return loc == '/login' ? null : '/login';
      }

      if (loc == '/login') {
        final done = onboardingAsync.valueOrNull;
        if (done == null) return null;
        return done ? '/timer' : '/onboarding';
      }

      final done = onboardingAsync.valueOrNull;
      if (done == null) return null;

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

      // ── Profil vendeur (hors shell) ───────────────────────────────────────
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // ── Sélecteur de projet dédié (hors shell) ────────────────────────────
      GoRoute(
        path: '/projects/select',
        builder: (context, state) => const ProjectSelectScreen(),
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

          // Branch 1 — Projets (tous clients)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                builder: (context, state) => const ProjectsScreen(),
              ),
            ],
          ),

          // Branch 2 — Clients → Client detail → Sessions
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
