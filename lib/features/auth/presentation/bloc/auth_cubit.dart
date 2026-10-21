import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/storage/session_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// ViewModel for Authentication adhering strictly to Clean MVVM with BLoC:
/// - UI state management and permission coordination.
/// - Calls domain repository interface (zero knowledge of Dio or raw HTTP).
/// - Loop-safe 401 unauthenticated handler (Requirement M1.3).
class AuthCubit extends Cubit<AuthState> {
  final AuthRepository _authRepository;
  final SessionStorage _sessionStorage;

  AuthCubit({
    required AuthRepository authRepository,
    required SessionStorage sessionStorage,
  })  : _authRepository = authRepository,
        _sessionStorage = sessionStorage,
        super(const AuthInitial());

  /// Attempts to restore session from browser localStorage.
  /// Requirement M1: "The session survives a page refresh."
  Future<void> restoreSession() async {
    final cachedToken = _sessionStorage.getToken();
    final cachedUser = _sessionStorage.getUser();

    // If no token exists, the user is simply visiting for the first time.
    // Cleanly transition to Unauthenticated without any 401 error message.
    if (cachedToken == null || cachedToken.isEmpty) {
      emit(const Unauthenticated());
      return;
    }

    // Instant optimistic render from localStorage to prevent screen flicker
    if (cachedUser != null) {
      emit(Authenticated(user: cachedUser, token: cachedToken));
    } else {
      emit(const AuthLoading());
    }

    // Call domain repository to configure transport headers and fetch fresh permissions
    final result = await _authRepository.restoreSession();
    result.when(
      success: (data) {
        emit(Authenticated(user: data.user, token: data.token));
      },
      failure: (exception) {
        if (exception.statusCode == 401) {
          handleUnauthorized();
        } else if (cachedUser == null) {
          emit(const Unauthenticated());
        }
      },
    );
  }

  /// Submits sign-in credentials.
  /// Requirement M1: "A sign-in screen that shows the server's errors (wrong password, banned user)."
  Future<void> login({
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading());
    final result = await _authRepository.login(
      email: email,
      password: password,
    );

    result.when(
      success: (data) {
        emit(Authenticated(user: data.user, token: data.token));
      },
      failure: (exception) {
        emit(AuthError(exception.message));
      },
    );
  }

  /// Revokes active session on server and cleans up local storage.
  /// Requirement M1: "Sign-out revokes the token on the server."
  Future<void> logout() async {
    emit(const AuthLoading());
    await _authRepository.logout();
    _sessionStorage.clear();
    emit(const Unauthenticated());
  }

  /// Global 401 unauthenticated handler.
  /// Requirement M1.3:
  /// "Any 401 from any transport sends the user back to sign-in,
  /// closes the realtime connections, and does not loop."
  void handleUnauthorized() {
    // If already in an unauthenticated state, NO-OP to prevent infinite redirect loops
    if (state is Unauthenticated) return;

    _sessionStorage.clear();
    emit(const Unauthenticated(
      message: 'Your session has expired or was revoked (401). Please sign in again.',
    ));
  }
}
