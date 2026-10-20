import 'package:equatable/equatable.dart';

/// Lifecycle statuses of a trip in the badrgo platform.
enum TripStatus {
  requested('REQUESTED', 'Requested'),
  assigned('ASSIGNED', 'Assigned'),
  inProgress('IN_PROGRESS', 'In Progress'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled');

  final String apiValue;
  final String label;

  const TripStatus(this.apiValue, this.label);

  static TripStatus fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ASSIGNED':
        return TripStatus.assigned;
      case 'IN_PROGRESS':
        return TripStatus.inProgress;
      case 'COMPLETED':
        return TripStatus.completed;
      case 'CANCELLED':
        return TripStatus.cancelled;
      case 'REQUESTED':
      default:
        return TripStatus.requested;
    }
  }
}

/// Pure domain entity for financial amounts.
class MoneyEntity extends Equatable {
  final String currency;
  final double amount;

  const MoneyEntity({
    required this.currency,
    required this.amount,
  });

  @override
  List<Object?> get props => [currency, amount];
}

/// Pure domain entity for Geographic Location & Name.
class PlaceEntity extends Equatable {
  final String name;
  final double? lat;
  final double? lng;

  const PlaceEntity({
    required this.name,
    this.lat,
    this.lng,
  });

  @override
  List<Object?> get props => [name, lat, lng];
}

/// Pure domain entity for Rider profile.
class RiderEntity extends Equatable {
  final String id;
  final String name;
  final String phone;

  const RiderEntity({
    required this.id,
    required this.name,
    required this.phone,
  });

  @override
  List<Object?> get props => [id, name, phone];
}

/// Pure domain entity for Driver profile.
class DriverEntity extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? vehicle;
  final String? status;

  const DriverEntity({
    required this.id,
    required this.name,
    required this.phone,
    this.vehicle,
    this.status,
  });

  @override
  List<Object?> get props => [id, name, phone, vehicle, status];
}

/// Pure domain entity for a single event in the Trip status timeline.
class TripTimelineEntity extends Equatable {
  final TripStatus status;
  final DateTime timestamp;
  final String? note;

  const TripTimelineEntity({
    required this.status,
    required this.timestamp,
    this.note,
  });

  @override
  List<Object?> get props => [status, timestamp, note];
}

/// Pure domain entity for a complete Trip snapshot.
///
/// Contains ZERO Flutter UI dependencies and ZERO transport code.
/// Adheres strictly to M4 requirements:
/// - Nested rider, driver, pickup & dropoff, fare, refunds, timeline.
/// - Calculation for remaining refundable balance.
/// - Validation logic for assign, cancel, and refund actions.
class TripEntity extends Equatable {
  final String id;
  final TripStatus status;
  final String cityId;
  final String cityName;
  final RiderEntity rider;
  final DriverEntity? driver;
  final PlaceEntity pickup;
  final PlaceEntity dropoff;
  final double distanceKm;
  final MoneyEntity fare;
  final MoneyEntity refunded;
  final String? refundReason;
  final String? cancelReason;
  final String? cancelledBy;
  final DateTime requestedAt;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final List<TripTimelineEntity> timeline;

  const TripEntity({
    required this.id,
    required this.status,
    required this.cityId,
    required this.cityName,
    required this.rider,
    this.driver,
    required this.pickup,
    required this.dropoff,
    required this.distanceKm,
    required this.fare,
    required this.refunded,
    this.refundReason,
    this.cancelReason,
    this.cancelledBy,
    required this.requestedAt,
    this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.timeline = const [],
  });

  /// Remaining refundable balance: fare amount minus already refunded amount.
  double get remainingRefundableAmount => (fare.amount - refunded.amount).clamp(0.0, double.infinity);

  /// Check whether driver assignment is available for this trip.
  bool get canAssign => status == TripStatus.requested;

  /// Check whether cancellation is allowed (completed and already cancelled trips cannot be cancelled).
  bool get canCancel => status != TripStatus.completed && status != TripStatus.cancelled;

