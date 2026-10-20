import 'dart:async';
import 'package:badrgo_ops_console/core/errors/app_exception.dart';
import 'package:badrgo_ops_console/core/errors/error_code.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/features/dashboard/domain/entities/kpi_entity.dart';
import 'package:badrgo_ops_console/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:badrgo_ops_console/features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'package:badrgo_ops_console/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:flutter_test/flutter_test.dart';

class MockDashboardRepository implements DashboardRepository {
  ApiResult<KpiEntity>? kpiResult;
  final StreamController<KpiEntity> _sseController = StreamController<KpiEntity>.broadcast();
  KpiRange? lastRequestedRange;

  @override
  Future<ApiResult<KpiEntity>> getKpis(KpiRange range) async {
    lastRequestedRange = range;
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return kpiResult ??
        ApiSuccess<KpiEntity>(
          KpiEntity(
            range: range,
            generatedAt: DateTime.now(),
            openAlerts: 2,
            trips: const TripsKpiEntity(
              active: 12,
              completed: 400,
              cancelled: 10,
              cancellationRate: 0.024,
            ),
            revenue: const [
              RevenueEntity(currency: 'QAR', amount: 15000.0),
            ],
            drivers: const DriversKpiEntity(
              available: 18,
              onTrip: 12,
              offline: 5,
              total: 35,
            ),
            series: const [
              SeriesPointEntity(
                bucket: '2026-10-20T10:00:00Z',
                total: 30,
                completed: 28,
                cancelled: 2,
              ),
            ],
          ),
        );
  }

  @override
  Stream<KpiEntity> subscribeKpiUpdates() => _sseController.stream;

  void emitSseUpdate(KpiEntity kpi) {
    _sseController.add(kpi);
  }

  @override
  Future<void> dispose() async {
    await _sseController.close();
  }
}

void main() {
  group('Part 3.3: DashboardCubit ViewModel Tests', () {
    late MockDashboardRepository repository;
    late DashboardCubit cubit;

    setUp(() {
      repository = MockDashboardRepository();
      cubit = DashboardCubit(repository: repository);
    });

    tearDown(() async {
      await cubit.close();
      await repository.dispose();
    });

    test('emits DashboardRestricted when user lacks kpi:read permission (e.g. support role)', () async {
      await cubit.loadDashboard(hasKpiPermission: false);

      expect(cubit.state, isA<DashboardRestricted>());
    });

    test('emits [DashboardLoading, DashboardLoaded] on initial load with permission', () async {
      final states = <DashboardState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadDashboard(hasKpiPermission: true);
      await Future<void>.delayed(Duration.zero);

      expect(states.length, 2);
      expect(states[0], isA<DashboardLoading>());
      expect(states[1], isA<DashboardLoaded>());

      final loaded = states[1] as DashboardLoaded;
      expect(loaded.kpi.trips.active, 12);
      expect(loaded.kpi.revenue.first.amount, 15000.0);
      expect(loaded.selectedRange, KpiRange.last24h);

      await sub.cancel();
    });

    test('reactively updates tiles on SSE kpi event without losing series chart data', () async {
      await cubit.loadDashboard(hasKpiPermission: true);
      expect(cubit.state, isA<DashboardLoaded>());

      final loadedBefore = cubit.state as DashboardLoaded;
      expect(loadedBefore.kpi.series, isNotEmpty);

      // Simulate incoming SSE event with refreshed numbers and empty series
      repository.emitSseUpdate(
        KpiEntity(
          range: KpiRange.last24h,
          generatedAt: DateTime.now(),
          openAlerts: 5,
          trips: const TripsKpiEntity(
            active: 16,
            completed: 405,
            cancelled: 11,
            cancellationRate: 0.026,
          ),
          revenue: const [
            RevenueEntity(currency: 'QAR', amount: 15350.0),
          ],
          drivers: const DriversKpiEntity(
            available: 15,
            onTrip: 16,
            offline: 4,
            total: 35,
          ),
          series: const [], // Empty series from SSE event
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loadedAfter = cubit.state as DashboardLoaded;
      expect(loadedAfter.kpi.trips.active, 16);
      expect(loadedAfter.kpi.openAlerts, 5);
      expect(loadedAfter.isLivePulse, isTrue);
      // Preserved historical series from GraphQL initial fetch!
      expect(loadedAfter.kpi.series.length, 1);
      expect(loadedAfter.kpi.series.first.total, 30);
    });

    test('switchRange changes period to Last 7 Days and re-fetches GraphQL', () async {
      await cubit.loadDashboard(hasKpiPermission: true);

      await cubit.switchRange(KpiRange.last7d);

      expect(repository.lastRequestedRange, KpiRange.last7d);
      final loaded = cubit.state as DashboardLoaded;
      expect(loaded.selectedRange, KpiRange.last7d);
    });

    test('emits DashboardError when GraphQL query fails', () async {
      repository.kpiResult = ApiFailure(
        AppException(
          code: ErrorCode.networkError,
          message: 'Failed to fetch GraphQL KPIs',
        ),
      );

      await cubit.loadDashboard(hasKpiPermission: true);

      expect(cubit.state, isA<DashboardError>());
      expect((cubit.state as DashboardError).message, contains('Failed to fetch'));
    });
  });
}
