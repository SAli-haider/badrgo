import '../../../../core/network/api_result.dart';
import '../entities/trip_entity.dart';

/// Pure domain repository contract for Trips management and actions.
///
/// Adheres strictly to M4 requirements:
/// - Reads via GraphQL (paginated list with filters, nested detail).
/// - Writes via REST (assign driver, cancel trip, refund trip).
/// - Realtime updates via SSE (`trip.created`, `trip.updated`).
/// - Pure Dart contract with ZERO UI or transport dependencies.
abstract class TripsRepository {
  /// Fetches paginated trips matching optional filters via GraphQL.
  Future<ApiResult<PaginatedTripsEntity>> getTrips({
    TripFilterEntity? filter,
    int first = 20,
    String? after,
  });

  /// Fetches single trip with full nested details (timeline, rider, driver, city).
  Future<ApiResult<TripEntity>> getTripById(String id);

  /// Fetches available drivers for the assignment picker.
  Future<ApiResult<List<DriverEntity>>> getAvailableDrivers({String? cityId});

  /// Assigns an available driver to a requested trip via REST.
  Future<ApiResult<TripEntity>> assignDriver({
    required String tripId,
    required String driverId,
  });

  /// Cancels a trip with a stated reason via REST.
  Future<ApiResult<TripEntity>> cancelTrip({
    required String tripId,
    required String reason,
  });

  /// Issues a refund for a completed trip with validated amount & reason via REST.
  Future<ApiResult<TripEntity>> refundTrip({
    required String tripId,
    required double amount,
    required String reason,
  });

  /// Subscribes to live `trip.created` SSE events.
  Stream<TripEntity> subscribeTripCreated();

  /// Subscribes to live `trip.updated` SSE events.
  Stream<TripEntity> subscribeTripUpdated();

  /// Closes active subscriptions.
  Future<void> dispose();
}
