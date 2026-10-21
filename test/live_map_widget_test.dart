import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/core/network/ws/ws_connection_state.dart';
import 'package:badrgo_ops_console/core/theme/app_theme.dart';
import 'package:badrgo_ops_console/features/auth/domain/entities/user_entity.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_state.dart';
import 'package:badrgo_ops_console/features/map/domain/entities/driver_location_entity.dart';
import 'package:badrgo_ops_console/features/map/domain/repositories/map_repository.dart';
import 'package:badrgo_ops_console/features/map/presentation/bloc/live_map_cubit.dart';
import 'package:badrgo_ops_console/features/map/presentation/bloc/live_map_state.dart';
import 'package:badrgo_ops_console/features/map/presentation/widgets/driver_detail_card.dart';
import 'package:badrgo_ops_console/features/map/presentation/widgets/live_map_screen.dart';
import 'package:badrgo_ops_console/features/trips/domain/entities/trip_entity.dart';

class _FakeMapRepository implements MapRepository {
  final _locationsController =
      StreamController<List<DriverLocationEntity>>.broadcast();
  final _stateController =
      StreamController<WsConnectionState>.broadcast();
  final _countdownController = StreamController<int?>.broadcast();

  bool isTrackingStarted = false;
  bool isTrackingStopped = false;

  void emitDrivers(List<DriverLocationEntity> drivers) {
    _locationsController.add(drivers);
  }

  void emitState(WsConnectionState state) {
    _stateController.add(state);
  }

  void emitCountdown(int? seconds) {
    _countdownController.add(seconds);
  }

  @override
  Stream<List<DriverLocationEntity>> streamDriverLocations() =>
      _locationsController.stream;

  @override
  Stream<WsConnectionState> get connectionStateStream =>
      _stateController.stream;

  @override
  Stream<int?> get countdownStream => _countdownController.stream;

  @override
  WsConnectionState get connectionState => WsConnectionState.connected;

  @override
  List<DriverLocationEntity> get cachedDrivers => const [];

  @override
  void startTracking(String token) {
    isTrackingStarted = true;
  }

  @override
  void stopTracking() {
    isTrackingStopped = true;
  }

  @override
  Future<ApiResult<DriverEntity>> getDriverDetails(String driverId) async {
    return ApiSuccess(
      DriverEntity(
        id: driverId,
        name: 'Test Driver',
        phone: '+97455001122',
        vehicle: 'Toyota Camry · White',
        status: 'available',
      ),
    );
  }

  @override
  Future<ApiResult<TripEntity?>> getActiveTrip(String tripId) async {
    return const ApiSuccess(null);
  }

  @override
  void dispose() {
    _locationsController.close();
    _stateController.close();
    _countdownController.close();
  }
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(super.initialState);

