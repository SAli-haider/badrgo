import 'package:equatable/equatable.dart';

/// Available KPI time ranges supported by backend GraphQL API.
enum KpiRange {
  last24h('LAST_24H', 'Last 24 Hours'),
  last7d('LAST_7D', 'Last 7 Days');

  final String apiValue;
  final String label;

  const KpiRange(this.apiValue, this.label);

  static KpiRange fromString(String? value) {
    if (value == 'LAST_7D') return KpiRange.last7d;
    return KpiRange.last24h;
  }
}

/// Pure domain entity representing revenue breakdown per currency.
/// Adheres to M3 requirement:
/// "`revenue` is a list with one entry per currency. Render it correctly."
class RevenueEntity extends Equatable {
  final String currency;
  final double amount;

  const RevenueEntity({
    required this.currency,
    required this.amount,
  });

  @override
  List<Object?> get props => [currency, amount];
}

/// Pure domain entity for Trips KPI metrics.
class TripsKpiEntity extends Equatable {
  final int active;
  final int completed;
  final int cancelled;
  final double cancellationRate;

  const TripsKpiEntity({
    required this.active,
    required this.completed,
    required this.cancelled,
    required this.cancellationRate,
  });

  @override
  List<Object?> get props => [active, completed, cancelled, cancellationRate];
}

/// Pure domain entity for Driver availability and status metrics.
class DriversKpiEntity extends Equatable {
  final int available;
  final int onTrip;
  final int offline;
  final int total;

  const DriversKpiEntity({
    required this.available,
    required this.onTrip,
    required this.offline,
    required this.total,
  });

  @override
  List<Object?> get props => [available, onTrip, offline, total];
}

/// Pure domain entity for a single time-series bucket point.
class SeriesPointEntity extends Equatable {
  final String bucket;
  final int total;
  final int completed;
  final int cancelled;

  const SeriesPointEntity({
    required this.bucket,
    required this.total,
    required this.completed,
    required this.cancelled,
  });

  @override
  List<Object?> get props => [bucket, total, completed, cancelled];
}

/// Pure domain entity for comprehensive operational KPIs.
/// Contains ZERO Flutter UI imports and ZERO network transport code.
class KpiEntity extends Equatable {
  final KpiRange range;
  final DateTime generatedAt;
  final int openAlerts;
  final TripsKpiEntity trips;
  final List<RevenueEntity> revenue;
  final DriversKpiEntity drivers;
  final List<SeriesPointEntity> series;

  const KpiEntity({
    required this.range,
    required this.generatedAt,
    required this.openAlerts,
    required this.trips,
    required this.revenue,
    required this.drivers,
    required this.series,
  });

  KpiEntity copyWith({
    KpiRange? range,
    DateTime? generatedAt,
    int? openAlerts,
    TripsKpiEntity? trips,
    List<RevenueEntity>? revenue,
    DriversKpiEntity? drivers,
    List<SeriesPointEntity>? series,
  }) {
    return KpiEntity(
      range: range ?? this.range,
      generatedAt: generatedAt ?? this.generatedAt,
      openAlerts: openAlerts ?? this.openAlerts,
      trips: trips ?? this.trips,
      revenue: revenue ?? this.revenue,
      drivers: drivers ?? this.drivers,
      series: series ?? this.series,
    );
  }

  @override
  List<Object?> get props => [
        range,
        generatedAt,
        openAlerts,
        trips,
        revenue,
        drivers,
        series,
      ];
}
