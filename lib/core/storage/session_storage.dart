import '../../features/auth/domain/entities/user_entity.dart';
import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart';

/// Abstract contract for session storage.
///
/// Automatically resolves to:
/// - `SessionStorageWeb` (browser localStorage via package:web) in Web environment.
/// - `SessionStorageStub` (in-memory storage) in VM & unit test environment.
///
/// Adheres to requirement M1:
/// "The session survives a page refresh. Sign-out revokes the token on the server."
abstract class SessionStorage {
  void saveToken(String token);
  String? getToken();
  void saveUser(UserEntity user);
  UserEntity? getUser();
  void clear();

  factory SessionStorage() => getSessionStorageImpl();
}
