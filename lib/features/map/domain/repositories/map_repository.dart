import '../../../../core/network/api_result.dart';
import '../../../../core/network/ws/ws_connection_state.dart';
import '../../../trips/domain/entities/trip_entity.dart';
import '../entities/driver_location_entity.dart';

/// Pure domain repository contract for Live Driver Map operations.
///
/// Follows Clean Architecture:
/// - Defined in Domain Layer
/// - Independent of UI and transport implementation details
abstract class MapRepository {
  /// Stream of all active driver locations updated in real time via WebSocket.
  Stream<List<DriverLocationEntity>> streamDriverLocations();

  /// Stream of live WebSocket connection state (connected, reconnecting, etc.).
  Stream<WsConnectionState> get connectionStateStream;

  /// Stream of countdown seconds until next reconnection attempt (if reconnecting).
  Stream<int?> get countdownStream;

  /// Current live WebSocket connection state.
  WsConnectionState get connectionState;

  /// Cached active driver locations in memory.
  List<DriverLocationEntity> get cachedDrivers;

  /// Starts live WebSocket tracking for the authenticated user token.
  void startTracking(String token);

  /// Stops tracking and closes the WebSocket connection.
  void stopTracking();

  /// Fetches comprehensive profile details for a selected driver.
  Future<ApiResult<DriverEntity>> getDriverDetails(String driverId);

  /// Fetches current active trip details for a driver on trip.
  Future<ApiResult<TripEntity?>> getActiveTrip(String tripId);

  /// Disposes of all subscriptions and stream controllers.
  void dispose();
}