  /// Check whether refund is allowed (must be completed and have remaining balance).
  bool get canRefund => status == TripStatus.completed && remainingRefundableAmount > 0;

  TripEntity copyWith({
    String? id,
    TripStatus? status,
    String? cityId,
    String? cityName,
    RiderEntity? rider,
    DriverEntity? driver,
    PlaceEntity? pickup,
    PlaceEntity? dropoff,
    double? distanceKm,
    MoneyEntity? fare,
    MoneyEntity? refunded,
    String? refundReason,
    String? cancelReason,
    String? cancelledBy,
    DateTime? requestedAt,
    DateTime? assignedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    List<TripTimelineEntity>? timeline,
  }) {
    return TripEntity(
      id: id ?? this.id,
      status: status ?? this.status,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      rider: rider ?? this.rider,
      driver: driver ?? this.driver,
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      distanceKm: distanceKm ?? this.distanceKm,
      fare: fare ?? this.fare,
      refunded: refunded ?? this.refunded,
      refundReason: refundReason ?? this.refundReason,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      requestedAt: requestedAt ?? this.requestedAt,
      assignedAt: assignedAt ?? this.assignedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      timeline: timeline ?? this.timeline,
    );
  }

  @override
  List<Object?> get props => [
        id,
        status,
        cityId,
        cityName,
        rider,
        driver,
        pickup,
        dropoff,
        distanceKm,
        fare,
        refunded,
        refundReason,
        cancelReason,
        cancelledBy,
        requestedAt,
        assignedAt,
        startedAt,
        completedAt,
        cancelledAt,
        timeline,
      ];
}

/// Filter parameters for paginated Trip queries.
class TripFilterEntity extends Equatable {
  final List<TripStatus>? status;
  final String? search;
  final DateTime? from;
  final DateTime? to;
  final String? cityId;

  const TripFilterEntity({
    this.status,
    this.search,
    this.from,
    this.to,
    this.cityId,
  });

  TripFilterEntity copyWith({
    List<TripStatus>? status,
    String? search,
    DateTime? from,
    DateTime? to,
    String? cityId,
  }) {
    return TripFilterEntity(
      status: status ?? this.status,
      search: search ?? this.search,
      from: from ?? this.from,
      to: to ?? this.to,
      cityId: cityId ?? this.cityId,
    );
  }

  /// Checks whether a trip satisfies this filter.
  bool matches(TripEntity trip) {
    if (status != null && status!.isNotEmpty) {
      if (!status!.contains(trip.status)) {
        return false;
      }
    }
    if (cityId != null && cityId!.isNotEmpty) {
      if (trip.cityId != cityId && trip.cityName.toLowerCase() != cityId!.toLowerCase()) {
        return false;
      }
    }
    if (from != null && trip.requestedAt.isBefore(from!)) {
      return false;
    }
    if (to != null && trip.requestedAt.isAfter(to!)) {
      return false;
    }
    if (search != null && search!.trim().isNotEmpty) {
      final q = search!.trim().toLowerCase();
      final inId = trip.id.toLowerCase().contains(q);
      final inRider = trip.rider.name.toLowerCase().contains(q) || trip.rider.phone.contains(q);
      final inDriver = (trip.driver?.name.toLowerCase().contains(q) ?? false) ||
          (trip.driver?.phone.contains(q) ?? false);
      final inRoute = trip.pickup.name.toLowerCase().contains(q) ||
          trip.dropoff.name.toLowerCase().contains(q);
      if (!inId && !inRider && !inDriver && !inRoute) {
        return false;
      }
    }
    return true;
  }

  @override
  List<Object?> get props => [status, search, from, to, cityId];
}

/// Paginated cursor envelope for Trip lists.
class PaginatedTripsEntity extends Equatable {
  final List<TripEntity> trips;
  final bool hasNextPage;
  final String? endCursor;
  final int totalCount;

  const PaginatedTripsEntity({
    required this.trips,
    required this.hasNextPage,
    this.endCursor,
    required this.totalCount,
  });

  @override
  List<Object?> get props => [trips, hasNextPage, endCursor, totalCount];
}
