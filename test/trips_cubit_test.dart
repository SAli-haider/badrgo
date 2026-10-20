import 'dart:async';
import 'package:badrgo_ops_console/core/errors/app_exception.dart';
import 'package:badrgo_ops_console/core/errors/error_code.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/features/trips/domain/entities/trip_entity.dart';
import 'package:badrgo_ops_console/features/trips/domain/repositories/trips_repository.dart';
import 'package:badrgo_ops_console/features/trips/presentation/bloc/trip_action_cubit.dart';
import 'package:badrgo_ops_console/features/trips/presentation/bloc/trip_action_state.dart';
import 'package:badrgo_ops_console/features/trips/presentation/bloc/trips_cubit.dart';
import 'package:badrgo_ops_console/features/trips/presentation/bloc/trips_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockTripsRepository implements TripsRepository {
  ApiResult<PaginatedTripsEntity>? paginatedResult;
  ApiResult<TripEntity>? tripDetailResult;
  ApiResult<List<DriverEntity>>? availableDriversResult;
  ApiResult<TripEntity>? actionResult;

  final StreamController<TripEntity> _createdController =
      StreamController<TripEntity>.broadcast();
  final StreamController<TripEntity> _updatedController =
      StreamController<TripEntity>.broadcast();

  final TripEntity sampleTrip = TripEntity(
    id: 'trip_1',
    status: TripStatus.requested,
    cityId: 'city_doh',
    cityName: 'Doha',
    rider: const RiderEntity(id: 'r_1', name: 'Rider A', phone: '+974111'),
    pickup: const PlaceEntity(name: 'Pickup A'),
    dropoff: const PlaceEntity(name: 'Dropoff B'),
    distanceKm: 5.0,
    fare: const MoneyEntity(currency: 'QAR', amount: 50.0),
    refunded: const MoneyEntity(currency: 'QAR', amount: 0.0),
    requestedAt: DateTime.now(),
  );

  @override
  Future<ApiResult<PaginatedTripsEntity>> getTrips({
    TripFilterEntity? filter,
    int first = 20,
    String? after,
  }) async {
    return paginatedResult ??
        ApiSuccess<PaginatedTripsEntity>(
          PaginatedTripsEntity(
            trips: [sampleTrip],
            hasNextPage: true,
            endCursor: 'cursor_1',
            totalCount: 1,
          ),
        );
  }

  @override
  Future<ApiResult<TripEntity>> getTripById(String id) async {
    return tripDetailResult ?? ApiSuccess<TripEntity>(sampleTrip);
  }

  @override
  Future<ApiResult<List<DriverEntity>>> getAvailableDrivers({String? cityId}) async {
    return availableDriversResult ??
        const ApiSuccess<List<DriverEntity>>([
          DriverEntity(
            id: 'd_1',
            name: 'Driver 1',
            phone: '+974222',
            vehicle: 'Camry',
          ),
        ]);
  }

  @override
  Future<ApiResult<TripEntity>> assignDriver({
    required String tripId,
    required String driverId,
  }) async {
    return actionResult ??
        ApiSuccess<TripEntity>(
          sampleTrip.copyWith(
            status: TripStatus.assigned,
            driver: DriverEntity(id: driverId, name: 'Driver', phone: '+974'),
          ),
        );
  }

  @override
  Future<ApiResult<TripEntity>> cancelTrip({
    required String tripId,
    required String reason,
  }) async {
    return actionResult ??
        ApiSuccess<TripEntity>(
          sampleTrip.copyWith(
            status: TripStatus.cancelled,
            cancelReason: reason,
          ),
        );
  }

  @override
  Future<ApiResult<TripEntity>> refundTrip({
    required String tripId,
    required double amount,
    required String reason,
  }) async {
    return actionResult ??
        ApiSuccess<TripEntity>(
          sampleTrip.copyWith(
            status: TripStatus.completed,
            refunded: MoneyEntity(currency: 'QAR', amount: amount),
            refundReason: reason,
          ),
        );
  }

  @override
  Stream<TripEntity> subscribeTripCreated() => _createdController.stream;

  @override
  Stream<TripEntity> subscribeTripUpdated() => _updatedController.stream;

  void emitCreated(TripEntity trip) => _createdController.add(trip);
  void emitUpdated(TripEntity trip) => _updatedController.add(trip);

  @override
  Future<void> dispose() async {
    await _createdController.close();
    await _updatedController.close();
  }
}

