import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/alerts/presentation/widgets/alerts_screen.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/widgets/login_screen.dart';
import '../../features/dashboard/presentation/widgets/dashboard_screen.dart';
import '../../features/map/presentation/widgets/live_map_screen.dart';
import '../../features/shell/presentation/widgets/access_denied_screen.dart';
import '../../features/shell/presentation/widgets/shell_scaffold.dart';
import '../../features/trips/presentation/widgets/trips_screen.dart';

/// Centralized routing configuration with RBAC route-level guards.
///
/// Adheres strictly to M2 requirement:
/// - "Navigation, routes and action buttons come from the permissions in /api/me, never from role names."
/// - "A URL the user may not see shows a proper 'no access' state, not a crash or an empty page."
class AppRouter {
  final AuthCubit authCubit;

  AppRouter({required this.authCubit});

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authCubit.stream),
    redirect: (context, state) {
      final authState = authCubit.state;
      final isLoggingIn = state.matchedLocation == '/login';

      // 1. Unauthenticated Guard
      if (authState is! Authenticated) {
        return isLoggingIn ? null : '/login';
      }

      final user = authState.user;

      // 2. Authenticated Landing Redirect: Redirect / and /login to first permitted module
      if (isLoggingIn || state.matchedLocation == '/') {
        if (user.hasAnyPermission(['kpi:read', 'city:read'])) return '/dashboard';
        if (user.hasPermission('trip:read')) return '/trips';
        if (user.hasPermission('driver:track')) return '/map';
        if (user.hasPermission('alert:read')) return '/alerts';
        return '/access-denied';
      }

      // 3. Permission-driven Route Guards (never from role names!)
      final location = state.matchedLocation;

      if (location.startsWith('/dashboard') &&
          !user.hasAnyPermission(['kpi:read', 'city:read'])) {
        return '/access-denied?required=kpi:read&path=$location';
      }

      if (location.startsWith('/trips') && !user.hasPermission('trip:read')) {
        return '/access-denied?required=trip:read&path=$location';
      }

      if (location.startsWith('/map') && !user.hasPermission('driver:track')) {
        return '/access-denied?required=driver:track&path=$location';
      }

      if (location.startsWith('/alerts') && !user.hasPermission('alert:read')) {
        return '/access-denied?required=alert:read&path=$location';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/access-denied',
        builder: (context, state) {
          final requiredPermission = state.uri.queryParameters['required'];
          final attemptedPath = state.uri.queryParameters['path'];
          return AccessDeniedScreen(
            requiredPermission: requiredPermission,
            attemptedPath: attemptedPath,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ShellScaffold(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/trips',
            builder: (context, state) => const TripsScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const LiveMapScreen(),
          ),
          GoRoute(
            path: '/alerts',
            builder: (context, state) => const AlertsScreen(),
          ),
        ],
      ),
    ],
  );
}

/// Helper converting Cubit/Bloc Stream into a Listenable for GoRouter.
class GoRouterRefreshStream extends ChangeNotifier {
  late final dynamic _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
