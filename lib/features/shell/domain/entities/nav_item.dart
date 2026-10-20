/// Navigation item entity mapping a module to its route and required permission.
/// Pure Dart entity with ZERO Flutter UI dependencies.
///
/// Adheres strictly to M2 requirement:
/// "Navigation, routes and action buttons come from the permissions in /api/me, never from role names."
class NavItem {
  final String title;
  final String path;
  final List<String> requiredPermissions;
  final String iconKey;

  const NavItem({
    required this.title,
    required this.path,
    required this.requiredPermissions,
    required this.iconKey,
  });

  /// The standard navigation modules of badrgo Ops Console
  static const List<NavItem> all = [
    NavItem(
      title: 'Dashboard',
      path: '/dashboard',
      requiredPermissions: ['kpi:read', 'city:read'],
      iconKey: 'dashboard',
    ),
    NavItem(
      title: 'Trips',
      path: '/trips',
      requiredPermissions: ['trip:read'],
      iconKey: 'trips',
    ),
    NavItem(
      title: 'Live Map',
      path: '/map',
      requiredPermissions: ['driver:track'],
      iconKey: 'map',
    ),
    NavItem(
      title: 'Alerts',
      path: '/alerts',
      requiredPermissions: ['alert:read'],
      iconKey: 'alerts',
    ),
  ];
}
