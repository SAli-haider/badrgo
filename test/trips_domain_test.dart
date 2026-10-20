import 'package:badrgo_ops_console/features/trips/domain/entities/trip_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Part 4.1: Trips Domain Layer Tests', () {
    test('TripStatus parses all enum values correctly with fallback to requested', () {
      expect(TripStatus.fromString('REQUESTED'), TripStatus.requested);
      expect(TripStatus.fromString('ASSIGNED'), TripStatus.assigned);
      expect(TripStatus.fromString('IN_PROGRESS'), TripStatus.inProgress);
      expect(TripStatus.fromString('COMPLETED'), TripStatus.completed);
      expect(TripStatus.fromString('CANCELLED'), TripStatus.cancelled);
      expect(TripStatus.fromString('UNKNOWN'), TripStatus.requested);
      expect(TripStatus.fromString(null), TripStatus.requested);
    });

    test('TripEntity action validation guards (canAssign, canCancel, canRefund)', () {
      final requestedTrip = TripEntity(
        id: 'trip_1',
        status: TripStatus.requested,
        cityId: 'city_doh',
        cityName: 'Doha',
        rider: const RiderEntity(id: 'r_1', name: 'Ali', phone: '+97455551234'),
        pickup: const PlaceEntity(name: 'Corniche'),
        dropoff: const PlaceEntity(name: 'The Pearl'),
        distanceKm: 8.5,
        fare: const MoneyEntity(currency: 'QAR', amount: 45.0),
        refunded: const MoneyEntity(currency: 'QAR', amount: 0.0),
        requestedAt: DateTime.now(),
      );

      // Requested state
      expect(requestedTrip.canAssign, isTrue);
      expect(requestedTrip.canCancel, isTrue);
      expect(requestedTrip.canRefund, isFalse);

      // Completed with remaining refundable balance
      final completedTrip = requestedTrip.copyWith(
        status: TripStatus.completed,
        driver: const DriverEntity(
          id: 'd_1',
          name: 'Ahmed',
          phone: '+97455554321',
          vehicle: 'Toyota Camry',
        ),
      );
      expect(completedTrip.canAssign, isFalse);
      expect(completedTrip.canCancel, isFalse);
      expect(completedTrip.canRefund, isTrue);
      expect(completedTrip.remainingRefundableAmount, 45.0);

      // Completed with partial refund
      final partiallyRefundedTrip = completedTrip.copyWith(
        refunded: const MoneyEntity(currency: 'QAR', amount: 20.0),
      );
      expect(partiallyRefundedTrip.canRefund, isTrue);
      expect(partiallyRefundedTrip.remainingRefundableAmount, 25.0);

      // Completed with full refund
      final fullyRefundedTrip = completedTrip.copyWith(
        refunded: const MoneyEntity(currency: 'QAR', amount: 45.0),
      );
      expect(fullyRefundedTrip.canRefund, isFalse);
      expect(fullyRefundedTrip.remainingRefundableAmount, 0.0);

      // Cancelled state
      final cancelledTrip = requestedTrip.copyWith(status: TripStatus.cancelled);
      expect(cancelledTrip.canAssign, isFalse);
      expect(cancelledTrip.canCancel, isFalse);
      expect(cancelledTrip.canRefund, isFalse);
    });

    test('TripFilterEntity copyWith preserves and overrides fields cleanly', () {
      const initial = TripFilterEntity(
        status: [TripStatus.requested],
        search: 'Doha',
      );

      final updated = initial.copyWith(
        status: [TripStatus.completed],
        search: 'Pearl',
      );

      expect(updated.status, [TripStatus.completed]);
      expect(updated.search, 'Pearl');
      expect(updated.from, isNull);
    });
  });
}
