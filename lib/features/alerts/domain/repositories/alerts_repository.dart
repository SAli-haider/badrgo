import '../../../../core/network/api_result.dart';
import '../entities/alert_entity.dart';

/// Pure domain repository contract for operational alerts.
///
/// Follows Clean Architecture:
/// - Defined in Domain Layer
/// - Independent of UI and transport implementation details
abstract class AlertsRepository {
  /// Fetches paginated alerts list (newest first) from REST API.
  Future<ApiResult<List<AlertEntity>>> fetchAlerts({
    int page = 1,
    int pageSize = 50,
  });

  /// Acknowledges an alert via REST API.
  /// Requires `alert:acknowledge` permission.
  Future<ApiResult<AlertEntity>> acknowledgeAlert(String alertId);

  /// Real-time stream of incoming new alerts from SSE `alert.created`.
  Stream<AlertEntity> get onAlertCreated;

  /// Real-time stream of acknowledged alert updates from SSE `alert.acknowledged`.
  Stream<AlertEntity> get onAlertAcknowledged;

  /// Disposes of SSE subscriptions and internal stream controllers.
  void dispose();
}
