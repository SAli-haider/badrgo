import 'package:flutter_test/flutter_test.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/core/router/app_router.dart';
import 'package:badrgo_ops_console/core/storage/session_storage.dart';
import 'package:badrgo_ops_console/features/auth/domain/entities/user_entity.dart';
import 'package:badrgo_ops_console/features/auth/domain/repositories/auth_repository.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:badrgo_ops_console/features/shell/domain/entities/nav_item.dart';

class StubAuthRepo implements AuthRepository {
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

class StubStorage implements SessionStorage {
  @override
  void clear() {}
  @override
  String? getToken() => null;
  @override
  UserEntity? getUser() => null;
  @override
  void saveToken(String token) {}
  @override
  void saveUser(UserEntity user) {}
}

void main() {
  group('Part 2.1: Navigation Model & Route Guards Verification', () {
    test('NavItem.all contains 4 core modules mapped to permissions', () {
      final items = NavItem.all;
      expect(items.length, 4);

      final paths = items.map((i) => i.path).toList();
      expect(paths, containsAll(['/dashboard', '/trips', '/map', '/alerts']));

      // Verify permission gating mapping
      final mapItem = items.firstWhere((i) => i.path == '/map');
      expect(mapItem.requiredPermissions, contains('driver:track'));

      final tripsItem = items.firstWhere((i) => i.path == '/trips');
      expect(tripsItem.requiredPermissions, contains('trip:read'));
    });

    test('AppRouter initializes cleanly with AuthCubit', () {
      final cubit = AuthCubit(
        authRepository: StubAuthRepo(),
        sessionStorage: StubStorage(),
      );

      final router = AppRouter(authCubit: cubit);
      expect(router.router, isNotNull);
    });
  });
}