void main() {
  group('Part 4.3: TripsCubit & TripActionCubit ViewModel Tests', () {
    late MockTripsRepository repository;
    late TripsCubit tripsCubit;
    late TripActionCubit actionCubit;

    setUp(() {
      repository = MockTripsRepository();
      tripsCubit = TripsCubit(repository: repository);
      actionCubit = TripActionCubit(repository: repository);
    });

    tearDown(() async {
      await tripsCubit.close();
      await actionCubit.close();
      await repository.dispose();
    });

    test('TripsCubit loads initial trips with pagination metadata', () async {
      await tripsCubit.loadTrips();

      expect(tripsCubit.state, isA<TripsLoaded>());
      final state = tripsCubit.state as TripsLoaded;
      expect(state.trips.length, 1);
      expect(state.hasNextPage, isTrue);
      expect(state.endCursor, 'cursor_1');
    });

    test('TripsCubit fetches next page and appends to existing trips without duplicate IDs', () async {
      await tripsCubit.loadTrips();

      repository.paginatedResult = ApiSuccess(
        PaginatedTripsEntity(
          trips: [
            repository.sampleTrip.copyWith(id: 'trip_2'),
          ],
          hasNextPage: false,
          endCursor: 'cursor_2',
          totalCount: 2,
        ),
      );

      await tripsCubit.fetchNextPage();

      final state = tripsCubit.state as TripsLoaded;
      expect(state.trips.length, 2);
      expect(state.trips[0].id, 'trip_1');
      expect(state.trips[1].id, 'trip_2');
      expect(state.hasNextPage, isFalse);
    });

    test('TripsCubit prepends live SSE trip.created to top and records recentlyCreatedTripIds', () async {
      await tripsCubit.loadTrips();

      final newTrip = repository.sampleTrip.copyWith(id: 'trip_sse_new');
      repository.emitCreated(newTrip);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = tripsCubit.state as TripsLoaded;
      expect(state.trips.first.id, 'trip_sse_new');
      expect(state.recentlyCreatedTripIds, contains('trip_sse_new'));
    });

    test('TripsCubit updates existing trip in-place on SSE trip.updated and marks recentlyUpdatedTripIds', () async {
      await tripsCubit.loadTrips();

      final updatedTrip = repository.sampleTrip.copyWith(
        status: TripStatus.assigned,
        driver: const DriverEntity(id: 'd_1', name: 'Assigned', phone: '123'),
      );
      repository.emitUpdated(updatedTrip);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = tripsCubit.state as TripsLoaded;
      expect(state.trips.first.status, TripStatus.assigned);
      expect(state.recentlyUpdatedTripIds, contains('trip_1'));
    });

    test('TripsCubit surfaces TripNotFound when accessing trip outside city jurisdiction', () async {
      repository.tripDetailResult = ApiSuccess(
        repository.sampleTrip.copyWith(
          cityId: 'city_ray',
          cityName: 'Al Rayyan',
        ),
      );

      // Operator assigned to Doha visits an Al Rayyan trip
      await tripsCubit.selectTrip('trip_1', userCity: 'Doha');

      expect(tripsCubit.state, isA<TripNotFound>());
    });

    test('TripActionCubit handles assign driver successfully', () async {
      await actionCubit.assignDriver(tripId: 'trip_1', driverId: 'd_1');

      expect(actionCubit.state, isA<TripActionSuccess>());
      final success = actionCubit.state as TripActionSuccess;
      expect(success.trip.status, TripStatus.assigned);
    });

    test('TripActionCubit captures 409 INVALID_STATE and emits TripActionConflict with race guidance', () async {
      repository.actionResult = ApiFailure(
        AppException(
          code: ErrorCode.invalidState,
          message: 'The trip is no longer in requested state',
          statusCode: 409,
        ),
      );

      await actionCubit.assignDriver(tripId: 'trip_1', driverId: 'd_1');

      expect(actionCubit.state, isA<TripActionConflict>());
      final conflict = actionCubit.state as TripActionConflict;
      expect(conflict.message, contains('409 Conflict'));
      expect(conflict.tripId, 'trip_1');
    });

    test('TripActionCubit validates refund amount against remaining balance', () async {
      // Trying to refund 60 QAR when remaining is only 50 QAR
      await actionCubit.refundTrip(
        tripId: 'trip_1',
        amount: 60.0,
        reason: 'Overcharge',
        maxRefundable: 50.0,
      );

      expect(actionCubit.state, isA<TripActionError>());
      final error = actionCubit.state as TripActionError;
      expect(error.message, contains('exceeds remaining refundable balance'));
    });
  });
}
