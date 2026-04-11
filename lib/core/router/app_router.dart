import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/supabase_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/timer/timer_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/timer',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.session != null;
      final isOnLogin = state.matchedLocation == '/login';

      if (!isLoggedIn && !isOnLogin) return '/login';
      if (isLoggedIn && isOnLogin) return '/timer';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/timer',
        builder: (context, state) => const TimerScreen(),
      ),
    ],
  );
});
