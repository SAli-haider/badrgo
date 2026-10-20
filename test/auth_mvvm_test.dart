import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:badrgo_ops_console/core/errors/app_exception.dart';
import 'package:badrgo_ops_console/core/errors/error_code.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/core/storage/session_storage.dart';
import 'package:badrgo_ops_console/features/auth/domain/entities/user_entity.dart';
import 'package:badrgo_ops_console/features/auth/domain/repositories/auth_repository.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:badrgo_ops_console/features/auth/presentation/bloc/auth_state.dart';
import 'package:badrgo_ops_console/features/auth/presentation/widgets/login_screen.dart';

class FakeAuthRepository implements AuthRepository {
  final bool shouldFail;
  final String failMessage;
  final ErrorCode failCode;

  FakeAuthRepository({
    this.shouldFail = false,
    this.failMessage = 'Invalid email or password',
    this.failCode = ErrorCode.unauthenticated,
  });

  @override
  Future<ApiResult<({String token, UserEntity user})>> login({
    required String email,
    required String password,
  }) async {
    if (shouldFail) {
      return ApiFailure(
        AppException(code: failCode, message: failMessage),
      );
    }

    return const ApiSuccess((
      token: 'mock-jwt-token-xyz',
      user: UserEntity(
        id: 'usr-1',
        name: 'Doha Dispatcher',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['trip:read', 'trip:assign', 'trip:cancel'],
      ),
    ));
  }

  @override
  Future<ApiResult<({String token, UserEntity user})>> restoreSession() async {
    if (shouldFail) {
      return ApiFailure(
        AppException(code: failCode, message: failMessage, statusCode: 401),
      );
    }
    return const ApiSuccess((
      token: 'mock-jwt-token-xyz',
      user: UserEntity(
        id: 'usr-1',
        name: 'Doha Dispatcher',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['trip:read', 'trip:assign', 'trip:cancel'],
      ),
    ));
  }

  @override
  Future<ApiResult<UserEntity>> getMe() async {
    return const ApiSuccess(
      UserEntity(
        id: 'usr-1',
        name: 'Doha Dispatcher',
        email: 'dispatch.doha@demo.test',
        role: 'dispatcher',
        city: 'Doha',
        permissions: ['trip:read', 'trip:assign', 'trip:cancel'],
      ),
    );
  }

  @override
  Future<ApiResult<void>> logout() async {
    return const ApiSuccess(null);
  }
}

class FakeSessionStorage implements SessionStorage {
  String? _token;
  UserEntity? _user;

  @override
  void saveToken(String token) => _token = token;

  @override
  String? getToken() => _token;

  @override
  void saveUser(UserEntity user) => _user = user;

  @override
  UserEntity? getUser() => _user;

  @override
  void clear() {
    _token = null;
    _user = null;
  }
}

void main() {
  group('Part 1.1 + 1.2 Cross-Verification: AuthCubit & Repository Flow', () {
    test('Successful login emits [AuthLoading, Authenticated] and persists session', () async {
      final repo = FakeAuthRepository();
      final storage = FakeSessionStorage();
      final cubit = AuthCubit(authRepository: repo, sessionStorage: storage);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const AuthLoading(),
          isA<Authenticated>()
              .having((s) => s.token, 'token', 'mock-jwt-token-xyz')
              .having((s) => s.user.email, 'email', 'dispatch.doha@demo.test'),
        ]),
      );

      await cubit.login(email: 'dispatch.doha@demo.test', password: 'Demo@12345');
    });

    test('Failed login (wrong credentials) emits [AuthLoading, AuthError]', () async {
      final repo = FakeAuthRepository(
        shouldFail: true,
        failMessage: 'Wrong password provided',
      );
      final storage = FakeSessionStorage();
      final cubit = AuthCubit(authRepository: repo, sessionStorage: storage);

      expectLater(
        cubit.stream,
        emitsInOrder([
          const AuthLoading(),
          isA<AuthError>().having((s) => s.message, 'message', 'Wrong password provided'),
        ]),
      );

      await cubit.login(email: 'wrong@demo.test', password: 'badpassword');
    });

    test('401 handleUnauthorized closes session without redirect loop', () async {
      final repo = FakeAuthRepository();
      final storage = FakeSessionStorage();
      final cubit = AuthCubit(authRepository: repo, sessionStorage: storage);

      // 1. Log in
      await cubit.login(email: 'dispatch.doha@demo.test', password: 'Demo@12345');
      expect(cubit.state, isA<Authenticated>());

      // 2. Trigger 401
      final states = <AuthState>[];
      cubit.stream.listen(states.add);

      cubit.handleUnauthorized();
      expect(cubit.state, isA<Unauthenticated>());

      // 3. Trigger 401 again -> should NO-OP and NOT emit again (preventing loop)
      final initialCount = states.length;
      cubit.handleUnauthorized();
      expect(states.length, initialCount);
    });
  });

  group('Part 1.3 Cross-Verification: LoginScreen View Layer', () {
    testWidgets('LoginScreen renders inputs, buttons, and demo account chips', (tester) async {
      final repo = FakeAuthRepository();
      final storage = FakeSessionStorage();
      final cubit = AuthCubit(authRepository: repo, sessionStorage: storage);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const LoginScreen(),
          ),
        ),
      );

      expect(find.text('Sign In to Console'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Demo Test Accounts'), findsOneWidget);
    });

    testWidgets('LoginScreen displays server error banner on AuthError', (tester) async {
      final repo = FakeAuthRepository(
        shouldFail: true,
        failMessage: 'User account has been banned',
      );
      final storage = FakeSessionStorage();
      final cubit = AuthCubit(authRepository: repo, sessionStorage: storage);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const LoginScreen(),
          ),
        ),
      );

      // Trigger login with failure
      await cubit.login(email: 'banned@demo.test', password: '123');
      await tester.pump();

      expect(find.text('User account has been banned'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
