import '../../domain/entities/alert_entity.dart';

/// DTO for deserializing alert payloads from REST endpoints and SSE streams.
class AlertModel extends AlertEntity {
  const AlertModel({
    required super.id,
    required super.cityId,
    required super.type,
    required super.severity,
    required super.message,
    super.tripId,
    super.driverId,
    required super.createdAt,
    super.acknowledgedAt,
    super.acknowledgedBy,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    // 1. ID & City
    final id = (json['id'] ?? '').toString();
    final cityId = (json['cityId'] ?? json['city_id'] ?? '').toString();

    // 2. Type & Severity
    final type = AlertType.fromString(json['type']?.toString());
    final severity = AlertSeverity.fromString(json['severity']?.toString());

    // 3. Message
    final message = (json['message'] ?? 'Alert triggered').toString();

    // 4. Trip and Driver references
    final tripId = json['tripId']?.toString();
    final driverId = json['driverId']?.toString();

    // 5. Timestamps
    final rawCreatedAt = json['createdAt'] ?? json['created_at'];
    final createdAt = rawCreatedAt != null
        ? (DateTime.tryParse(rawCreatedAt.toString()) ?? DateTime.now())
        : DateTime.now();

    final rawAckAt = json['acknowledgedAt'] ?? json['acknowledged_at'];
    final acknowledgedAt = rawAckAt != null
        ? DateTime.tryParse(rawAckAt.toString())
        : null;

    final acknowledgedBy = json['acknowledgedBy']?.toString();

    return AlertModel(
      id: id,
      cityId: cityId,
      type: type,
      severity: severity,
      message: message,
      tripId: tripId,
      driverId: driverId,
      createdAt: createdAt,
      acknowledgedAt: acknowledgedAt,
      acknowledgedBy: acknowledgedBy,
    );
  }

  @override
  AlertModel copyWith({
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
    return AlertModel(
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'cityId': cityId,
        'type': type.apiValue,
        'severity': severity.apiValue,
        'message': message,
        if (tripId != null) 'tripId': tripId,
        if (driverId != null) 'driverId': driverId,
        'createdAt': createdAt.toIso8601String(),
        if (acknowledgedAt != null)
          'acknowledgedAt': acknowledgedAt!.toIso8601String(),
        if (acknowledgedBy != null) 'acknowledgedBy': acknowledgedBy,
      };
}
