import 'dart:convert';
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import 'session_storage.dart';

/// In-memory storage implementation for non-web environments (unit tests, VM).
class SessionStorageStub implements SessionStorage {
  final Map<String, String> _storage = {};

  @override
  void saveToken(String token) {
    _storage['token'] = token;
  }

  @override
  String? getToken() {
    return _storage['token'];
  }

  @override
  void saveUser(UserEntity user) {
    final model = UserModel.fromEntity(user);
    _storage['user'] = jsonEncode(model.toJson());
  }

  @override
  UserEntity? getUser() {
    final raw = _storage['user'];
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(decoded).toEntity();
    }
    return null;
  }

  @override
  void clear() {
    _storage.clear();
  }
}

SessionStorage getSessionStorageImpl() => SessionStorageStub();
