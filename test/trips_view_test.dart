import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/features/auth/domain/entities/user_entity.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_state.dart';
import 'package:badrgo_ops_console/features/trips/domain/entities/trip_entity.dart';
import 'package:badrgo_ops_console/features/trips/domain/repositories/trips_repository.dart';
import 'package:badrgo_ops_console/features/trips/presentation/bloc/trips_cubit.dart';
import 'package:badrgo_ops_console/features/trips/presentation/widgets/trip_detail_sheet.dart';
import 'package:badrgo_ops_console/features/trips/presentation/widgets/trips_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTripsRepository implements TripsRepository {
  final TripEntity testTrip = TripEntity(
    id: 'trip_1001',
    status: TripStatus.requested,
    cityId: 'city_doh',
    cityName: 'Doha',
    rider: const RiderEntity(
      id: 'r_1',
      name: 'Salim Al-Hajri',
      phone: '+97455551234',
    ),
    driver: null,
    pickup: const PlaceEntity(name: 'Doha Festival City'),
    dropoff: const PlaceEntity(name: 'Villaggio Mall'),
    distanceKm: 14.5,
    fare: const MoneyEntity(currency: 'QAR', amount: 55.0),
    refunded: const MoneyEntity(currency: 'QAR', amount: 0.0),
    requestedAt: DateTime.now(),
  );

  @override
  Future<ApiResult<PaginatedTripsEntity>> getTrips({
    TripFilterEntity? filter,
    int first = 20,
    String? after,
  }) async {
    return ApiSuccess(
      PaginatedTripsEntity(
        trips: [testTrip],
        hasNextPage: false,
        totalCount: 1,
      ),
    );
  }

  @override
  Future<ApiResult<TripEntity>> getTripById(String id) async {
    return ApiSuccess(testTrip);
  }

  @override
  Future<ApiResult<List<DriverEntity>>> getAvailableDrivers({String? cityId}) async {
    return const ApiSuccess([]);
  }

  @override
  Future<ApiResult<TripEntity>> assignDriver({
    required String tripId,
    required String driverId,
  }) async {
    return ApiSuccess(testTrip);
  }

  @override
  Future<ApiResult<TripEntity>> cancelTrip({
    required String tripId,
    required String reason,
  }) async {
    return ApiSuccess(testTrip);
  }

  @override
  Future<ApiResult<TripEntity>> refundTrip({
    required String tripId,
    required double amount,
    required String reason,
  }) async {
    return ApiSuccess(testTrip);
  }

  @override
  Stream<TripEntity> subscribeTripCreated() => const Stream.empty();

  @override
  Stream<TripEntity> subscribeTripUpdated() => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

class FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  FakeAuthCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Part 4.4: Trips View Layer Tests', () {
    late FakeTripsRepository tripsRepository;

    setUp(() {
      tripsRepository = FakeTripsRepository();
    });

    Widget createWidgetUnderTest(AuthState authState) {
      final fakeAuthCubit = FakeAuthCubit(authState);

      return MaterialApp(
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<TripsRepository>.value(
              value: tripsRepository,
            ),
          ],
          child: BlocProvider<AuthCubit>.value(
            value: fakeAuthCubit,
            child: const Scaffold(
              body: TripsScreen(),
            ),
          ),
        ),
      );
    }

    testWidgets('TripsScreen renders table header, filters, and trip rows', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const dispatcherUser = UserEntity(
        id: 'u_disp',
        name: 'Dispatcher Doha',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['trip:read', 'trip:assign', 'trip:cancel'],
      );

      await tester.pumpWidget(createWidgetUnderTest(const Authenticated(user: dispatcherUser, token: 'tok')));
      await tester.pumpAndSettle();

      expect(find.text('Trips Operations'), findsOneWidget);
      expect(find.text('1 trips'), findsOneWidget);
      expect(find.text('Salim Al-Hajri'), findsOneWidget);
      expect(find.text('+97455551234'), findsOneWidget); // Unmasked for dispatcher
      expect(find.text('Doha Festival City'), findsOneWidget);
    });

    testWidgets('TripsScreen masks phone numbers for viewer role', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const viewerUser = UserEntity(
        id: 'u_viewer',
        name: 'Viewer Doha',
        email: 'viewer.doha@demo.test',
        role: 'viewer',
        city: 'Doha',
        permissions: ['trip:read', 'kpi:read'],
      );

      await tester.pumpWidget(createWidgetUnderTest(const Authenticated(user: viewerUser, token: 'tok')));
      await tester.pumpAndSettle();

      expect(find.text('+97455551234'), findsNothing); // Raw phone is hidden!
      expect(find.textContaining('••••'), findsWidgets); // Masked representation displayed
    });

    testWidgets('TripDetailSheet hides all action buttons for viewer role', (tester) async {
      const viewerUser = UserEntity(
        id: 'u_viewer',
        name: 'Viewer Doha',
        email: 'viewer.doha@demo.test',
        role: 'viewer',
        city: 'Doha',
        permissions: ['trip:read', 'kpi:read'],
      );

      final fakeAuthCubit = FakeAuthCubit(const Authenticated(user: viewerUser, token: 'tok'));
      final tripsCubit = TripsCubit(repository: tripsRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>.value(value: fakeAuthCubit),
              BlocProvider<TripsCubit>.value(value: tripsCubit),
            ],
            child: Scaffold(
              body: TripDetailSheet(
                trip: tripsRepository.testTrip,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assign Driver'), findsNothing);
      expect(find.text('Cancel Trip'), findsNothing);
      expect(find.text('Refund Trip'), findsNothing);
    });

    testWidgets('TripDetailSheet shows Assign Driver & Cancel for dispatcher', (tester) async {
      const dispatcherUser = UserEntity(
        id: 'u_disp',
        name: 'Dispatcher Doha',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['trip:read', 'trip:assign', 'trip:cancel'],
      );

      final fakeAuthCubit = FakeAuthCubit(const Authenticated(user: dispatcherUser, token: 'tok'));
      final tripsCubit = TripsCubit(repository: tripsRepository);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>.value(value: fakeAuthCubit),
              BlocProvider<TripsCubit>.value(value: tripsCubit),
            ],
            child: Scaffold(
              body: TripDetailSheet(
                trip: tripsRepository.testTrip,
                onClose: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assign Driver'), findsOneWidget);
      expect(find.text('Cancel Trip'), findsOneWidget);
      expect(find.text('Refund Trip'), findsNothing); // Dispatcher lacks refund permission
    });
  });
}
