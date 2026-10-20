import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/phone_masker.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/trip_entity.dart';
import '../bloc/trips_cubit.dart';
import 'assign_driver_dialog.dart';
import 'cancel_trip_dialog.dart';
import 'refund_trip_dialog.dart';

/// Drawer / Sheet displaying complete nested Trip Details.
///
/// Adheres strictly to M4 requirements:
/// - "A detail view with rider, driver, pickup and dropoff, fare, refunds and the status timeline."
/// - "Actions, shown only when permitted: assign driver, cancel, refund."
/// - "viewer: no action buttons anywhere, masked phone numbers."
class TripDetailSheet extends StatelessWidget {
  final TripEntity trip;
  final VoidCallback onClose;

  const TripDetailSheet({
    super.key,
    required this.trip,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;
    final isViewer = user?.isViewer ?? false;

    return Container(
      width: 440,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header Bar
          _buildHeader(context),
          const Divider(color: AppColors.border, height: 1),

          // Scrollable Body Details
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Route Section
                _buildRouteSection(),
                const SizedBox(height: 20),

                // Parties: Rider & Driver
                _buildPartiesSection(isViewer),
                const SizedBox(height: 20),

                // Financials & Refunds
                _buildFinancialsSection(),
                const SizedBox(height: 20),

                // Status Timeline
                _buildTimelineSection(),
              ],
            ),
          ),

          // Bottom Action Bar (strictly gated by user permissions)
          if (user != null && !isViewer) ...[
            const Divider(color: AppColors.border, height: 1),
            _buildActionFooter(context, user),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    Color statusColor;
    switch (trip.status) {
      case TripStatus.completed:
        statusColor = AppColors.success;
      case TripStatus.inProgress:
        statusColor = AppColors.info;
      case TripStatus.requested:
      case TripStatus.assigned:
        statusColor = AppColors.warning;
      case TripStatus.cancelled:
        statusColor = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'Trip #${trip.id.substring(0, trip.id.length > 8 ? 8 : trip.id.length)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: OpsBadge(
                    label: trip.status.label,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildRouteSection() {
    return OpsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ROUTE DETAILS',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 10, color: AppColors.success),
                  Container(
                    width: 2,
                    height: 28,
                    color: AppColors.border,
                  ),
                  const Icon(Icons.location_on, size: 14, color: AppColors.error),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.pickup.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      trip.dropoff.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OpsBadge(
                label: '${trip.distanceKm.toStringAsFixed(1)} KM',
                color: AppColors.primary,
                showDot: false,
              ),
              const SizedBox(width: 8),
              OpsBadge(
                label: trip.cityName,
                color: AppColors.muted,
                showDot: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesSection(bool isViewer) {
    final riderPhone = PhoneMasker.mask(trip.rider.phone, shouldMask: isViewer);
    final driverPhone = trip.driver != null
        ? PhoneMasker.mask(trip.driver!.phone, shouldMask: isViewer)
        : null;

    return OpsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PARTIES',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          // Rider
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person_outline, size: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.rider.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Rider · $riderPhone',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          // Driver
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_car_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              if (trip.driver != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.driver!.name,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Driver · $driverPhone · ${trip.driver?.vehicle ?? ""}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                )
              else
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unassigned',
                        style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Waiting for driver dispatch',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialsSection() {
    final currency = trip.fare.currency;

    return OpsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FINANCIAL BREAKDOWN',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Fare', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(
                CurrencyFormatter.format(trip.fare.amount, currency),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (trip.refunded.amount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Refunded Amount', style: TextStyle(color: AppColors.error, fontSize: 13)),
                Text(
                  '- ${CurrencyFormatter.format(trip.refunded.amount, currency)}',
                  style: const TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (trip.refundReason != null) ...[
              const SizedBox(height: 4),
              Text(
                'Reason: ${trip.refundReason}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ],
          if (trip.cancelReason != null) ...[
            const SizedBox(height: 8),
            Text(
              'Cancellation Reason: ${trip.cancelReason}',
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return OpsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS TIMELINE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          if (trip.timeline.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Requested at ${DateFormatter.formatShort(trip.requestedAt)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: trip.timeline.length,
              itemBuilder: (context, index) {
                final event = trip.timeline[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.status.label,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              DateFormatter.formatShort(event.timestamp),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                            if (event.note != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                event.note!,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionFooter(BuildContext context, UserEntity user) {
    final canAssign = user.hasPermission('trip:assign') && trip.canAssign;
    final canCancel = user.hasPermission('trip:cancel') && trip.canCancel;
    final canRefund = user.hasPermission('trip:refund') && trip.canRefund;

    if (!canAssign && !canCancel && !canRefund) {
      return const SizedBox.shrink();
    }

    final tripsCubit = context.read<TripsCubit>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          if (canCancel)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Cancel Trip'),
              onPressed: () {
                CancelTripDialog.show(
                  context,
                  trip: trip,
                  onCancelled: () => tripsCubit.refreshTrip(trip.id),
                );
              },
            ),
          if (canRefund)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.currency_exchange, size: 16),
              label: const Text('Refund Trip'),
              onPressed: () {
                RefundTripDialog.show(
                  context,
                  trip: trip,
                  onRefunded: () => tripsCubit.refreshTrip(trip.id),
                );
              },
            ),
          if (canAssign)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
              label: const Text('Assign Driver'),
              onPressed: () {
                AssignDriverDialog.show(
                  context,
                  trip: trip,
                  onAssigned: () => tripsCubit.refreshTrip(trip.id),
                );
              },
            ),
        ],
      ),
    );
  }
}