  @override
  Future<void> login({required String email, required String password}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> restoreSession() async {}

  @override
  void handleUnauthorized() {}
}

void main() {
  group('Part 5.4: LiveMapCubit State & RBAC Logic', () {
    test('emits LiveMapRestricted when user lacks driver:track permission', () {
      final repository = _FakeMapRepository();
      const supportUser = UserEntity(
        id: 'usr-support',
        name: 'Support Agent',
        email: 'support.doha@demo.test',
        role: 'support',
        city: 'Doha',
        permissions: ['trip:read', 'trip:refund'], // No driver:track
      );

      final cubit = LiveMapCubit(
        repository: repository,
        currentUser: supportUser,
        token: 'token_123',
      );

      cubit.initTracking();

      expect(cubit.state, isA<LiveMapRestricted>());
      expect((cubit.state as LiveMapRestricted).requiredPermission, 'driver:track');
      expect(repository.isTrackingStarted, isFalse);

      cubit.close();
      repository.dispose();
    });

    test('starts tracking and sets city center when user has driver:track', () async {
      final repository = _FakeMapRepository();
      const dispatcherRayyan = UserEntity(
        id: 'usr-dispatcher',
        name: 'Rayyan Dispatcher',
        email: 'dispatch.rayyan@demo.test',
        role: 'dispatcher',
        city: 'Al Rayyan',
        permissions: ['driver:track', 'trip:read', 'trip:assign'],
      );

      final cubit = LiveMapCubit(
        repository: repository,
        currentUser: dispatcherRayyan,
        token: 'token_rayyan',
      );

      cubit.initTracking();

      expect(repository.isTrackingStarted, isTrue);
      expect(cubit.state, isA<LiveMapLoaded>());

      final loaded = cubit.state as LiveMapLoaded;
      expect(loaded.centerLat, 25.2919);
      expect(loaded.centerLng, 51.4244);

      // Emit new driver update
      final testDriver = DriverLocationEntity(
        id: 'd-1',
        name: 'Tariq',
        phone: '+97455998877',
        status: 'available',
        latitude: 25.292,
        longitude: 51.425,
        updatedAt: DateTime.now(),
      );
      repository.emitDrivers([testDriver]);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      final updatedState = cubit.state as LiveMapLoaded;
      expect(updatedState.allDrivers.length, 1);
      expect(updatedState.availableCount, 1);
      expect(updatedState.onTripCount, 0);

      cubit.close();
      repository.dispose();
    });

    test('filtering by status and search updates filteredDrivers list', () async {
      final repository = _FakeMapRepository();
      const opsManager = UserEntity(
        id: 'usr-ops',
        name: 'Ops Manager',
        email: 'ops.doha@demo.test',
        role: 'ops_manager',
        city: 'Doha',
        permissions: ['driver:track'],
      );

      final cubit = LiveMapCubit(
        repository: repository,
        currentUser: opsManager,
        token: 'token_doha',
      );

      cubit.initTracking();

      final drivers = [
        DriverLocationEntity(
          id: 'd-1',
          name: 'Ahmed',
          phone: '+97455112233',
          status: 'available',
          vehicle: 'Toyota Camry',
          latitude: 25.28,
          longitude: 51.53,
          updatedAt: DateTime.now(),
        ),
        DriverLocationEntity(
          id: 'd-2',
          name: 'Bilal',
          phone: '+97455445566',
          status: 'on_trip',
          vehicle: 'Kia K5',
          latitude: 25.29,
          longitude: 51.54,
          updatedAt: DateTime.now(),
        ),
      ];

      repository.emitDrivers(drivers);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect((cubit.state as LiveMapLoaded).filteredDrivers.length, 2);

      // Filter: available only
      cubit.setFilter('available');
      expect((cubit.state as LiveMapLoaded).filteredDrivers.length, 1);
      expect((cubit.state as LiveMapLoaded).filteredDrivers.first.id, 'd-1');

      // Search: 'kia'
      cubit.setFilter('all');
      cubit.setSearch('kia');
      expect((cubit.state as LiveMapLoaded).filteredDrivers.length, 1);
      expect((cubit.state as LiveMapLoaded).filteredDrivers.first.id, 'd-2');

      cubit.close();
      repository.dispose();
    });
  });

  group('Part 5.5: LiveMapScreen & DriverDetailCard Widget Tests', () {
    testWidgets('renders Access Restricted view when user lacks driver:track', (tester) async {
      final repository = _FakeMapRepository();
      const supportUser = UserEntity(
        id: 'usr-support',
        name: 'Support Doha',
        email: 'support.doha@demo.test',
        role: 'support',
        city: 'Doha',
        permissions: ['trip:read', 'trip:refund'], // No driver:track
      );

      final authCubit = _FakeAuthCubit(const Authenticated(user: supportUser, token: 'mock_token'));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<MapRepository>.value(value: repository),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthCubit>.value(value: authCubit),
              ],
              child: const Scaffold(body: LiveMapScreen()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Live Map Restricted'), findsOneWidget);
      expect(find.textContaining('driver:track'), findsOneWidget);

      repository.dispose();
    });

    testWidgets('DriverDetailCard displays driver data and masks phone for viewer', (tester) async {
      final driver = DriverLocationEntity(
        id: 'drv-456',
        name: 'Saad Al-Kuwari',
        phone: '+97455887766',
        status: 'available',
        vehicle: 'Lexus ES350 · Silver · 112233',
        latitude: 25.2867,
        longitude: 51.5333,
        updatedAt: DateTime.now(),
      );

      // 1. Test for non-viewer (unmasked phone)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DriverDetailCard(
              driver: driver,
              isViewer: false,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Saad Al-Kuwari'), findsOneWidget);
      expect(find.text('+97455887766'), findsOneWidget);
      expect(find.text('AVAILABLE'), findsOneWidget);

      // 2. Test for viewer (masked phone)
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: DriverDetailCard(
              driver: driver,
              isViewer: true,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('+974 •••• ••66'), findsOneWidget);
    });
  });
}
