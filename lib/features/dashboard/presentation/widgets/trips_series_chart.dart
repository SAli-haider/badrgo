import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../domain/entities/kpi_entity.dart';

/// Interactive Trips-over-time chart powered by fl_chart.
///
/// Adheres strictly to M3 requirements:
/// - "A trips-over-time chart (series) with a Last 24h / Last 7 days switch."
/// - Multi-line visualization for Total, Completed, and Cancelled trips.
class TripsSeriesChart extends StatelessWidget {
  final List<SeriesPointEntity> series;
  final KpiRange range;

  const TripsSeriesChart({
    super.key,
    required this.series,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const OpsCard(
        child: SizedBox(
          height: 280,
          child: Center(
            child: Text(
              'No series data available for the selected period.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    final totalSpots = <FlSpot>[];
    final completedSpots = <FlSpot>[];
    final cancelledSpots = <FlSpot>[];

    double maxY = 10;

    for (int i = 0; i < series.length; i++) {
      final point = series[i];
      final x = i.toDouble();
      totalSpots.add(FlSpot(x, point.total.toDouble()));
      completedSpots.add(FlSpot(x, point.completed.toDouble()));
      cancelledSpots.add(FlSpot(x, point.cancelled.toDouble()));

      if (point.total > maxY) {
        maxY = point.total.toDouble();
      }
    }

    // Add 15% headroom to Y axis
    maxY = (maxY * 1.15).ceilToDouble();

    return OpsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trips Volume Over Time',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    range == KpiRange.last24h
                        ? 'Hourly breakdown (Last 24 Hours)'
                        : 'Daily volume trends (Last 7 Days)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              // Chart Legends
              Row(
                children: [
                  _buildLegend(color: AppColors.accent, label: 'Total'),
                  const SizedBox(width: 14),
                  _buildLegend(color: AppColors.success, label: 'Completed'),
                  const SizedBox(width: 14),
                  _buildLegend(color: AppColors.error, label: 'Cancelled'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 5 ? (maxY / 5).roundToDouble() : 1,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: series.length > 8 ? (series.length / 6).floorToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= series.length) {
                          return const SizedBox.shrink();
                        }
                        final bucketStr = series[index].bucket;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            _formatBucket(bucketStr, range),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Total line
                  LineChartBarData(
                    spots: totalSpots,
                    isCurved: true,
                    color: AppColors.accent,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.accent.withValues(alpha: 0.12),
                    ),
                  ),
                  // Completed line
                  LineChartBarData(
                    spots: completedSpots,
                    isCurved: true,
                    color: AppColors.success,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  // Cancelled line
                  LineChartBarData(
                    spots: cancelledSpots,
                    isCurved: true,
                    color: AppColors.error,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        final point = (index >= 0 && index < series.length)
                            ? series[index]
                            : null;
                        final label = spot.barIndex == 0
                            ? 'Total: ${spot.y.toInt()}'
                            : spot.barIndex == 1
                                ? 'Completed: ${spot.y.toInt()}'
                                : 'Cancelled: ${spot.y.toInt()}';

                        final color = spot.barIndex == 0
                            ? AppColors.accent
                            : spot.barIndex == 1
                                ? AppColors.success
                                : AppColors.error;

                        return LineTooltipItem(
                          '${point != null ? _formatBucket(point.bucket, range) : ""}\n$label',
                          TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatBucket(String bucket, KpiRange range) {
    try {
      final dt = DateTime.parse(bucket).toLocal();
      if (range == KpiRange.last24h) {
        return DateFormat('HH:mm').format(dt);
      } else {
        return DateFormat('MMM d').format(dt);
      }
    } catch (_) {
      return bucket.length > 5 ? bucket.substring(bucket.length - 5) : bucket;
    }
  }
}
