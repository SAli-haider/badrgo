import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../../../core/widgets/ops_error_view.dart';
import '../../../../core/widgets/ops_loading_indicator.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../bloc/alerts_cubit.dart';
import '../bloc/alerts_state.dart';
import 'alert_card.dart';

/// Operational Alerts Feed Screen (M6).
///
/// Follows Clean MVVM with BLoC:
/// - Real-time SSE listener for alert.created and alert.acknowledged
/// - Critical SOS alerts highlight with high visibility
/// - Acknowledge action permitted strictly by `alert:acknowledge` (hidden for `viewer`)
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;

    return BlocProvider(
      create: (ctx) => AlertsCubit(
        repository: ctx.read<AlertsRepository>(),
        currentUser: user ??
            const UserEntity(
              id: '',
              name: 'Operator',
              email: '',
              role: 'unknown',
              city: 'Doha',
              permissions: [],
            ),
      )..loadAlerts(),
      child: const _AlertsView(),
    );
  }
}

class _AlertsView extends StatelessWidget {
  const _AlertsView();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final canAcknowledge = authState is Authenticated &&
        authState.user.hasPermission('alert:acknowledge');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocBuilder<AlertsCubit, AlertsState>(
        builder: (context, state) {
          if (state is AlertsLoading || state is AlertsInitial) {
            return const Center(child: OpsLoadingIndicator());
          }

          if (state is AlertsError) {
            return Center(
              child: OpsErrorView(
                message: state.message,
                onRetry: () => context.read<AlertsCubit>().loadAlerts(),
              ),
            );
          }

          if (state is AlertsLoaded) {
            return _buildAlertsContent(context, state, canAcknowledge);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAlertsContent(
    BuildContext context,
    AlertsLoaded state,
    bool canAcknowledge,
  ) {
    final cubit = context.read<AlertsCubit>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & SSE Live Badge
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operational Alerts',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time fleet events, emergencies, and anomalies from SSE',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // SSE Live Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: AppColors.success),
                    SizedBox(width: 6),
                    Text(
                      'Live SSE Feed',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filter Toolbar Card
          OpsCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildFilterChip(
                  label: 'All (${state.totalCount})',
                  isSelected: state.severityFilter == 'all',
                  color: AppColors.primary,
                  onTap: () => cubit.setSeverityFilter('all'),
                ),
                _buildFilterChip(
                  label: 'Critical SOS (${state.criticalCount})',
                  isSelected: state.severityFilter == 'critical',
                  color: AppColors.error,
                  onTap: () => cubit.setSeverityFilter('critical'),
                ),
                _buildFilterChip(
                  label: 'Warnings (${state.warningCount})',
                  isSelected: state.severityFilter == 'warning',
                  color: AppColors.warning,
                  onTap: () => cubit.setSeverityFilter('warning'),
                ),
                _buildFilterChip(
                  label: 'Info (${state.infoCount})',
                  isSelected: state.severityFilter == 'info',
                  color: AppColors.info,
                  onTap: () => cubit.setSeverityFilter('info'),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1,
                  height: 20,
                  color: AppColors.border,
                ),
                const SizedBox(width: 8),
                // Status Filter
                _buildFilterChip(
                  label: 'Unresolved (${state.unacknowledgedCount})',
                  isSelected: state.statusFilter == 'unacknowledged',
                  color: AppColors.warning,
                  onTap: () {
                    cubit.setStatusFilter(
                      state.statusFilter == 'unacknowledged' ? 'all' : 'unacknowledged',
                    );
                  },
                ),
                _buildFilterChip(
                  label: 'Acknowledged',
                  isSelected: state.statusFilter == 'acknowledged',
                  color: AppColors.success,
                  onTap: () {
                    cubit.setStatusFilter(
                      state.statusFilter == 'acknowledged' ? 'all' : 'acknowledged',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Alerts List
          if (state.filteredAlerts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: OpsCard(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_off_outlined,
                        size: 44,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No alerts found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No operational alerts matching the selected filter criteria.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.filteredAlerts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final alert = state.filteredAlerts[index];
                return AlertCard(
                  alert: alert,
                  canAcknowledge: canAcknowledge,
                  isAcknowledging: state.acknowledgingIds.contains(alert.id),
                  onAcknowledge: () => cubit.acknowledgeAlert(alert.id),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
