import 'dart:async';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/graphql_client.dart';
import '../../../../core/network/sse/sse_client.dart';
import '../../domain/entities/kpi_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../models/kpi_model.dart';

/// Concrete implementation of DashboardRepository using GraphQL and SSE.
///
/// Adheres strictly to requirements:
/// - TR-2: "GraphQL: Dashboard KPIs and charts"
/// - TR-3: "SSE (/api/events): Live KPI tiles"
/// - M3: "KPI tiles: active trips, completed, cancellation rate, revenue,
///   drivers available and on trip, open alerts. Load them with GraphQL kpis,
///   then keep them live with the SSE kpi event."
class DashboardRepositoryImpl implements DashboardRepository {
  final GraphQLClient _graphQLClient;
  final SseClient _sseClient;

  static const String _kpiQuery = r'''
    query GetKpis($range: KpiRange!) {
      kpis(range: $range) {
        range
        generatedAt
        openAlerts
        trips {
          active
          completed
          cancelled
          cancellationRate
        }
        revenue {
          currency
          amount
        }
        drivers {
          available
          onTrip
          offline
          total
        }
        series {
          bucket
          total
          completed
          cancelled
        }
      }
    }
  ''';

  DashboardRepositoryImpl({
    required GraphQLClient graphQLClient,
    required SseClient sseClient,
  })  : _graphQLClient = graphQLClient,
        _sseClient = sseClient;

  @override
  Future<ApiResult<KpiEntity>> getKpis(KpiRange range) async {
    return _graphQLClient.query<KpiEntity>(
      document: _kpiQuery,
      variables: {'range': range.apiValue},
      fromData: (data) {
        final kpisMap = data['kpis'] as Map<String, dynamic>? ?? {};
        return KpiModel.fromJson(kpisMap).toEntity();
      },
    );
  }

  @override
  Stream<KpiEntity> subscribeKpiUpdates() {
    return _sseClient.listenTo('kpi').map((json) {
      return KpiModel.fromJson(json).toEntity();
    });
  }

  @override
  Future<void> dispose() async {
    // SseClient connection lifecycle is managed centrally across the app session.
  }
}
