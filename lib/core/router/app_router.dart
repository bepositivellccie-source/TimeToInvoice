import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supabase_provider.dart';
import '../providers/onboarding_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/timer/timer_screen.dart';
import '../../features/clients/clients_screen.dart';
import '../../features/clients/client_detail_screen.dart';
import '../../features/clients/client_profile_screen.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/invoices/invoice_screen.dart';
import '../../features/invoices/invoices_history_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/projects/projects_screen.dart';
import '../../features/projects/project_select_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/invoices/pdf_gallery_screen.dart';
import '../../features/settings/settings_screen.dart';

/// Listenable that notifies GoRouter when auth or onboarding state changes,
/// WITHOUT recreating the GoRouter instance (avoids GlobalKey collisions
/// in StatefulShellRoute).
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (prev, next) => notifyListeners());
    ref.listen(onboardingProvider, (prev, next) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // ── Auth state (read, not watch) ──
      final authAsync = ref.read(authStateProvider);
      final isLoading = authAsync.isLoading;

      // Tant que l'état auth charge → splash
      if (isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      final isLoggedIn = authAsync.valueOrNull?.session != null;

      // Pas connecté → login
      if (!isLoggedIn) {
        return loc == '/login' ? null : '/login';
      }

      // Connecté — vérifier onboarding
      final onboardingAsync = ref.read(onboardingProvider);

      if (loc == '/login' || loc == '/splash') {
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
      // ── Splash (chargement initial) ──────────────────────────────────────
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),

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

      // ── Sélecteur de projet dédié (hors shell) ────────────────────────────
      GoRoute(
        path: '/projects/select',
        builder: (context, state) => const ProjectSelectScreen(),
      ),

      // ── Profil utilisateur (hors shell) ──────────────────────────────────
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // ── Paramètres (hors shell) ─────────────────────────────────────────
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
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
          // Branch 0 — Projets (tous clients)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/projects',
                builder: (context, state) => const ProjectsScreen(),
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
                        path: 'profile',
                        builder: (context, state) => ClientProfileScreen(
                          clientId: state.pathParameters['clientId']!,
                        ),
                      ),
                      GoRoute(
                        path: 'projects/:projectId/sessions',
                        builder: (context, state) => SessionsScreen(
                          projectId: state.pathParameters['projectId']!,
                          highlightSessionId: state.extra as String?,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 2 — Timer (Chrono, FAB central)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timer',
                builder: (context, state) => const TimerScreen(),
              ),
            ],
          ),

          // Branch 3 — Factures (historique)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/invoices',
                builder: (context, state) =>
                    const InvoicesHistoryScreen(),
              ),
            ],
          ),

          // Branch 4 — PDFs (galerie)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pdfs',
                builder: (context, state) =>
                    const PdfGalleryScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
