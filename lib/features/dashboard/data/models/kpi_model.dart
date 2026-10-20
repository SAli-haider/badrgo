import '../../domain/entities/kpi_entity.dart';

/// DTO for Revenue item per currency.
class RevenueModel extends RevenueEntity {
  const RevenueModel({
    required super.currency,
    required super.amount,
  });

  factory RevenueModel.fromJson(Map<String, dynamic> json) {
    return RevenueModel(
      currency: json['currency']?.toString() ?? 'QAR',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'amount': amount,
      };
}

/// DTO for Trips KPI metrics.
class TripsKpiModel extends TripsKpiEntity {
  const TripsKpiModel({
    required super.active,
    required super.completed,
    required super.cancelled,
    required super.cancellationRate,
  });

  factory TripsKpiModel.fromJson(Map<String, dynamic> json) {
    return TripsKpiModel(
      active: (json['active'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      cancellationRate: (json['cancellationRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'active': active,
        'completed': completed,
        'cancelled': cancelled,
        'cancellationRate': cancellationRate,
      };
}

/// DTO for Drivers KPI metrics.
class DriversKpiModel extends DriversKpiEntity {
  const DriversKpiModel({
    required super.available,
    required super.onTrip,
    required super.offline,
    required super.total,
  });

  factory DriversKpiModel.fromJson(Map<String, dynamic> json) {
    return DriversKpiModel(
      available: (json['available'] as num?)?.toInt() ?? 0,
      onTrip: (json['onTrip'] as num?)?.toInt() ?? 0,
      offline: (json['offline'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'available': available,
        'onTrip': onTrip,
        'offline': offline,
        'total': total,
      };
}

/// DTO for a single bucket point in the historical series.
class SeriesPointModel extends SeriesPointEntity {
  const SeriesPointModel({
    required super.bucket,
    required super.total,
    required super.completed,
    required super.cancelled,
  });

  factory SeriesPointModel.fromJson(Map<String, dynamic> json) {
    return SeriesPointModel(
      bucket: json['bucket']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'bucket': bucket,
        'total': total,
        'completed': completed,
        'cancelled': cancelled,
      };
}

/// DTO model parsing both GraphQL KPI query responses and SSE `kpi` event payloads.
class KpiModel extends KpiEntity {
  const KpiModel({
    required super.range,
    required super.generatedAt,
    required super.openAlerts,
    required super.trips,
    required super.revenue,
    required super.drivers,
    required super.series,
  });

  factory KpiModel.fromJson(Map<String, dynamic> json) {
    final rangeStr = json['range']?.toString();
    final range = KpiRange.fromString(rangeStr);

    DateTime genAt;
    try {
      final genStr = json['generatedAt']?.toString();
      genAt = genStr != null ? DateTime.parse(genStr) : DateTime.now();
    } catch (_) {
      genAt = DateTime.now();
    }

    final openAlerts = (json['openAlerts'] as num?)?.toInt() ?? 0;

    final tripsJson = json['trips'] as Map<String, dynamic>? ?? {};
    final trips = TripsKpiModel.fromJson(tripsJson);

    final rawRevenue = json['revenue'] as List? ?? [];
    final revenue = rawRevenue
        .map((r) => RevenueModel.fromJson(r as Map<String, dynamic>))
        .toList();

    final driversJson = json['drivers'] as Map<String, dynamic>? ?? {};
    final drivers = DriversKpiModel.fromJson(driversJson);

    final rawSeries = json['series'] as List? ?? [];
    final series = rawSeries
        .map((s) => SeriesPointModel.fromJson(s as Map<String, dynamic>))
        .toList();

    return KpiModel(
      range: range,
      generatedAt: genAt,
      openAlerts: openAlerts,
      trips: trips,
      revenue: revenue,
      drivers: drivers,
      series: series,
    );
  }

  KpiEntity toEntity() {
    return KpiEntity(
      range: range,
      generatedAt: generatedAt,
      openAlerts: openAlerts,
      trips: trips,
      revenue: revenue,
      drivers: drivers,
      series: series,
    );
  }
}
