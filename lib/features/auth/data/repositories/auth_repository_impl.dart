import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_code.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/graphql_client.dart';
import '../../../../core/network/rest_client.dart';
import '../../../../core/storage/session_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

/// Data layer implementation of AuthRepository.
///
/// Adheres to:
/// - M1: Sign-in screen showing server errors.
/// - M1: Session survives page refresh.
/// - M1: Sign-out revokes token on the server.
class AuthRepositoryImpl implements AuthRepository {
  final RestClient _restClient;
  final GraphQLClient _graphQLClient;
  final SessionStorage _sessionStorage;

  AuthRepositoryImpl({
    required RestClient restClient,
    required GraphQLClient graphQLClient,
    required SessionStorage sessionStorage,
  })  : _restClient = restClient,
        _graphQLClient = graphQLClient,
        _sessionStorage = sessionStorage {
    // If a token was already saved in localStorage from previous session,
    // immediately initialize clients with it upon startup
    final savedToken = _sessionStorage.getToken();
    if (savedToken != null && savedToken.isNotEmpty) {
      _restClient.updateToken(savedToken);
      _graphQLClient.updateToken(savedToken);
    }
  }

  @override
  Future<ApiResult<({String token, UserEntity user})>> login({
    required String email,
    required String password,
  }) async {
    final result = await _restClient.post<Map<String, dynamic>>(
      AppConfig.loginEndpoint,
      body: {
        'email': email.trim(),
        'password': password,
      },
      fromJson: (json) => json as Map<String, dynamic>,
    );

    return result.when(
      success: (data) async {
        final token = data['token']?.toString() ?? '';

        // Immediately configure client authorization with new token
        _restClient.updateToken(token);
        _graphQLClient.updateToken(token);

        // Fetch complete profile with permissions matrix from /api/me
        final meResult = await getMe();
        final user = meResult.dataOrNull ??
            (data['user'] is Map<String, dynamic>
                ? UserModel.fromJson(data['user'] as Map<String, dynamic>).toEntity()
                : UserEntity(
                    id: 'me',
                    name: email,
                    email: email,
                    role: 'viewer',
                    city: 'Doha',
                    permissions: const [],
                  ));

        // Persist session across page reloads
        _sessionStorage.saveToken(token);
        _sessionStorage.saveUser(user);

        return ApiSuccess((token: token, user: user));
      },
      failure: (exception) => ApiFailure(exception),
    );
  }

  @override
  Future<ApiResult<({String token, UserEntity user})>> restoreSession() async {
    final token = _sessionStorage.getToken();
    final cachedUser = _sessionStorage.getUser();

    if (token == null || token.isEmpty) {
      return const ApiFailure(
        AppException(
          code: ErrorCode.unauthenticated,
          message: 'No stored session found',
          statusCode: 401,
        ),
      );
    }

    // Set token on transport clients BEFORE calling /api/me
    _restClient.updateToken(token);
    _graphQLClient.updateToken(token);

    final meResult = await getMe();
    return meResult.when(
      success: (user) {
        _sessionStorage.saveUser(user);
        return ApiSuccess((token: token, user: user));
      },
      failure: (exception) {
        if (exception.statusCode == 401) {
          _sessionStorage.clear();
          _restClient.updateToken(null);
          _graphQLClient.updateToken(null);
        } else if (cachedUser != null) {
          // If offline / transient network error, use cached profile
          return ApiSuccess((token: token, user: cachedUser));
        }
        return ApiFailure(exception);
      },
    );
  }

  @override
  Future<ApiResult<UserEntity>> getMe() async {
    final result = await _restClient.get<Map<String, dynamic>>(
      AppConfig.meEndpoint,
      fromJson: (json) => json as Map<String, dynamic>,
    );

    return result.when(
      success: (data) {
        final user = UserModel.fromJson(data).toEntity();
        _sessionStorage.saveUser(user);
        return ApiSuccess(user);
      },
      failure: (exception) => ApiFailure(exception),
    );
  }

  @override
  Future<ApiResult<void>> logout() async {
    // Attempt backend token revocation on server
    try {
      await _restClient.post(AppConfig.logoutEndpoint);
    } catch (_) {}

    // Clean up local session and reset client authorization headers
    _sessionStorage.clear();
    _restClient.updateToken(null);
    _graphQLClient.updateToken(null);

    return const ApiSuccess(null);
  }
}
