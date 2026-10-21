import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../../../core/widgets/ops_error_view.dart';
import '../../../../core/widgets/ops_loading_indicator.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/kpi_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/dashboard_state.dart';
import 'kpi_metric_card.dart';
import 'trips_series_chart.dart';

/// Operations Dashboard Screen adhering strictly to Clean MVVM with BLoC:
/// - Pure View layer: renders state and dispatches UI events.
/// - ZERO direct network calls or Dio/HTTP transport code.
/// - Adheres strictly to M3 requirements:
///   - KPI tiles: active trips, completed, cancellation rate, revenue,
///     drivers available and on trip, open alerts.
///   - Kept live via SSE `kpi` event without page reload.
///   - Multi-currency revenue cards rendering list per currency.
///   - Trips-over-time chart with Last 24h / Last 7 days switch.
///   - Restricted access state for users lacking `kpi:read` (e.g. support role).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final hasKpiPermission = authState is Authenticated &&
        authState.user.hasPermission('kpi:read');

    return BlocProvider(
      create: (ctx) => DashboardCubit(
        repository: ctx.read<DashboardRepository>(),
      )..loadDashboard(hasKpiPermission: hasKpiPermission),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading || state is DashboardInitial) {
          return const Center(
            child: OpsLoadingIndicator(message: 'Loading operational KPIs via GraphQL...'),
          );
        }

        if (state is DashboardRestricted) {
          return Center(
            child: OpsCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'Access Restricted',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is DashboardError) {
          final authState = context.read<AuthCubit>().state;
          final hasPerm = authState is Authenticated &&
              authState.user.hasPermission('kpi:read');

          return Center(
            child: OpsErrorView(
              message: state.message,
              onRetry: () => context.read<DashboardCubit>().loadDashboard(
                    hasKpiPermission: hasPerm,
                  ),
            ),
          );
        }

        if (state is DashboardLoaded) {
          final kpi = state.kpi;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Title, Realtime SSE Status, and Range Selector Switch
                _buildHeader(context, state),
                const SizedBox(height: 8),

                // Subtle in-place progress indicator when switching ranges
                if (state.isSwitchingRange)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(2)),
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        color: AppColors.accent,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 10.5),

                const SizedBox(height: 12),

                // KPI Metric Tiles Grid
                _buildMetricTiles(context, kpi, state.isLivePulse),
                const SizedBox(height: 24),

                // Multi-Currency Revenue Section (M3: revenue is a list per currency)
                _buildRevenueSection(context, kpi.revenue, state.isLivePulse),
                const SizedBox(height: 24),

                // Trips-Over-Time Series Chart with 24h / 7d Switch
                TripsSeriesChart(
                  series: kpi.series,
                  range: state.selectedRange,
                ),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHeader(BuildContext context, DashboardLoaded state) {
    final cubit = context.read<DashboardCubit>();
    final formattedTime = DateFormat('HH:mm:ss').format(state.lastUpdated.toLocal());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operations Dashboard',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                // Live SSE indicator badge
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Live SSE Stream active · Last update at $formattedTime',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        // Range Toggle Switch: Last 24 Hours vs Last 7 Days
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _buildRangeButton(
                context: context,
                label: 'Last 24 Hours',
                isSelected: state.selectedRange == KpiRange.last24h,
                isLoading: state.isSwitchingRange && state.selectedRange == KpiRange.last24h,
                onTap: () => cubit.switchRange(KpiRange.last24h),
              ),
              _buildRangeButton(
                context: context,
                label: 'Last 7 Days',
                isSelected: state.selectedRange == KpiRange.last7d,
                isLoading: state.isSwitchingRange && state.selectedRange == KpiRange.last7d,
                onTap: () => cubit.switchRange(KpiRange.last7d),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRangeButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    bool isLoading = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              if (isLoading) ...[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTiles(BuildContext context, KpiEntity kpi, bool isLivePulse) {
    final numberFormatter = NumberFormat('#,###');
    final cancellationPct = (kpi.trips.cancellationRate * 100).toStringAsFixed(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200
            ? 5
            : constraints.maxWidth > 800
                ? 3
                : 2;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.8,
          children: [
            // Active Trips
            KpiMetricCard(
              title: 'Active Trips',
              value: numberFormatter.format(kpi.trips.active),
              icon: Icons.directions_car,
              accentColor: AppColors.accent,
              isLivePulse: isLivePulse,
            ),
            // Completed Trips
            KpiMetricCard(
              title: 'Completed Trips',
              value: numberFormatter.format(kpi.trips.completed),
              icon: Icons.check_circle_outline,
              accentColor: AppColors.success,
              isLivePulse: isLivePulse,
            ),
            // Cancellation Rate
            KpiMetricCard(
              title: 'Cancellation Rate',
              value: '$cancellationPct%',
              subtitle: '${numberFormatter.format(kpi.trips.cancelled)} cancelled',
              icon: Icons.cancel_outlined,
              accentColor: AppColors.error,
              isLivePulse: isLivePulse,
            ),
            // Drivers Metrics
            KpiMetricCard(
              title: 'Drivers',
              value: '${kpi.drivers.available} Avail',
              subtitle: '${kpi.drivers.onTrip} on trip · ${kpi.drivers.total} total',
              icon: Icons.person_pin_circle_outlined,
              accentColor: const Color(0xFF8B5CF6),
              isLivePulse: isLivePulse,
            ),
            // Open Alerts
            KpiMetricCard(
              title: 'Open Alerts',
              value: kpi.openAlerts.toString(),
              icon: Icons.warning_amber_rounded,
              accentColor: AppColors.warning,
              badge: kpi.openAlerts > 0
                  ? const OpsBadge(label: 'Action Required', color: AppColors.warning)
                  : const OpsBadge(label: 'Normal', color: AppColors.success),
              isLivePulse: isLivePulse,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRevenueSection(
    BuildContext context,
    List<RevenueEntity> revenueList,
    bool isLivePulse,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REVENUE BREAKDOWN',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        if (revenueList.isEmpty)
          const OpsCard(
            padding: EdgeInsets.all(16),
            child: Text(
              'No revenue recorded for this period.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: revenueList.map((rev) {
              return SizedBox(
                width: 280,
                child: OpsCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            OpsBadge(
                              label: rev.currency,
                              color: AppColors.primary,
                              showDot: false,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              CurrencyFormatter.format(rev.amount, rev.currency),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.success,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
