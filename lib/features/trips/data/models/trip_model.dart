import '../../domain/entities/trip_entity.dart';

/// DTO for Money amounts.
class MoneyModel extends MoneyEntity {
  const MoneyModel({
    required super.currency,
    required super.amount,
  });

  factory MoneyModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MoneyModel(currency: 'QAR', amount: 0.0);
    }
    return MoneyModel(
      currency: json['currency']?.toString() ?? 'QAR',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'currency': currency,
        'amount': amount,
      };
}

/// DTO for Places.
class PlaceModel extends PlaceEntity {
  const PlaceModel({
    required super.name,
    super.lat,
    super.lng,
  });

  factory PlaceModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PlaceModel(name: 'Unknown Location');
    }
    return PlaceModel(
      name: json['address']?.toString() ?? json['name']?.toString() ?? 'Unknown Location',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'lat': lat,
        'lng': lng,
      };
}

/// DTO for Rider profiles.
class RiderModel extends RiderEntity {
  const RiderModel({
    required super.id,
    required super.name,
    required super.phone,
  });

  factory RiderModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const RiderModel(id: '', name: 'Unknown Rider', phone: '');
    }
    return RiderModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Rider',
      phone: json['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
      };
}

/// DTO for Driver profiles.
class DriverModel extends DriverEntity {
  const DriverModel({
    required super.id,
    required super.name,
    required super.phone,
    super.vehicle,
    super.status,
  });

  static String? _parseVehicle(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map) {
      final make = v['make']?.toString() ?? '';
      final model = v['model']?.toString() ?? '';
      final plate = v['plate']?.toString() ?? '';
      final color = v['color']?.toString() ?? '';
      final name = [make, model].where((s) => s.isNotEmpty).join(' ');
      final parts = [name, color, plate].where((s) => s.isNotEmpty).toList();
      return parts.isNotEmpty ? parts.join(' · ') : null;
    }
    return v.toString();
  }

  factory DriverModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const DriverModel(id: '', name: '', phone: '');
    }
    return DriverModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      vehicle: _parseVehicle(json['vehicle']),
      status: json['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        if (vehicle != null) 'vehicle': vehicle,
        if (status != null) 'status': status,
      };
}

/// DTO for Trip Timeline events.
class TripTimelineModel extends TripTimelineEntity {
  const TripTimelineModel({
    required super.status,
    required super.timestamp,
    super.note,
  });

  factory TripTimelineModel.fromJson(Map<String, dynamic> json) {
    DateTime ts;
    try {
      final str = json['timestamp']?.toString();
      ts = str != null ? DateTime.parse(str) : DateTime.now();
    } catch (_) {
      ts = DateTime.now();
    }

    return TripTimelineModel(
      status: TripStatus.fromString(json['status']?.toString()),
      timestamp: ts,
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status.apiValue,
        'timestamp': timestamp.toIso8601String(),
        if (note != null) 'note': note,
      };
}

/// DTO parsing Trip data across GraphQL, REST, and SSE events.
class TripModel extends TripEntity {
  const TripModel({
    required super.id,
    required super.status,
    required super.cityId,
    required super.cityName,
    required super.rider,
    super.driver,
    required super.pickup,
    required super.dropoff,
    required super.distanceKm,
    required super.fare,
    required super.refunded,
    super.refundReason,
    super.cancelReason,
    super.cancelledBy,
    required super.requestedAt,
    super.assignedAt,
    super.startedAt,
    super.completedAt,
    super.cancelledAt,
    super.timeline,
  });

