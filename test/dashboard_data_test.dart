import 'dart:async';
import 'package:badrgo_ops_console/core/network/graphql_client.dart';
import 'package:badrgo_ops_console/core/network/sse/sse_client_stub.dart';
import 'package:badrgo_ops_console/core/network/sse/sse_ready_event.dart';
import 'package:badrgo_ops_console/features/dashboard/data/models/kpi_model.dart';
import 'package:badrgo_ops_console/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:badrgo_ops_console/features/dashboard/domain/entities/kpi_entity.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Part 3.1 & 3.2: Dashboard Domain & Data Layer', () {
    test('KpiModel correctly parses full GraphQL payload with multi-currency revenue', () {
      final json = {
        'range': 'LAST_24H',
        'generatedAt': '2026-10-20T12:00:00.000Z',
        'openAlerts': 3,
        'trips': {
          'active': 14,
          'completed': 520,
          'cancelled': 25,
          'cancellationRate': 0.045,
        },
        'revenue': [
          {'currency': 'QAR', 'amount': 18450.5},
          {'currency': 'USD', 'amount': 5068.6},
        ],
        'drivers': {
          'available': 22,
          'onTrip': 14,
          'offline': 8,
          'total': 44,
        },
        'series': [
          {'bucket': '2026-10-20T08:00:00Z', 'total': 40, 'completed': 38, 'cancelled': 2},
          {'bucket': '2026-10-20T09:00:00Z', 'total': 55, 'completed': 52, 'cancelled': 3},
        ],
      };

      final model = KpiModel.fromJson(json);

      expect(model.range, KpiRange.last24h);
      expect(model.openAlerts, 3);
      expect(model.trips.active, 14);
      expect(model.trips.completed, 520);
      expect(model.trips.cancellationRate, 0.045);

      // M3: "revenue is a list with one entry per currency. Render it correctly."
      expect(model.revenue.length, 2);
      expect(model.revenue[0].currency, 'QAR');
      expect(model.revenue[0].amount, 18450.5);
      expect(model.revenue[1].currency, 'USD');
      expect(model.revenue[1].amount, 5068.6);

      expect(model.drivers.available, 22);
      expect(model.drivers.onTrip, 14);
      expect(model.drivers.total, 44);

      expect(model.series.length, 2);
      expect(model.series[0].bucket, '2026-10-20T08:00:00Z');
      expect(model.series[0].total, 40);
    });

    test('KpiModel handles null or empty series and 7D range gracefully', () {
      final json = {
        'range': 'LAST_7D',
        'generatedAt': '2026-10-20T12:00:00.000Z',
        'openAlerts': 0,
        'trips': {'active': 0, 'completed': 0, 'cancelled': 0, 'cancellationRate': 0.0},
        'revenue': [],
        'drivers': {'available': 0, 'onTrip': 0, 'offline': 0, 'total': 0},
      };

      final model = KpiModel.fromJson(json);
      expect(model.range, KpiRange.last7d);
      expect(model.openAlerts, 0);
      expect(model.revenue, isEmpty);
      expect(model.series, isEmpty);
    });

    test('SseClientStub manages connection lifecycle and ready event', () async {
      final sseStub = SseClientStub();

      expect(sseStub.isConnected, isFalse);

      final readyCompleter = Completer<SseReadyEvent>();
      sseStub.onReady.listen(readyCompleter.complete);

      final stateHistory = <bool>[];
      sseStub.onConnectionState.listen(stateHistory.add);

      sseStub.connect('test_token');

      expect(sseStub.isConnected, isTrue);
      final readyEvent = await readyCompleter.future;
      expect(readyEvent.topics, contains('kpi'));
      expect(readyEvent.isTopicDenied('kpi'), isFalse);

      sseStub.disconnect();
      await Future<void>.delayed(Duration.zero);
      expect(sseStub.isConnected, isFalse);
      expect(stateHistory, [true, false]);
    });

    test('DashboardRepositoryImpl streams real-time KPI events from SSE', () async {
      final sseStub = SseClientStub();
      final dio = Dio();
      final gqlClient = GraphQLClient(dio: dio);

      final repository = DashboardRepositoryImpl(
        graphQLClient: gqlClient,
        sseClient: sseStub,
      );

      final receivedKpis = <KpiEntity>[];
      final subscription = repository.subscribeKpiUpdates().listen(receivedKpis.add);

      sseStub.simulateEvent('kpi', {
        'range': 'LAST_24H',
        'generatedAt': DateTime.now().toIso8601String(),
        'openAlerts': 1,
        'trips': {'active': 10, 'completed': 200, 'cancelled': 5, 'cancellationRate': 0.02},
        'revenue': [{'currency': 'QAR', 'amount': 7500.0}],
        'drivers': {'available': 15, 'onTrip': 10, 'offline': 2, 'total': 27},
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(receivedKpis.length, 1);
      expect(receivedKpis.first.trips.active, 10);
      expect(receivedKpis.first.revenue.first.amount, 7500.0);

      await subscription.cancel();
    });
  });
}
