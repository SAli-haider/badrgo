import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/nav_item.dart';

/// Role-aware app shell layout adhering strictly to M2 requirements:
/// - "Navigation, routes and action buttons come from the permissions in /api/me, never from role names."
/// - "The shell shows the signed-in user, their role and their city."
class ShellScaffold extends StatelessWidget {
  final Widget child;
  final String currentPath;

  const ShellScaffold({
    super.key,
    required this.child,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is! Authenticated) {
          return child;
        }

        final user = state.user;

        // Filter navigation items STRICTLY based on user.permissions, never role names!
        final permittedNavItems = NavItem.all.where((item) {
          return user.hasAnyPermission(item.requiredPermissions);
        }).toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              // 1. Sidebar Navigation
              _buildSidebar(context, user, permittedNavItems),

              // 2. Main Content Workspace
              Expanded(
                child: Column(
                  children: [
                    _buildTopHeader(context, user),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    UserEntity user,
    List<NavItem> permittedNavItems,
  ) {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.local_taxi_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'badrgo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'OPS CONSOLE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Permitted Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(10, 8, 10, 6),
                  child: Text(
                    'MODULES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                ...permittedNavItems.map((item) {
                  final isSelected = currentPath.startsWith(item.path);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () => context.go(item.path),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _getNavIcon(item.iconKey),
                              size: 18,
                              color: isSelected ? AppColors.primary : AppColors.muted,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // Footer Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: const Row(
              children: [
                OpsBadge(
                  label: 'LIVE SANDBOX',
                  color: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getNavIcon(String iconKey) {
    switch (iconKey) {
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'trips':
        return Icons.alt_route_rounded;
      case 'map':
        return Icons.map_outlined;
      case 'alerts':
        return Icons.notifications_none_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Widget _buildTopHeader(BuildContext context, UserEntity user) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Breadcrumb Title (Flexible to adapt to tablet/responsive widths)
          const Flexible(
            child: Text(
              'Operations Control Center',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Operator profile badges: User name, Role badge, City badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User Name
              Text(
                user.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),

              // Role Badge
              OpsBadge(
                label: user.role,
                color: AppColors.primary,
                showDot: false,
              ),
              const SizedBox(width: 6),

              // City Badge
              OpsBadge(
                label: user.city,
                color: AppColors.warning,
                icon: Icons.location_on_outlined,
              ),
              const SizedBox(width: 10),

              const VerticalDivider(width: 1, indent: 16, endIndent: 16),
              const SizedBox(width: 8),

              // Sign-out Button
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.muted),
                tooltip: 'Sign Out (Revoke Token)',
                onPressed: () => context.read<AuthCubit>().logout(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
