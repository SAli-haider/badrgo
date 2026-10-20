import '../../../../core/network/api_result.dart';
import '../entities/kpi_entity.dart';

/// Pure domain contract for Operations Dashboard data.
///
/// Adheres strictly to:
/// - M3: "KPI tiles: active trips, completed, cancellation rate, revenue,
///   drivers available and on trip, open alerts. Load them with GraphQL kpis,
///   then keep them live with the SSE kpi event."
/// - MVVM: Pure contract with zero UI or transport dependencies.
abstract class DashboardRepository {
  /// Fetches current operational KPIs for the given time range using GraphQL.
  Future<ApiResult<KpiEntity>> getKpis(KpiRange range);

  /// Subscribes to realtime KPI updates pushed via SSE `kpi` event.
  Stream<KpiEntity> subscribeKpiUpdates();

  /// Closes any active realtime subscriptions.
  Future<void> dispose();
}
