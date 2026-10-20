import '../errors/app_exception.dart';

/// Callbacks invoked by transport clients (REST, GraphQL, SSE, WebSocket)
/// to notify the global session coordinator without tight coupling.
abstract class NetworkEventBus {
  /// Invoked when ANY transport receives a 401 (UNAUTHENTICATED) error.
  /// Requirement M1.3:
  /// "Any 401 from any transport sends the user back to sign-in,
  /// closes the realtime connections, and does not loop."
  void onUnauthorized(AppException exception);

  /// Invoked when ANY transport receives a 503 (MAINTENANCE) error.
  /// Requirement M7:
  /// "The API can go into maintenance... every endpoint returns 503"
  void onMaintenance(AppException exception);
}
