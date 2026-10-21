import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/core/theme/app_theme.dart';
import 'package:badrgo_ops_console/features/alerts/domain/entities/alert_entity.dart';
import 'package:badrgo_ops_console/features/alerts/domain/repositories/alerts_repository.dart';
import 'package:badrgo_ops_console/features/alerts/presentation/bloc/global_sos_cubit.dart';
import 'package:badrgo_ops_console/features/alerts/presentation/widgets/alert_card.dart';
import 'package:badrgo_ops_console/features/auth/domain/entities/user_entity.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_state.dart';
import 'package:badrgo_ops_console/features/shell/presentation/widgets/global_sos_banner.dart';

class _FakeAlertsRepository implements AlertsRepository {
  final _createdController = StreamController<AlertEntity>.broadcast();
  final _ackController = StreamController<AlertEntity>.broadcast();

  List<AlertEntity> alertsToReturn = [];
  bool wasAckCalled = false;
  String? lastAckedId;

  void emitCreated(AlertEntity alert) {
    _createdController.add(alert);
  }

  void emitAck(AlertEntity alert) {
    _ackController.add(alert);
  }

  @override
  Stream<AlertEntity> get onAlertCreated => _createdController.stream;

  @override
  Stream<AlertEntity> get onAlertAcknowledged => _ackController.stream;

  @override
  Future<ApiResult<List<AlertEntity>>> fetchAlerts({
    int page = 1,
    int pageSize = 50,
  }) async {
    return ApiSuccess(alertsToReturn);
  }

  @override
  Future<ApiResult<AlertEntity>> acknowledgeAlert(String alertId) async {
    wasAckCalled = true;
    lastAckedId = alertId;
    final match = alertsToReturn.firstWhere(
      (a) => a.id == alertId,
      orElse: () => AlertEntity(
        id: alertId,
        cityId: 'city_doh',
        type: AlertType.sos,
        severity: AlertSeverity.critical,
        message: 'SOS',
        createdAt: DateTime.now(),
      ),
    );

    final acknowledged = match.copyWith(
      acknowledgedAt: DateTime.now(),
      acknowledgedBy: 'dispatch.doha@demo.test',
    );
    _ackController.add(acknowledged);
    return ApiSuccess(acknowledged);
  }

  @override
  void dispose() {
    _createdController.close();
    _ackController.close();
  }
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(super.initialState);

  @override
  Future<void> login({required String email, required String password}) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> restoreSession() async {}

  @override
  void handleUnauthorized() {}
}

void main() {
  group('Part 6.4: Alerts RBAC Widget Tests', () {
    testWidgets('Acknowledge button is visible for dispatcher with alert:acknowledge', (tester) async {
      final alert = AlertEntity(
        id: 'alt-1',
        cityId: 'city_doh',
        type: AlertType.sos,
        severity: AlertSeverity.critical,
        message: 'Driver emergency triggered on Corniche',
        createdAt: DateTime.now(),
      );

      var ackTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AlertCard(
              alert: alert,
              canAcknowledge: true,
              onAcknowledge: () => ackTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Acknowledge'), findsOneWidget);
      expect(find.text('Pending Acknowledgment'), findsNothing);

      await tester.tap(find.text('Acknowledge'));
      expect(ackTapped, isTrue);
    });

    testWidgets('Acknowledge button is HIDDEN for viewer without alert:acknowledge', (tester) async {
      final alert = AlertEntity(
        id: 'alt-2',
        cityId: 'city_doh',
        type: AlertType.highDemand,
        severity: AlertSeverity.warning,
        message: 'High demand in Al Sadd',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: AlertCard(
              alert: alert,
              canAcknowledge: false,
              onAcknowledge: () {},
            ),
          ),
        ),
      );

      expect(find.text('Acknowledge'), findsNothing);
      expect(find.text('PENDING ACKNOWLEDGMENT'), findsOneWidget);
    });

    testWidgets('GlobalSosBanner renders prominently when active critical alert exists', (tester) async {
      final repository = _FakeAlertsRepository();
      repository.alertsToReturn = [
        AlertEntity(
          id: 'sos-999',
          cityId: 'city_doh',
          type: AlertType.sos,
          severity: AlertSeverity.critical,
          message: 'SOS: Urgent vehicle collision assistance needed',
          tripId: 'trip-777',
          driverId: 'drv-888',
          createdAt: DateTime.now(),
        ),
      ];

      const dispatcher = UserEntity(
        id: 'usr-dispatch',
        name: 'Dispatcher Doha',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['alert:read', 'alert:acknowledge'],
      );

      final authCubit = _FakeAuthCubit(const Authenticated(user: dispatcher, token: 'mock'));
      final globalSosCubit = GlobalSosCubit(repository: repository);
      await globalSosCubit.start();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<AlertsRepository>.value(value: repository),
            ],
            child: MultiBlocProvider(
              providers: [
                BlocProvider<AuthCubit>.value(value: authCubit),
                BlocProvider<GlobalSosCubit>.value(value: globalSosCubit),
              ],
              child: const Scaffold(
                body: Column(
                  children: [
                    GlobalSosBanner(),
                    Expanded(child: Center(child: Text('Dashboard Screen'))),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('CRITICAL SOS EMERGENCY'), findsOneWidget);
      expect(find.textContaining('Urgent vehicle collision assistance'), findsOneWidget);
      expect(find.text('Acknowledge'), findsOneWidget);
      expect(find.text('View Trip'), findsOneWidget);

      // Tap Acknowledge from global banner
      await tester.tap(find.text('Acknowledge'));
      await tester.pumpAndSettle();

      expect(repository.wasAckCalled, isTrue);
      expect(repository.lastAckedId, 'sos-999');

      globalSosCubit.close();
      repository.dispose();
    });

    testWidgets('GlobalSosBanner dismisses completely when close button is tapped', (tester) async {
      final repository = _FakeAlertsRepository();
      repository.alertsToReturn = [
        AlertEntity(
          id: 'sos-111',
          cityId: 'doha',
          type: AlertType.sos,
          severity: AlertSeverity.critical,
          message: 'SOS: Engine failure in highway tunnel',
          createdAt: DateTime.now(),
        ),
      ];

      const dispatcher = UserEntity(
        id: 'usr-dispatch',
        name: 'Dispatcher Doha',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['alert:read'],
      );

      final authCubit = _FakeAuthCubit(const Authenticated(user: dispatcher, token: 'mock'));
      final globalSosCubit = GlobalSosCubit(repository: repository);
      await globalSosCubit.start();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthCubit>.value(value: authCubit),
              BlocProvider<GlobalSosCubit>.value(value: globalSosCubit),
            ],
            child: const Scaffold(
              body: Column(
                children: [
                  GlobalSosBanner(),
                  Expanded(child: Center(child: Text('Dashboard Screen'))),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('CRITICAL SOS EMERGENCY'), findsOneWidget);

      // Tap close button on the SOS banner
      await tester.tap(find.byTooltip('Dismiss SOS Banner'));
      await tester.pumpAndSettle();

      // Banner should be gone immediately!
      expect(find.text('CRITICAL SOS EMERGENCY'), findsNothing);

      globalSosCubit.close();
      repository.dispose();
    });
  });
}
