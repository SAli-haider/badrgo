import 'package:equatable/equatable.dart';

/// Pure domain entity representing an authenticated badrgo operator.
///
/// Contains ZERO Flutter UI and ZERO network transport dependencies.
/// Adheres strictly to M2 requirements:
/// - Permissions drive access, never role names.
/// - Stores user role, city, and active permissions list.
class UserEntity extends Equatable {
  final String id;
  final String name;
  final String email;
  final String role;
  final String city;
  final List<String> permissions;
  final bool isBanned;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.city,
    required this.permissions,
    this.isBanned = false,
  });

  /// Check whether the operator possesses a specific permission key.
  /// M2: "Navigation, routes and action buttons come from the permissions in /api/me, never from role names."
  bool hasPermission(String permission) {
    return permissions.contains(permission);
  }

  /// Check whether the operator possesses at least one permission in a given list.
  bool hasAnyPermission(List<String> requiredPermissions) {
    return requiredPermissions.any((p) => permissions.contains(p));
  }

  /// Check whether operator has jurisdiction over a specific city.
  bool canAccessCity(String targetCity) {
    if (role.toLowerCase() == 'super_admin' ||
        city.toLowerCase() == 'all cities' ||
        city.toLowerCase() == 'all') {
      return true;
    }
    return city.toLowerCase() == targetCity.toLowerCase();
  }

  /// Masking indicator for viewer role.
  /// Requirement: "viewer: no action buttons anywhere, masked phone numbers, but KPIs and trips are visible."
  bool get isViewer => role.toLowerCase() == 'viewer';

  @override
  List<Object?> get props => [id, name, email, role, city, permissions, isBanned];
}
