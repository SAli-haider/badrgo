import 'package:equatable/equatable.dart';
import '../../domain/entities/trip_entity.dart';

/// State representation for Trip Mutation Actions (Assign, Cancel, Refund).
abstract class TripActionState extends Equatable {
  const TripActionState();

  @override
  List<Object?> get props => [];
}

class TripActionInitial extends TripActionState {
  const TripActionInitial();
}

class TripActionLoading extends TripActionState {
  const TripActionLoading();
}

class TripActionSuccess extends TripActionState {
  final String message;
  final TripEntity trip;

  const TripActionSuccess({
    required this.message,
    required this.trip,
  });

  @override
  List<Object?> get props => [message, trip];
}

/// Specialized state for 409 INVALID_STATE / CONFLICT simulator race conditions.
/// Adheres to requirement: "Handle 409 INVALID_STATE clearly. The simulator may change a trip while the user is looking at it."
class TripActionConflict extends TripActionState {
  final String message;
  final String tripId;

  const TripActionConflict({
    required this.message,
    required this.tripId,
  });

  @override
  List<Object?> get props => [message, tripId];
}

class TripActionError extends TripActionState {
  final String message;

  const TripActionError(this.message);

  @override
  List<Object?> get props => [message];
}

class AvailableDriversLoaded extends TripActionState {
  final List<DriverEntity> drivers;

  const AvailableDriversLoaded(this.drivers);

  @override
  List<Object?> get props => [drivers];
}
