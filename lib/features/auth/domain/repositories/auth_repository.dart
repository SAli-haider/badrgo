import '../../../../core/network/api_result.dart';
import '../entities/user_entity.dart';

/// Pure domain repository contract for Authentication.
///
/// Adheres strictly to requirements:
/// - M1: Sign-in screen showing server errors (wrong password, banned user).
/// - M1: Session survives page refresh.
/// - M1: Sign-out revokes token on the server.
abstract class AuthRepository {
  /// Signs in against `POST /api/auth/sign-in/email`.
  Future<ApiResult<({String token, UserEntity user})>> login({
    required String email,
    required String password,
  });

  /// Restores session using persisted token, configures transport clients,
  /// and validates profile against `GET /api/me`.
  Future<ApiResult<({String token, UserEntity user})>> restoreSession();

  /// Fetches operator profile and permissions list via `GET /api/me`.
  Future<ApiResult<UserEntity>> getMe();

  /// Revokes active session token on backend via `POST /api/auth/sign-out`.
  Future<ApiResult<void>> logout();
}
