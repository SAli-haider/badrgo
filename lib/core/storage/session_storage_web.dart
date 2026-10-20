import 'dart:convert';
import 'package:web/web.dart' as web;
import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import 'session_storage.dart';

/// Browser localStorage implementation for Flutter Web runtime.
class SessionStorageWeb implements SessionStorage {
  static const String _tokenKey = 'badrgo_ops_token';
  static const String _userKey = 'badrgo_ops_user';

  @override
  void saveToken(String token) {
    try {
      web.window.localStorage.setItem(_tokenKey, token);
    } catch (_) {}
  }

  @override
  String? getToken() {
    try {
      final token = web.window.localStorage.getItem(_tokenKey);
      return (token != null && token.isNotEmpty) ? token : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void saveUser(UserEntity user) {
    try {
      final model = UserModel.fromEntity(user);
      web.window.localStorage.setItem(_userKey, jsonEncode(model.toJson()));
    } catch (_) {}
  }

  @override
  UserEntity? getUser() {
    try {
      final raw = web.window.localStorage.getItem(_userKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return UserModel.fromJson(decoded).toEntity();
      }
    } catch (_) {}
    return null;
  }

  @override
  void clear() {
    try {
      web.window.localStorage.removeItem(_tokenKey);
      web.window.localStorage.removeItem(_userKey);
    } catch (_) {}
  }
}

SessionStorage getSessionStorageImpl() => SessionStorageWeb();
