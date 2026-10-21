import '../../domain/entities/driver_location_entity.dart';

/// DTO for deserializing driver location data frames from WebSocket.
class DriverLocationModel extends DriverLocationEntity {
  const DriverLocationModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.status,
    required super.latitude,
    required super.longitude,
    super.heading,
    super.vehicle,
    super.currentTripId,
    super.cityId,
    required super.updatedAt,
  });

  static double _parseDouble(dynamic val, {double defaultValue = 0.0}) {
    if (val == null) return defaultValue;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? defaultValue;
    }
    return defaultValue;
  }

  static double? _parseHeading(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

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

  factory DriverLocationModel.fromJson(Map<String, dynamic> json) {
    // 1. Resolve Driver ID
    final id = (json['driverId'] ??
            json['id'] ??
            json['driver_id'] ??
            '')
        .toString();

    // 2. Resolve Name & Phone
    final name = (json['driverName'] ??
            json['name'] ??
            json['driver_name'] ??
            'Driver $id')
        .toString();
    final phone = (json['phone'] ?? json['phoneNumber'] ?? '').toString();

    // 3. Resolve Status
    final status = (json['status'] ?? 'available').toString();

    // 4. Resolve Coordinates (handles nested location or flat lat/lng)
    double lat = 0.0;
    double lng = 0.0;
    double? heading;

    if (json['location'] is Map) {
      final loc = json['location'] as Map;
      lat = _parseDouble(loc['lat'] ?? loc['latitude']);
      lng = _parseDouble(loc['lng'] ?? loc['longitude'] ?? loc['lon']);
      heading = _parseHeading(loc['heading'] ?? loc['bearing']);
    } else {
      lat = _parseDouble(json['lat'] ?? json['latitude']);
      lng = _parseDouble(json['lng'] ?? json['longitude'] ?? json['lon']);
      heading = _parseHeading(json['heading'] ?? json['bearing']);
    }

    // 5. Resolve Vehicle, Trip, City
    final vehicle = _parseVehicle(json['vehicle']);
    final currentTripId =
        (json['currentTripId'] ?? json['current_trip_id'] ?? json['tripId'])
            ?.toString();
    final cityId = (json['cityId'] ?? json['city_id'] ?? json['city'])?.toString();

    // 6. Resolve Timestamp
    final rawTime = json['updatedAt'] ?? json['timestamp'] ?? json['time'];
    final updatedAt = rawTime != null
        ? (DateTime.tryParse(rawTime.toString()) ?? DateTime.now())
        : DateTime.now();

    return DriverLocationModel(
      id: id,
      name: name,
      phone: phone,
      status: status,
      latitude: lat,
      longitude: lng,
      heading: heading,
      vehicle: vehicle,
      currentTripId: currentTripId,
      cityId: cityId,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'status': status,
        'latitude': latitude,
        'longitude': longitude,
        if (heading != null) 'heading': heading,
        if (vehicle != null) 'vehicle': vehicle,
        if (currentTripId != null) 'currentTripId': currentTripId,
        if (cityId != null) 'cityId': cityId,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
