import 'package:equatable/equatable.dart';
import '../../domain/entities/trip_entity.dart';

/// State representation for Trips List & Filtering adhering to MVVM.
abstract class TripsState extends Equatable {
  const TripsState();

  @override
  List<Object?> get props => [];
}

class TripsInitial extends TripsState {
  const TripsInitial();
}

class TripsLoading extends TripsState {
  const TripsLoading();
}

class TripsLoaded extends TripsState {
  final List<TripEntity> trips;
  final bool hasNextPage;
  final String? endCursor;
  final int totalCount;
  final TripFilterEntity filter;
  final bool isLoadingMore;
  final Set<String> recentlyCreatedTripIds;
  final Set<String> recentlyUpdatedTripIds;
  final TripEntity? selectedTrip;
  final bool isLoadingDetail;

  const TripsLoaded({
    required this.trips,
    this.hasNextPage = false,
    this.endCursor,
    this.totalCount = 0,
    this.filter = const TripFilterEntity(),
    this.isLoadingMore = false,
    this.recentlyCreatedTripIds = const {},
    this.recentlyUpdatedTripIds = const {},
    this.selectedTrip,
    this.isLoadingDetail = false,
  });

  TripsLoaded copyWith({
    List<TripEntity>? trips,
    bool? hasNextPage,
    String? endCursor,
    int? totalCount,
    TripFilterEntity? filter,
    bool? isLoadingMore,
    Set<String>? recentlyCreatedTripIds,
    Set<String>? recentlyUpdatedTripIds,
    TripEntity? selectedTrip,
    bool? isLoadingDetail,
    bool clearSelectedTrip = false,
  }) {
    return TripsLoaded(
      trips: trips ?? this.trips,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      endCursor: endCursor ?? this.endCursor,
      totalCount: totalCount ?? this.totalCount,
      filter: filter ?? this.filter,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      recentlyCreatedTripIds:
          recentlyCreatedTripIds ?? this.recentlyCreatedTripIds,
      recentlyUpdatedTripIds:
          recentlyUpdatedTripIds ?? this.recentlyUpdatedTripIds,
      selectedTrip:
          clearSelectedTrip ? null : (selectedTrip ?? this.selectedTrip),
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
    );
  }

  @override
  List<Object?> get props => [
        trips,
        hasNextPage,
        endCursor,
        totalCount,
        filter,
        isLoadingMore,
        recentlyCreatedTripIds,
        recentlyUpdatedTripIds,
        selectedTrip,
        isLoadingDetail,
      ];
}

class TripsError extends TripsState {
  final String message;

  const TripsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Fallback state when a trip from another city or invalid ID is visited.
/// Adheres to requirement: "A trip from another city by URL: the app shows a 'not found' state."
class TripNotFound extends TripsState {
  final String message;

  const TripNotFound({
    this.message = 'The requested trip was not found or is outside your assigned city jurisdiction.',
  });

  @override
  List<Object?> get props => [message];
}
