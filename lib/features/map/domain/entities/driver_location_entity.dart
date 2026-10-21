import 'package:equatable/equatable.dart';

/// Pure domain entity representing a driver's live GPS location and status.
///
/// Adheres strictly to Domain Layer guidelines:
/// - Pure Dart
/// - Zero Flutter UI imports
/// - Zero transport/HTTP/WS imports
class DriverLocationEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String status;
  final double latitude;
  final double longitude;
  final double? heading;
  final String? vehicle;
  final String? currentTripId;
  final String? cityId;
  final DateTime updatedAt;

  const DriverLocationEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.vehicle,
    this.currentTripId,
    this.cityId,
    required this.updatedAt,
  });

  bool get isAvailable => status.toLowerCase() == 'available';
  bool get isOnTrip =>
      status.toLowerCase() == 'on_trip' || status.toLowerCase() == 'ontrip';
  bool get isBusy => status.toLowerCase() == 'busy';
  bool get isOffline => status.toLowerCase() == 'offline';

  DriverLocationEntity copyWith({
    String? id,
    String? name,
    String? phone,
    String? status,
    double? latitude,
    double? longitude,
    double? heading,
    String? vehicle,
    String? currentTripId,
    String? cityId,
    DateTime? updatedAt,
  }) {
    return DriverLocationEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      vehicle: vehicle ?? this.vehicle,
      currentTripId: currentTripId ?? this.currentTripId,
      cityId: cityId ?? this.cityId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        phone,
        status,
        latitude,
        longitude,
        heading,
        vehicle,
        currentTripId,
        cityId,
        updatedAt,
      ];
}
