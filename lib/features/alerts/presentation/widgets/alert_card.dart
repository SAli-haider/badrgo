import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../domain/entities/alert_entity.dart';

/// Card component rendering an individual operational alert.
class AlertCard extends StatelessWidget {
  final AlertEntity alert;
  final bool canAcknowledge;
  final bool isAcknowledging;
  final VoidCallback onAcknowledge;

  const AlertCard({
    super.key,
    required this.alert,
    required this.canAcknowledge,
    this.isAcknowledging = false,
    required this.onAcknowledge,
  });

  Color _severityColor() {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return AppColors.error;
      case AlertSeverity.warning:
        return AppColors.warning;
      case AlertSeverity.info:
        return AppColors.info;
    }
  }

  IconData _severityIcon() {
    switch (alert.severity) {
      case AlertSeverity.critical:
        return Icons.emergency;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severityColor = _severityColor();

    return OpsCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: severityColor,
              width: 5,
            ),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Severity Badge, Type Label, Relative Time & Ack Status
            Row(
              children: [
                Icon(_severityIcon(), size: 18, color: severityColor),
                const SizedBox(width: 8),
                Text(
                  alert.type.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: alert.isCritical ? AppColors.error : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                OpsBadge(
                  label: alert.severity.label.toUpperCase(),
                  color: severityColor,
                ),
                const Spacer(),
                Text(
                  DateFormatter.formatRelative(alert.createdAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: Alert Message
            Text(
              alert.message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),

            // Row 3: Metadata chips (Trip ID, Driver ID, City) & Acknowledge Action
            Row(
              children: [
                // City Badge
                OpsBadge(
                  label: alert.cityId.toUpperCase(),
                  color: AppColors.textSecondary,
                ),
                if (alert.tripId != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.go('/trips'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_long, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Trip: ${alert.tripId}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (alert.driverId != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => context.go('/map'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.person, size: 12, color: AppColors.info),
                          const SizedBox(width: 4),
                          Text(
                            'Driver: ${alert.driverId}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.info,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const Spacer(),

                // Acknowledged Status vs Acknowledge Button
                if (alert.isAcknowledged)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Acknowledged ${alert.acknowledgedBy != null ? "by ${alert.acknowledgedBy}" : ""}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                else if (canAcknowledge)
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
                    label: const Text('Acknowledge', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alert.isCritical ? AppColors.error : AppColors.surfaceLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: isAcknowledging ? null : onAcknowledge,
                  )
                else
                  const OpsBadge(
                    label: 'Pending Acknowledgment',
                    color: AppColors.muted,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
