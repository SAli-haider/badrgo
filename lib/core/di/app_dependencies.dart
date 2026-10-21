import '../errors/app_exception.dart';
import '../network/graphql_client.dart';
import '../network/network_event_bus.dart';
import '../network/rest_client.dart';
import '../network/sse/sse_client.dart';
import '../network/ws/ws_client.dart';
import '../router/app_router.dart';
import '../storage/session_storage.dart';
import '../../features/alerts/data/repositories/alerts_repository_impl.dart';
import '../../features/alerts/domain/repositories/alerts_repository.dart';
import '../../features/alerts/presentation/bloc/global_sos_cubit.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_cubit.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/health/data/repositories/health_repository_impl.dart';
import '../../features/health/domain/repositories/health_repository.dart';
import '../../features/health/presentation/bloc/health_cubit.dart';
import '../../features/map/data/repositories/map_repository_impl.dart';
import '../../features/map/domain/repositories/map_repository.dart';
import '../../features/trips/data/repositories/trips_repository_impl.dart';
import '../../features/trips/domain/repositories/trips_repository.dart';

/// Clean Composition Root & Dependency Container.
///
/// Encapsulates initialization of:
/// - Core storage and transports (Dio REST, GraphQL, SSE, WebSocket, Event Bus)
/// - Repositories (Data Layer)
/// - ViewModels (BLoC / Cubit)
/// - AppRouter (RBAC Route Guards)
class AppDependencies {
  final SessionStorage sessionStorage;
  final RestClient restClient;
  final GraphQLClient graphQLClient;
  final SseClient sseClient;
  final WsClient wsClient;
  final AuthRepository authRepository;
  final HealthRepository healthRepository;
  final DashboardRepository dashboardRepository;
  final TripsRepository tripsRepository;
  final MapRepository mapRepository;
  final AlertsRepository alertsRepository;
  final AuthCubit authCubit;
  final HealthCubit healthCubit;
  final GlobalSosCubit globalSosCubit;
  final AppRouter appRouter;

  const AppDependencies({
    required this.sessionStorage,
    required this.restClient,
    required this.graphQLClient,
    required this.sseClient,
    required this.wsClient,
    required this.authRepository,
    required this.healthRepository,
    required this.dashboardRepository,
    required this.tripsRepository,
    required this.mapRepository,
    required this.alertsRepository,
    required this.authCubit,
    required this.healthCubit,
    required this.globalSosCubit,
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

    final wsClient = WsClient(eventBus: eventBus);
    if (savedToken != null && savedToken.isNotEmpty) {
      wsClient.connect(savedToken);
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
    final mapRepository = MapRepositoryImpl(
      wsClient: wsClient,
      restClient: restClient,
    );
    final alertsRepository = AlertsRepositoryImpl(
      restClient: restClient,
      sseClient: sseClient,
    );

    // 5. ViewModels
    final authCubit = AuthCubit(
      authRepository: authRepository,
      sessionStorage: sessionStorage,
    );
    eventBus.attachAuthCubit(authCubit);

    final globalSosCubit = GlobalSosCubit(repository: alertsRepository);

    // Clean up or connect SSE & WebSocket when auth state changes (Requirements M1.3 & M5)
    authCubit.stream.listen((state) {
      if (state is Authenticated) {
        sseClient.connect(state.token);
        wsClient.connect(state.token);
        globalSosCubit.start();
      } else if (state is Unauthenticated) {
        sseClient.disconnect();
        wsClient.disconnect();
        globalSosCubit.stop();
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
      wsClient: wsClient,
      authRepository: authRepository,
      healthRepository: healthRepository,
      dashboardRepository: dashboardRepository,
      tripsRepository: tripsRepository,
      mapRepository: mapRepository,
      alertsRepository: alertsRepository,
      authCubit: authCubit,
      healthCubit: healthCubit,
      globalSosCubit: globalSosCubit,
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
    // Only handle 401 if user was actively Authenticated (prevents bogus errors on logout or fresh visit)
    if (_authCubit?.state is Authenticated) {
      _authCubit?.handleUnauthorized();
    }
  }

  @override
  void onMaintenance(AppException exception) {
    // Maintenance handler hook for M7
  }
}
