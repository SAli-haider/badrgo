import '../../domain/entities/user_entity.dart';

/// Data Transfer Object (DTO) for User/Operator.
///
/// Maps JSON from both:
/// 1. `POST /api/auth/sign-in/email`:
///    `{ token, user: { id, name, email, role, cityId, banned } }`
/// 2. `GET /api/me`:
///    `{ user: { id, name, email }, role: "...", city: { name: "Doha" }, permissions: { "trip": ["read"] } }`
class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String city;
  final List<String> permissions;
  final bool isBanned;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.city,
    required this.permissions,
    this.isBanned = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // If nested user object exists (as in /api/me)
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    final id = userMap['id']?.toString() ?? json['id']?.toString() ?? '';
    final email = userMap['email']?.toString() ?? json['email']?.toString() ?? '';
    final name = userMap['name']?.toString() ??
        json['name']?.toString() ??
        (email.isNotEmpty ? email : 'Operator');
    final role = json['role']?.toString() ?? userMap['role']?.toString() ?? 'viewer';

    // City parsing (can be object { name: "Doha" }, string "Doha", or cityId)
    // For super_admin, city is null in backend and represents "All cities".
    String city = role.toLowerCase() == 'super_admin' ? 'All cities' : 'Doha';
    final cityRaw = json['city'] ?? userMap['city'];
    if (cityRaw is Map<String, dynamic>) {
      city = cityRaw['name']?.toString() ?? city;
    } else if (cityRaw is String && cityRaw.isNotEmpty) {
      city = cityRaw;
    } else if (userMap['cityId'] != null) {
      final cityId = userMap['cityId'].toString();
      if (cityId.contains('rayyan')) {
        city = 'Al Rayyan';
      } else if (cityId.contains('wakrah')) {
        city = 'Al Wakrah';
      } else if (cityId.contains('doh')) {
        city = 'Doha';
      } else {
        city = cityId;
      }
    }

    // Permissions parsing: can be List<String> or Map<String, List<dynamic>>
    // e.g. { "trip": ["read", "assign"] } -> ["trip:read", "trip:assign"]
    final List<String> perms = [];
    final permissionsRaw = json['permissions'] ?? userMap['permissions'];

    if (permissionsRaw is Map<String, dynamic>) {
      permissionsRaw.forEach((category, actions) {
        if (actions is List) {
          for (final action in actions) {
            perms.add('$category:${action.toString()}');
          }
        }
      });
    } else if (permissionsRaw is List) {
      perms.addAll(permissionsRaw.map((e) => e.toString()));
    }

    final isBanned = json['isBanned'] == true ||
        json['banned'] == true ||
        userMap['banned'] == true ||
        userMap['isBanned'] == true;

    return UserModel(
      id: id,
      name: name,
      email: email,
      role: role,
      city: city,
      permissions: perms,
      isBanned: isBanned,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'city': city,
      'permissions': permissions,
      'isBanned': isBanned,
    };
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      name: name,
      email: email,
      role: role,
      city: city,
      permissions: permissions,
      isBanned: isBanned,
    );
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      role: entity.role,
      city: entity.city,
      permissions: entity.permissions,
      isBanned: entity.isBanned,
    );
  }
}
