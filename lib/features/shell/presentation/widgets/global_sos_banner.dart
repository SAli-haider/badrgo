import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../alerts/presentation/bloc/global_sos_cubit.dart';
import '../../../alerts/presentation/bloc/global_sos_state.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

/// App-wide prominent SOS Emergency Banner displayed across all screens
/// whenever an unacknowledged critical alert exists.
///
/// Adheres strictly to M6.2 requirement:
/// "`critical` alerts (SOS) must be noticed wherever the user is in the app."
class GlobalSosBanner extends StatelessWidget {
  const GlobalSosBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GlobalSosCubit?>();
    if (cubit == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<GlobalSosCubit, GlobalSosState>(
      bloc: cubit,
      builder: (context, state) {
        if (!state.hasActiveSos) {
          return const SizedBox.shrink();
        }

        final alert = state.latestSos!;
        final authState = context.read<AuthCubit>().state;
        final canAcknowledge = authState is Authenticated &&
            authState.user.hasPermission('alert:acknowledge');
        final isAcknowledging = state.acknowledgingIds.contains(alert.id);
        final cubit = context.read<GlobalSosCubit>();

        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF7F1D1D), // Dark Red-900
                  Color(0xFF991B1B), // Red-800
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.error, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final iconWidget = Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency,
                    color: Colors.white,
                    size: 20,
                  ),
                );

                final textWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'CRITICAL SOS EMERGENCY',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            alert.cityId.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      alert.message,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

                final actionsWidget = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Carousel controls if multiple active SOS alerts exist
                    if (state.visibleAlerts.length > 1) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: cubit.prevAlert,
                              borderRadius: BorderRadius.circular(4),
                              child: const Icon(
                                Icons.chevron_left,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${state.currentIndex + 1}/${state.visibleAlerts.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: cubit.nextAlert,
                              borderRadius: BorderRadius.circular(4),
                              child: const Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    if (alert.tripId != null) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('View Trip',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => context.go('/trips'),
                      ),
                      const SizedBox(width: 8),
                    ],

                    TextButton.icon(
                      icon: const Icon(Icons.list_alt, size: 14),
                      label: const Text('All Alerts',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                      ),
                      onPressed: () => context.go('/alerts'),
                    ),
                    const SizedBox(width: 8),

                    if (canAcknowledge) ...[
                      ElevatedButton.icon(
                        icon: isAcknowledging
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check, size: 14),
                        label: const Text('Acknowledge',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                        onPressed: isAcknowledging
                            ? null
                            : () => cubit.acknowledgeSos(alert.id),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Close / Dismiss button: closes the banner immediately
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: Colors.white70),
                      tooltip: 'Dismiss SOS Banner',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => cubit.dismissBanner(),
                    ),
                  ],
                );

                if (constraints.maxWidth < 750) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          iconWidget,
                          const SizedBox(width: 12),
                          Expanded(child: textWidget),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: actionsWidget,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 14),
                    Expanded(child: textWidget),
                    const SizedBox(width: 16),
                    actionsWidget,
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
