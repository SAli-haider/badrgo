import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/core/storage/session_storage.dart';
import 'package:badrgo_ops_console/features/auth/domain/entities/user_entity.dart';
import 'package:badrgo_ops_console/features/auth/domain/repositories/auth_repository.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_state.dart';
import 'package:badrgo_ops_console/features/shell/presentation/widgets/access_denied_screen.dart';
import 'package:badrgo_ops_console/features/shell/presentation/widgets/shell_scaffold.dart';

class MockAuthRepo implements AuthRepository {
  @override
  Future<ApiResult<({String token, UserEntity user})>> login({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<({String token, UserEntity user})>> restoreSession() async =>
      throw UnimplementedError();

  @override
  Future<ApiResult<UserEntity>> getMe() async => throw UnimplementedError();

  @override
  Future<ApiResult<void>> logout() async => const ApiSuccess(null);
}

class MockStorage implements SessionStorage {
  @override
  void clear() {}
  @override
  String? getToken() => 'mock-token';
  @override
  UserEntity? getUser() => null;
  @override
  void saveToken(String token) {}
  @override
  void saveUser(UserEntity user) {}
}

void main() {
  group('Part 2: Role-Aware Shell & RBAC Navigation Verification (M2)', () {
    testWidgets('Sidebar hides modules when user lacks specific permissions', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Support user: lacks 'driver:track' and 'kpi:read'
      const supportUser = UserEntity(
        id: 'usr-support',
        name: 'Fatima Al-Kuwari',
        email: 'support.doha@demo.test',
        role: 'support',
        city: 'Doha',
        permissions: ['trip:read', 'alert:read'],
      );

      final authCubit = AuthCubit(
        authRepository: MockAuthRepo(),
        sessionStorage: MockStorage(),
      );

      authCubit.emit(Authenticated(user: supportUser, token: 'mock-tok'));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authCubit,
            child: const ShellScaffold(
              currentPath: '/trips',
              child: Text('Trips Content'),
            ),
          ),
        ),
      );

      // Trips & Alerts must be visible because permissions are granted
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);

      // Live Map & Dashboard MUST be hidden because permissions are missing
      expect(find.text('Live Map'), findsNothing);
      expect(find.text('Dashboard'), findsNothing);

      // Header shows user name, role, and city
      expect(find.text('Fatima Al-Kuwari'), findsOneWidget);
      expect(find.text('SUPPORT'), findsOneWidget);
      expect(find.text('DOHA'), findsOneWidget);
    });

    testWidgets('Sidebar shows all modules for operator with full permissions', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const dispatcherUser = UserEntity(
        id: 'usr-dispatch',
        name: 'Hamad Al-Marri',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['kpi:read', 'trip:read', 'driver:track', 'alert:read'],
      );

      final authCubit = AuthCubit(
        authRepository: MockAuthRepo(),
        sessionStorage: MockStorage(),
      );

      authCubit.emit(Authenticated(user: dispatcherUser, token: 'mock-tok'));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: authCubit,
            child: const ShellScaffold(
              currentPath: '/dashboard',
              child: Text('Dashboard Content'),
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Trips'), findsOneWidget);
      expect(find.text('Live Map'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
    });

    testWidgets('AccessDeniedScreen renders restricted message and missing permission',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AccessDeniedScreen(
            requiredPermission: 'driver:track',
            attemptedPath: '/map',
          ),
        ),
      );

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Required: driver:track'), findsOneWidget);
      expect(find.text('Return to Permitted Console'), findsOneWidget);
    });
  });
}
