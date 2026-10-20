import '../errors/app_exception.dart';
import '../network/graphql_client.dart';
import '../network/network_event_bus.dart';
import '../network/rest_client.dart';
import '../network/sse/sse_client.dart';
import '../router/app_router.dart';
import '../storage/session_storage.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/health/data/repositories/health_repository_impl.dart';
import '../../features/health/domain/repositories/health_repository.dart';
import '../../features/health/presentation/bloc/health_cubit.dart';
import '../../features/trips/data/repositories/trips_repository_impl.dart';
import '../../features/trips/domain/repositories/trips_repository.dart';

/// Clean Composition Root & Dependency Container.
///
/// Encapsulates initialization of:
/// - Core storage and transports (Dio REST, GraphQL, SSE, Event Bus)
/// - Repositories (Data Layer)
/// - ViewModels (BLoC / Cubit)
/// - AppRouter (RBAC Route Guards)
class AppDependencies {
  final SessionStorage sessionStorage;
  final RestClient restClient;
  final GraphQLClient graphQLClient;
  final SseClient sseClient;
  final AuthRepository authRepository;
  final HealthRepository healthRepository;
  final DashboardRepository dashboardRepository;
  final TripsRepository tripsRepository;
  final AuthCubit authCubit;
  final HealthCubit healthCubit;
  final AppRouter appRouter;

  const AppDependencies({
    required this.sessionStorage,
    required this.restClient,
    required this.graphQLClient,
    required this.sseClient,
    required this.authRepository,
    required this.healthRepository,
    required this.dashboardRepository,
    required this.tripsRepository,
    required this.authCubit,
    required this.healthCubit,
    required this.appRouter,
  });

  /// Factory initializer that sets up dependencies, restores user session,
  /// and prepares the app for launch.
  static Future<AppDependencies> init() async {
    // 1. Core Storage & Stored Credentials
    final sessionStorage = SessionStorage();
    final savedToken = sessionStorage.getToken();

    // 2. Global Event Bus (propagate 401 & 503 across transports)
    final eventBus = _AppNetworkEventBus();

    // 3. Network Clients
    final restClient = RestClient(eventBus: eventBus);
    if (savedToken != null && savedToken.isNotEmpty) {
      restClient.updateToken(savedToken);
    }

    final graphQLClient = GraphQLClient(eventBus: eventBus);
    if (savedToken != null && savedToken.isNotEmpty) {
      graphQLClient.updateToken(savedToken);
    }

    final sseClient = SseClient(eventBus: eventBus);
    if (savedToken != null && savedToken.isNotEmpty) {
      sseClient.connect(savedToken);
    }

    // 4. Data Repositories
    final healthRepository = HealthRepositoryImpl(restClient: restClient);
    final authRepository = AuthRepositoryImpl(
      restClient: restClient,
      graphQLClient: graphQLClient,
      sessionStorage: sessionStorage,
    );
    final dashboardRepository = DashboardRepositoryImpl(
      graphQLClient: graphQLClient,
      sseClient: sseClient,
    );
    final tripsRepository = TripsRepositoryImpl(
      graphQLClient: graphQLClient,
      restClient: restClient,
      sseClient: sseClient,
    );

    // 5. ViewModels
    final authCubit = AuthCubit(
      authRepository: authRepository,
      sessionStorage: sessionStorage,
    );
    eventBus.attachAuthCubit(authCubit);

    // Clean up or connect SSE when auth state changes (Requirement M1.3)
    authCubit.stream.listen((state) {
      if (state is Authenticated) {
        sseClient.connect(state.token);
      } else if (state is Unauthenticated) {
        sseClient.disconnect();
      }
    });

    final healthCubit = HealthCubit(healthRepository: healthRepository);

    // 6. Router with RBAC Permission Guards
    final appRouter = AppRouter(authCubit: authCubit);

    // 7. Asynchronous bootstrap logic
    await authCubit.restoreSession();
    healthCubit.checkHealth();

    return AppDependencies(
      sessionStorage: sessionStorage,
      restClient: restClient,
      graphQLClient: graphQLClient,
      sseClient: sseClient,
      authRepository: authRepository,
      healthRepository: healthRepository,
      dashboardRepository: dashboardRepository,
      tripsRepository: tripsRepository,
      authCubit: authCubit,
      healthCubit: healthCubit,
      appRouter: appRouter,
    );
  }
}

class _AppNetworkEventBus implements NetworkEventBus {
  AuthCubit? _authCubit;

  void attachAuthCubit(AuthCubit authCubit) {
    _authCubit = authCubit;
  }

  @override
  void onUnauthorized(AppException exception) {
    _authCubit?.handleUnauthorized();
  }

  @override
  void onMaintenance(AppException exception) {
    // Maintenance handler hook for M7
  }
}
