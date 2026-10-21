import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/phone_masker.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../../trips/domain/entities/trip_entity.dart';
import '../../domain/entities/driver_location_entity.dart';

/// Floating inspector card displaying selected driver's profile,
/// live telemetry, and active trip data.
class DriverDetailCard extends StatelessWidget {
  final DriverLocationEntity driver;
  final DriverEntity? driverDetail;
  final TripEntity? activeTrip;
  final bool isLoadingDetail;
  final bool isViewer;
  final VoidCallback onClose;

  const DriverDetailCard({
    super.key,
    required this.driver,
    this.driverDetail,
    this.activeTrip,
    this.isLoadingDetail = false,
    this.isViewer = false,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = AppColors.forDriverStatus(driver.status);
    final rawPhone = driverDetail?.phone.isNotEmpty == true
        ? driverDetail!.phone
        : driver.phone;
    final displayPhone =
        PhoneMasker.mask(rawPhone, shouldMask: isViewer);
    final vehicle =
        driverDetail?.vehicle ?? driver.vehicle ?? 'Standard Vehicle';

    return OpsCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Avatar, Name & Close Button
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: statusColor.withValues(alpha: 0.2),
                  child: Icon(Icons.person, color: statusColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${driver.id}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                OpsBadge(
                  label: driver.status.toUpperCase(),
                  color: statusColor,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 18, color: AppColors.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onClose,
                ),
              ],
            ),
            const Divider(color: AppColors.border, height: 24),

            // Telemetry & Profile Rows
            _buildInfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: displayPhone.isNotEmpty ? displayPhone : 'Not Provided',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.directions_car_outlined,
              label: 'Vehicle',
              value: vehicle,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              icon: Icons.gps_fixed,
              label: 'Location',
              value:
                  '${driver.latitude.toStringAsFixed(4)}, ${driver.longitude.toStringAsFixed(4)}',
            ),
            if (driver.heading != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                icon: Icons.navigation_outlined,
                label: 'Heading',
                value: '${driver.heading!.toStringAsFixed(1)}°',
              ),
            ],

            // Active Trip Section (if on trip)
            if (driver.isOnTrip || activeTrip != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.alt_route,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'Active Trip',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        if (activeTrip != null)
                          OpsBadge(
                            label: activeTrip!.status.label,
                            color:
                                AppColors.forTripStatus(activeTrip!.status.name),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isLoadingDetail)
                      const LinearProgressIndicator(minHeight: 2)
                    else if (activeTrip != null) ...[
                      Text(
                        'Rider: ${activeTrip!.rider.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Route: ${activeTrip!.pickup.name} → ${activeTrip!.dropoff.name}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('View in Trips',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () {
                            context.go('/trips');
                          },
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Trip ID: ${driver.currentTripId ?? "Assigned"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
