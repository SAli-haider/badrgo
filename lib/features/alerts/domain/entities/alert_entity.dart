import 'package:equatable/equatable.dart';

/// Severity level of an operational alert.
enum AlertSeverity {
  info('info', 'Info'),
  warning('warning', 'Warning'),
  critical('critical', 'Critical');

  final String apiValue;
  final String label;

  const AlertSeverity(this.apiValue, this.label);

  static AlertSeverity fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      case 'info':
      default:
        return AlertSeverity.info;
    }
  }
}

/// Category / Type of an operational alert.
enum AlertType {
  sos('sos', 'SOS Emergency'),
  noDriverAvailable('no_driver_available', 'No Driver Available'),
  highDemand('high_demand', 'High Demand'),
  refundIssued('refund_issued', 'Refund Issued'),
  unknown('unknown', 'System Alert');

  final String apiValue;
  final String label;

  const AlertType(this.apiValue, this.label);

  static AlertType fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'sos':
        return AlertType.sos;
      case 'no_driver_available':
        return AlertType.noDriverAvailable;
      case 'high_demand':
        return AlertType.highDemand;
      case 'refund_issued':
        return AlertType.refundIssued;
      default:
        return AlertType.unknown;
    }
  }
}

/// Pure domain entity representing an operational alert.
///
/// Follows Clean Architecture:
/// - Pure Dart
/// - Zero Flutter UI dependencies
/// - Zero transport/HTTP/SSE dependencies
class AlertEntity extends Equatable {
  final String id;
  final String cityId;
  final AlertType type;
  final AlertSeverity severity;
  final String message;
  final String? tripId;
  final String? driverId;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;

  const AlertEntity({
    required this.id,
    required this.cityId,
    required this.type,
    required this.severity,
    required this.message,
    this.tripId,
    this.driverId,
    required this.createdAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
  });

  bool get isAcknowledged => acknowledgedAt != null;
  bool get isCritical =>
      severity == AlertSeverity.critical || type == AlertType.sos;
  bool get isWarning => severity == AlertSeverity.warning;
  bool get isInfo => severity == AlertSeverity.info;

  AlertEntity copyWith({
    String? id,
    String? cityId,
    AlertType? type,
    AlertSeverity? severity,
    String? message,
    String? tripId,
    String? driverId,
    DateTime? createdAt,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
  }) {
    return AlertEntity(
      id: id ?? this.id,
      cityId: cityId ?? this.cityId,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      message: message ?? this.message,
      tripId: tripId ?? this.tripId,
      driverId: driverId ?? this.driverId,
      createdAt: createdAt ?? this.createdAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        cityId,
        type,
        severity,
        message,
        tripId,
        driverId,
        createdAt,
        acknowledgedAt,
        acknowledgedBy,
      ];
}
