import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supabase_provider.dart';
import '../providers/onboarding_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/timer/timer_screen.dart';
import '../../features/menu/menu_screen.dart';
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
        return done ? '/home' : '/onboarding';
      }

      final done = onboardingAsync.valueOrNull;
      if (done == null) return null;

      if (!done && loc != '/onboarding') return '/onboarding';
      if (done && loc == '/onboarding') return '/home';

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

      // ── Projets (hors shell — accès depuis Menu) ─────────────────────────
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectsScreen(),
      ),

      // ── Clients + sous-routes (hors shell — accès depuis Menu) ──────────
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

      // ── PDFs (hors shell — accès depuis Menu) ───────────────────────────
      GoRoute(
        path: '/pdfs',
        builder: (context, state) => const PdfGalleryScreen(),
      ),

      // ── Facture (hors shell — écran focalisé) ─────────────────────────────
      GoRoute(
        path: '/invoices/new/:projectId',
        builder: (context, state) => InvoiceScreen(
          projectId: state.pathParameters['projectId']!,
        ),
      ),

      // ── Shell avec bottom nav 4 onglets ──────────────────────────────────
      // Branches : 0=/home, 1=/timer, 2=/invoices, 3=/menu
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Branch 0 — Accueil (KPI semaine + À faire)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Branch 1 — Chrono (timer)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timer',
                builder: (context, state) => const TimerScreen(),
              ),
            ],
          ),

          // Branch 2 — Factures (historique)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/invoices',
                builder: (context, state) => const InvoicesHistoryScreen(),
              ),
            ],
          ),

          // Branch 3 — Menu (Clients/Projets/PDFs/Paramètres)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/menu',
                builder: (context, state) => const MenuScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
