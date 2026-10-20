import 'package:badrgo_ops_console/core/network/graphql_client.dart';
import 'package:badrgo_ops_console/core/network/rest_client.dart';
import 'package:badrgo_ops_console/core/network/sse/sse_client_stub.dart';
import 'package:badrgo_ops_console/features/trips/data/models/trip_model.dart';
import 'package:badrgo_ops_console/features/trips/data/repositories/trips_repository_impl.dart';
import 'package:badrgo_ops_console/features/trips/domain/entities/trip_entity.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Part 4.2: Trips Data Layer Tests', () {
    test('TripModel parses complete nested GraphQL trip structure correctly', () {
      final json = {
        'id': 'trip_101',
        'status': 'IN_PROGRESS',
        'city': {'id': 'city_doh', 'name': 'Doha'},
        'rider': {'id': 'r_1', 'name': 'Fatima Al-Kuwari', 'phone': '+97455551122'},
        'driver': {
          'id': 'd_1',
          'name': 'Tariq Mansour',
          'phone': '+97466663344',
          'vehicle': {
            'make': 'Kia',
            'model': 'K5',
            'color': 'White',
            'plate': '89231',
          },
        },
        'pickup': {'address': 'Souq Waqif', 'lat': 25.2867, 'lng': 51.5333},
        'dropoff': {'address': 'Katara Cultural Village', 'lat': 25.3548, 'lng': 51.5244},
        'distanceKm': 12.4,
        'fare': {'currency': 'QAR', 'amount': 65.50},
        'refunded': {'currency': 'QAR', 'amount': 0.0},
        'refundReason': null,
        'cancelReason': null,
        'cancelledBy': null,
        'requestedAt': '2026-10-20T14:00:00.000Z',
        'assignedAt': '2026-10-20T14:02:00.000Z',
        'startedAt': '2026-10-20T14:07:00.000Z',
        'completedAt': null,
        'cancelledAt': null,
        'timeline': [
          {'status': 'REQUESTED', 'timestamp': '2026-10-20T14:00:00.000Z'},
          {'status': 'ASSIGNED', 'timestamp': '2026-10-20T14:02:00.000Z'},
          {'status': 'IN_PROGRESS', 'timestamp': '2026-10-20T14:07:00.000Z'},
        ],
      };

      final model = TripModel.fromJson(json);

      expect(model.id, 'trip_101');
      expect(model.status, TripStatus.inProgress);
      expect(model.cityName, 'Doha');
      expect(model.rider.name, 'Fatima Al-Kuwari');
      expect(model.driver?.name, 'Tariq Mansour');
      expect(model.driver?.vehicle, 'Kia K5 · White · 89231');
      expect(model.pickup.name, 'Souq Waqif');
      expect(model.fare.amount, 65.50);
      expect(model.timeline.length, 3);
      expect(model.timeline[2].status, TripStatus.inProgress);
    });

    test('TripModel handles unassigned requested trip with null driver', () {
      final json = {
        'id': 'trip_102',
        'status': 'REQUESTED',
        'city': {'id': 'city_doh', 'name': 'Doha'},
        'rider': {'id': 'r_2', 'name': 'Omar', 'phone': '+97477778899'},
        'driver': null,
        'pickup': {'name': 'West Bay'},
        'dropoff': {'name': 'Hamad International Airport'},
        'distanceKm': 18.0,
        'fare': {'currency': 'QAR', 'amount': 85.0},
        'refunded': {'currency': 'QAR', 'amount': 0.0},
        'requestedAt': '2026-10-20T14:15:00.000Z',
      };

      final model = TripModel.fromJson(json);

      expect(model.id, 'trip_102');
      expect(model.status, TripStatus.requested);
      expect(model.driver, isNull);
      expect(model.canAssign, isTrue);
    });

    test('PaginatedTripsModel parses GraphQL connection envelope with nodes', () {
      final json = {
        'trips': {
          'nodes': [
            {
              'id': 'trip_node_1',
              'status': 'COMPLETED',
              'city': {'id': 'city_doh', 'name': 'Doha'},
              'rider': {'id': 'r_1', 'name': 'Rider 1', 'phone': '123'},
              'pickup': {'name': 'A'},
              'dropoff': {'name': 'B'},
              'distanceKm': 5.0,
              'fare': {'currency': 'QAR', 'amount': 30.0},
              'refunded': {'currency': 'QAR', 'amount': 0.0},
              'requestedAt': '2026-10-20T10:00:00Z',
            },
          ],
          'pageInfo': {
            'hasNextPage': true,
            'endCursor': 'cursor_1',
          },
          'totalCount': 50,
        },
      };

      final model = PaginatedTripsModel.fromGraphQL(json);

      expect(model.trips.length, 1);
      expect(model.trips.first.id, 'trip_node_1');
      expect(model.hasNextPage, isTrue);
      expect(model.endCursor, 'cursor_1');
      expect(model.totalCount, 50);
    });

    test('TripsRepositoryImpl streams live SSE trip.created and trip.updated events', () async {
      final sseStub = SseClientStub();
      final dio = Dio();
      final gqlClient = GraphQLClient(dio: dio);
      final restClient = RestClient(dio: dio);

      final repository = TripsRepositoryImpl(
        graphQLClient: gqlClient,
        restClient: restClient,
        sseClient: sseStub,
      );

      final createdTrips = <TripEntity>[];
      final updatedTrips = <TripEntity>[];

      final sub1 = repository.subscribeTripCreated().listen(createdTrips.add);
      final sub2 = repository.subscribeTripUpdated().listen(updatedTrips.add);

      sseStub.simulateEvent('trip.created', {
        'id': 'trip_sse_1',
        'status': 'REQUESTED',
        'city': {'id': 'city_doh', 'name': 'Doha'},
        'rider': {'id': 'r_1', 'name': 'Live Rider', 'phone': '+974111'},
        'pickup': {'name': 'Live Pickup'},
        'dropoff': {'name': 'Live Dropoff'},
        'distanceKm': 3.5,
        'fare': {'currency': 'QAR', 'amount': 25.0},
        'refunded': {'currency': 'QAR', 'amount': 0.0},
        'requestedAt': DateTime.now().toIso8601String(),
      });

      sseStub.simulateEvent('trip.updated', {
        'id': 'trip_sse_1',
        'status': 'ASSIGNED',
        'city': {'id': 'city_doh', 'name': 'Doha'},
        'rider': {'id': 'r_1', 'name': 'Live Rider', 'phone': '+974111'},
        'driver': {'id': 'd_1', 'name': 'Assigned Driver', 'phone': '+974222'},
        'pickup': {'name': 'Live Pickup'},
        'dropoff': {'name': 'Live Dropoff'},
        'distanceKm': 3.5,
        'fare': {'currency': 'QAR', 'amount': 25.0},
        'refunded': {'currency': 'QAR', 'amount': 0.0},
        'requestedAt': DateTime.now().toIso8601String(),
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(createdTrips.length, 1);
      expect(createdTrips.first.id, 'trip_sse_1');
      expect(createdTrips.first.status, TripStatus.requested);

      expect(updatedTrips.length, 1);
      expect(updatedTrips.first.id, 'trip_sse_1');
      expect(updatedTrips.first.status, TripStatus.assigned);
      expect(updatedTrips.first.driver?.name, 'Assigned Driver');

      await sub1.cancel();
      await sub2.cancel();
    });
  });
}