  factory TripModel.fromJson(Map<String, dynamic> rawJson) {
    // Unpack event wrapper envelopes like { "trip": ... }, { "data": ... }, { "payload": ... }
    final json = (rawJson['trip'] is Map<String, dynamic>)
        ? rawJson['trip'] as Map<String, dynamic>
        : (rawJson['data'] is Map<String, dynamic>)
            ? rawJson['data'] as Map<String, dynamic>
            : (rawJson['payload'] is Map<String, dynamic>)
                ? rawJson['payload'] as Map<String, dynamic>
                : rawJson;

    final tripId = json['id']?.toString() ??
        json['tripId']?.toString() ??
        json['_id']?.toString() ??
        rawJson['id']?.toString() ??
        rawJson['tripId']?.toString() ??
        '';

    DateTime parseDate(dynamic val, {DateTime? fallback}) {
      if (val == null) return fallback ?? DateTime.now();
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return fallback ?? DateTime.now();
      }
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    final cityJson = json['city'] ?? rawJson['city'];
    String cId = '';
    String cName = 'Doha';
    if (cityJson is Map<String, dynamic>) {
      cId = cityJson['id']?.toString() ?? '';
      cName = cityJson['name']?.toString() ?? 'Doha';
    } else if (json['cityId'] != null || rawJson['cityId'] != null) {
      cId = (json['cityId'] ?? rawJson['cityId']).toString();
      if (cId.contains('rayyan')) {
        cName = 'Al Rayyan';
      } else if (cId.contains('wakrah')) {
        cName = 'Al Wakrah';
      } else {
        cName = 'Doha';
      }
    }

    final riderJson = (json['rider'] ?? rawJson['rider']) as Map<String, dynamic>?;
    final rider = riderJson != null
        ? RiderModel.fromJson(riderJson)
        : RiderModel(
            id: json['riderId']?.toString() ?? rawJson['riderId']?.toString() ?? '',
            name: json['riderName']?.toString() ??
                rawJson['riderName']?.toString() ??
                'Customer',
            phone: json['riderPhone']?.toString() ?? rawJson['riderPhone']?.toString() ?? '',
          );

    final driverJson = (json['driver'] ?? rawJson['driver']) as Map<String, dynamic>?;
    final driver = driverJson != null
        ? DriverModel.fromJson(driverJson)
        : (json['driverId'] != null || rawJson['driverId'] != null)
            ? DriverModel(
                id: (json['driverId'] ?? rawJson['driverId']).toString(),
                name: 'Assigned Driver',
                phone: '',
              )
            : null;

    final pickupJson = (json['pickup'] ?? rawJson['pickup']) as Map<String, dynamic>?;
    final pickup = PlaceModel.fromJson(pickupJson);

    final dropoffJson = (json['dropoff'] ?? rawJson['dropoff']) as Map<String, dynamic>?;
    final dropoff = PlaceModel.fromJson(dropoffJson);

    final fareJson = (json['fare'] ?? rawJson['fare']) as Map<String, dynamic>?;
    final fare = fareJson != null
        ? MoneyModel.fromJson(fareJson)
        : (json['fareAmount'] != null || json['amount'] != null)
            ? MoneyModel(
                currency: json['currency']?.toString() ?? 'QAR',
                amount: (json['fareAmount'] as num?)?.toDouble() ??
                    (json['amount'] as num?)?.toDouble() ??
                    0.0,
              )
            : const MoneyModel(currency: 'QAR', amount: 0.0);

    final refundedJson = (json['refunded'] ?? rawJson['refunded']) as Map<String, dynamic>?;
    final refunded = MoneyModel.fromJson(refundedJson);

    final reqAt = parseDate(json['requestedAt']);
    final assAt = parseNullableDate(json['assignedAt']);
    final staAt = parseNullableDate(json['startedAt']);
    final comAt = parseNullableDate(json['completedAt']);
    final canAt = parseNullableDate(json['cancelledAt']);
    final cReason = json['cancelReason']?.toString();

    final timelineRaw = json['timeline'] as List? ?? [];
    final timeline = <TripTimelineModel>[];
    for (final e in timelineRaw) {
      if (e is Map<String, dynamic>) {
        final st = TripStatus.fromString(e['status']?.toString());
        DateTime eventTime;
        switch (st) {
          case TripStatus.requested:
            eventTime = reqAt;
            break;
          case TripStatus.assigned:
            eventTime = assAt ?? reqAt;
            break;
          case TripStatus.inProgress:
            eventTime = staAt ?? assAt ?? reqAt;
            break;
          case TripStatus.completed:
            eventTime = comAt ?? staAt ?? reqAt;
            break;
          case TripStatus.cancelled:
            eventTime = canAt ?? reqAt;
            break;
        }
        timeline.add(TripTimelineModel(
          status: st,
          timestamp: eventTime,
          note: st == TripStatus.cancelled ? cReason : e['note']?.toString(),
        ));
      }
    }

    if (timeline.isEmpty) {
      timeline.add(TripTimelineModel(status: TripStatus.requested, timestamp: reqAt));
      if (assAt != null) {
        timeline.add(TripTimelineModel(status: TripStatus.assigned, timestamp: assAt));
      }
      if (staAt != null) {
        timeline.add(TripTimelineModel(status: TripStatus.inProgress, timestamp: staAt));
      }
      if (comAt != null) {
        timeline.add(TripTimelineModel(status: TripStatus.completed, timestamp: comAt));
      }
      if (canAt != null) {
        timeline.add(TripTimelineModel(status: TripStatus.cancelled, timestamp: canAt, note: cReason));
      }
    }

    return TripModel(
      id: tripId,
      status: TripStatus.fromString((json['status'] ?? rawJson['status'])?.toString()),
      cityId: cId,
      cityName: cName,
      rider: rider,
      driver: driver,
      pickup: pickup,
      dropoff: dropoff,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      fare: fare,
      refunded: refunded,
      refundReason: json['refundReason']?.toString(),
      cancelReason: cReason,
      cancelledBy: json['cancelledBy']?.toString(),
      requestedAt: reqAt,
      assignedAt: assAt,
      startedAt: staAt,
      completedAt: comAt,
      cancelledAt: canAt,
      timeline: timeline,
    );
  }

  TripEntity toEntity() => this;
}

/// DTO for Paginated Trips.
class PaginatedTripsModel extends PaginatedTripsEntity {
  const PaginatedTripsModel({
    required super.trips,
    required super.hasNextPage,
    super.endCursor,
    required super.totalCount,
  });

  factory PaginatedTripsModel.fromGraphQL(Map<String, dynamic> json) {
    final tripsContainer = json['trips'] as Map<String, dynamic>? ?? {};

    final rawNodes = tripsContainer['nodes'] as List?;
    final List<TripEntity> trips;
    if (rawNodes != null) {
      trips = rawNodes
          .map((n) => TripModel.fromJson(n as Map<String, dynamic>).toEntity())
          .toList();
    } else {
      final edges = tripsContainer['edges'] as List? ?? [];
      trips = edges.map((edge) {
        final node = (edge as Map<String, dynamic>)['node'] as Map<String, dynamic>;
        return TripModel.fromJson(node).toEntity();
      }).toList();
    }

    final pageInfo = tripsContainer['pageInfo'] as Map<String, dynamic>? ?? {};
    final hasNextPage = pageInfo['hasNextPage'] as bool? ?? false;
    final endCursor = pageInfo['endCursor']?.toString();
    final totalCount = (tripsContainer['totalCount'] as num?)?.toInt() ?? trips.length;

    return PaginatedTripsModel(
      trips: trips,
      hasNextPage: hasNextPage,
      endCursor: endCursor,
      totalCount: totalCount,
    );
  }
}
