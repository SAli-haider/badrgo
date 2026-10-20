import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/phone_masker.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../domain/entities/trip_entity.dart';

/// Single interactive row card representing a Trip in the operations table.
///
/// Adheres strictly to M4 requirements:
/// - "Live updates from SSE trip.created and trip.updated without a full reload.
///   Mark new and changed rows visibly."
/// - "viewer: masked phone numbers"
class TripRowCard extends StatelessWidget {
  final TripEntity trip;
  final bool isSelected;
  final bool isRecentlyCreated;
  final bool isRecentlyUpdated;
  final bool isViewer;
  final VoidCallback onTap;

  const TripRowCard({
    super.key,
    required this.trip,
    this.isSelected = false,
    this.isRecentlyCreated = false,
    this.isRecentlyUpdated = false,
    this.isViewer = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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

    Color borderColor = AppColors.border;
    if (isSelected) {
      borderColor = AppColors.primary;
    } else if (isRecentlyCreated) {
      borderColor = AppColors.success;
    } else if (isRecentlyUpdated) {
      borderColor = AppColors.primary;
    }

    final riderPhone = PhoneMasker.mask(trip.rider.phone, shouldMask: isViewer);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: borderColor,
            width: (isSelected || isRecentlyCreated || isRecentlyUpdated) ? 2 : 1,
          ),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : isRecentlyCreated
                  ? AppColors.success.withValues(alpha: 0.06)
                  : isRecentlyUpdated
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.surface,
        ),
        child: OpsCard(
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Column 1: ID & Time
              SizedBox(
                width: 140,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#${trip.id.substring(0, trip.id.length > 8 ? 8 : trip.id.length)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (isRecentlyCreated) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ] else if (isRecentlyUpdated) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'UPDATED',
                              style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.formatRelative(trip.requestedAt),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Column 2: Status Badge
              SizedBox(
                width: 130,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: OpsBadge(
                    label: trip.status.label,
                    color: statusColor,
                  ),
                ),
              ),

              // Column 3: Rider
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.rider.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      riderPhone,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Column 4: Driver
              Expanded(
                flex: 2,
                child: trip.driver != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trip.driver!.name,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            trip.driver?.vehicle ?? trip.driver!.phone,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      )
                    : const Text(
                        'Unassigned',
                        style: TextStyle(color: AppColors.warning, fontSize: 12, fontStyle: FontStyle.italic),
                      ),
              ),

              // Column 5: Route (Pickup -> Dropoff)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle, size: 8, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            trip.pickup.name,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 10, color: AppColors.error),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            trip.dropoff.name,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Column 6: Fare & Distance
              SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(trip.fare.amount, trip.fare.currency),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trip.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
