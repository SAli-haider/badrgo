import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/features/auth/domain/entities/user_entity.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_state.dart';
import 'package:badrgo_ops_console/features/dashboard/domain/entities/kpi_entity.dart';
import 'package:badrgo_ops_console/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:badrgo_ops_console/features/dashboard/presentation/widgets/dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDashboardRepository implements DashboardRepository {
  KpiRange? requestedRange;

  @override
  Future<ApiResult<KpiEntity>> getKpis(KpiRange range) async {
    requestedRange = range;
    return ApiSuccess<KpiEntity>(
      KpiEntity(
        range: range,
        generatedAt: DateTime.now(),
        openAlerts: 3,
        trips: const TripsKpiEntity(
          active: 15,
          completed: 450,
          cancelled: 12,
          cancellationRate: 0.026,
        ),
        revenue: const [
          RevenueEntity(currency: 'QAR', amount: 18450.50),
          RevenueEntity(currency: 'USD', amount: 5068.60),
        ],
        drivers: const DriversKpiEntity(
          available: 20,
          onTrip: 15,
          offline: 5,
          total: 40,
        ),
        series: const [
          SeriesPointEntity(
            bucket: '2026-10-20T10:00:00Z',
            total: 25,
            completed: 24,
            cancelled: 1,
          ),
        ],
      ),
    );
  }

  @override
  Stream<KpiEntity> subscribeKpiUpdates() => const Stream.empty();

  @override
  Future<void> dispose() async {}
}

class FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  FakeAuthCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Part 3.4: Dashboard View Layer Tests', () {
    late FakeDashboardRepository dashboardRepository;

    setUp(() {
      dashboardRepository = FakeDashboardRepository();
    });

    Widget createWidgetUnderTest(AuthState authState) {
      final fakeAuthCubit = FakeAuthCubit(authState);

      return MaterialApp(
        home: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<DashboardRepository>.value(
              value: dashboardRepository,
            ),
          ],
          child: BlocProvider<AuthCubit>.value(
            value: fakeAuthCubit,
            child: const Scaffold(
              body: DashboardScreen(),
            ),
          ),
        ),
      );
    }

    testWidgets('displays Access Restricted message when role lacks kpi:read (e.g. support role)', (tester) async {
      const supportUser = UserEntity(
        id: 'user_support',
        name: 'Support Agent',
        email: 'support.doha@demo.test',
        role: 'support',
        city: 'Doha',
        permissions: ['trip:read', 'trip:refund'], // No kpi:read
      );

      await tester.pumpWidget(createWidgetUnderTest(const Authenticated(user: supportUser, token: 'tok')));
      await tester.pumpAndSettle();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('renders all KPI tiles, multi-currency revenue and range buttons for authorized operator', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const opsUser = UserEntity(
        id: 'user_ops',
        name: 'Ops Manager',
        email: 'ops.doha@demo.test',
        role: 'ops_manager',
        city: 'Doha',
        permissions: ['kpi:read', 'trip:read', 'driver:read'],
      );

      await tester.pumpWidget(createWidgetUnderTest(const Authenticated(user: opsUser, token: 'tok')));
      await tester.pumpAndSettle();

      // Header verification
      expect(find.text('Operations Dashboard'), findsOneWidget);
      expect(find.text('Last 24 Hours'), findsOneWidget);
      expect(find.text('Last 7 Days'), findsOneWidget);

      // KPI Metric Tiles verification
      expect(find.text('ACTIVE TRIPS'), findsOneWidget);
      expect(find.text('COMPLETED TRIPS'), findsOneWidget);
      expect(find.text('CANCELLATION RATE'), findsOneWidget);
      expect(find.text('DRIVERS'), findsOneWidget);
      expect(find.text('OPEN ALERTS'), findsOneWidget);

      // Multi-currency revenue cards verification (M3)
      expect(find.text('REVENUE BREAKDOWN'), findsOneWidget);
      expect(find.text('QAR'), findsOneWidget);
      expect(find.text('USD'), findsOneWidget);

      // Tap range switch to Last 7 Days
      await tester.tap(find.text('Last 7 Days'));
      await tester.pumpAndSettle();

      expect(dashboardRepository.requestedRange, KpiRange.last7d);
    });
  });
}
