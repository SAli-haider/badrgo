import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/repositories/trips_repository.dart';
import 'trips_state.dart';

/// ViewModel for Trips list, pagination, filtering, and real-time SSE updates.
///
/// Adheres strictly to requirements:
/// - M4: "A paginated list (GraphQL, cursor based) with filters for status,
///   a date range and search."
/// - M4: "Live updates from SSE trip.created and trip.updated without a full reload.
///   Mark new and changed rows visibly."
/// - "A trip from another city by URL: the app shows a 'not found' state."
class TripsCubit extends Cubit<TripsState> {
  final TripsRepository _repository;
  StreamSubscription<TripEntity>? _createdSubscription;
  StreamSubscription<TripEntity>? _updatedSubscription;

  TripsCubit({
    required TripsRepository repository,
  })  : _repository = repository,
        super(const TripsInitial());

  /// Loads initial page of trips matching optional filters.
  Future<void> loadTrips({TripFilterEntity? filter}) async {
    final activeFilter = filter ?? const TripFilterEntity();
    emit(const TripsLoading());

    final result = await _repository.getTrips(filter: activeFilter, first: 20);

    result.when(
      success: (paginated) {
        emit(
          TripsLoaded(
            trips: paginated.trips,
            hasNextPage: paginated.hasNextPage,
            endCursor: paginated.endCursor,
            totalCount: paginated.totalCount,
            filter: activeFilter,
          ),
        );
        _startSseSubscriptions();
      },
      failure: (exception) {
        emit(TripsError(exception.message));
      },
    );
  }

  /// Fetches next page of cursor-paginated trips without destroying list state.
  Future<void> fetchNextPage() async {
    final currentState = state;
    if (currentState is! TripsLoaded) return;
    if (!currentState.hasNextPage || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    final result = await _repository.getTrips(
      filter: currentState.filter,
      first: 20,
      after: currentState.endCursor,
    );

    result.when(
      success: (newData) {
        // De-duplicate any trips that might already be in list due to SSE additions
        final existingIds = currentState.trips.map((t) => t.id).toSet();
        final filteredNew = newData.trips.where((t) => !existingIds.contains(t.id));

        emit(
          currentState.copyWith(
            trips: [...currentState.trips, ...filteredNew],
            hasNextPage: newData.hasNextPage,
            endCursor: newData.endCursor,
            totalCount: newData.totalCount,
            isLoadingMore: false,
          ),
        );
      },
      failure: (_) {
        emit(currentState.copyWith(isLoadingMore: false));
      },
    );
  }

  /// Applies new filter criteria and reloads the first page.
  Future<void> applyFilter(TripFilterEntity newFilter) async {
    await loadTrips(filter: newFilter);
  }

  /// Selects a trip to view complete nested details with city jurisdiction check.
  Future<void> selectTrip(
    String tripId, {
    String? userCity,
    bool isSuperAdmin = false,
  }) async {
    final currentState = state;
    TripEntity? cached;
    if (currentState is TripsLoaded) {
      cached = currentState.trips.cast<TripEntity?>().firstWhere(
            (t) => t?.id == tripId,
            orElse: () => null,
          );
      emit(currentState.copyWith(selectedTrip: cached, isLoadingDetail: true));
    }

    final result = await _repository.getTripById(tripId);

    result.when(
      success: (trip) {
        // City jurisdiction check:
        // "A trip from another city by URL: the app shows a 'not found' state."
        // super_admin has access to all cities.
        if (!isSuperAdmin &&
            userCity != null &&
            userCity.toLowerCase() != 'all' &&
            userCity.toLowerCase() != 'all cities') {
          final isDoha = userCity.toLowerCase().contains('doh');
          final isRayyan = userCity.toLowerCase().contains('ray');
          final isWakrah = userCity.toLowerCase().contains('wak');

          final tripCity = trip.cityName.toLowerCase();
          final tripCityId = trip.cityId.toLowerCase();

          final matches = (isDoha && (tripCity.contains('doh') || tripCityId.contains('doh'))) ||
              (isRayyan && (tripCity.contains('ray') || tripCityId.contains('ray'))) ||
              (isWakrah && (tripCity.contains('wak') || tripCityId.contains('wak'))) ||
              tripCity == userCity.toLowerCase() ||
              tripCityId == userCity.toLowerCase();

          if (!matches) {
            emit(const TripNotFound());
            return;
          }
        }

        if (state is TripsLoaded) {
          emit(
            (state as TripsLoaded).copyWith(
              selectedTrip: trip,
              isLoadingDetail: false,
            ),
          );
        }
      },
      failure: (exception) {
        if (state is TripsLoaded) {
          emit((state as TripsLoaded).copyWith(isLoadingDetail: false));
        } else {
          emit(TripNotFound(message: exception.message));
        }
      },
    );
  }

  /// Clears the selected trip detail drawer.
  void clearSelectedTrip() {
    if (state is TripsLoaded) {
      emit((state as TripsLoaded).copyWith(clearSelectedTrip: true));
    }
  }

  /// Updates a single trip in the loaded list and selected view.
  void updateTrip(TripEntity updatedTrip) {
    if (state is TripsLoaded) {
      final current = state as TripsLoaded;
      final index = current.trips.indexWhere((t) => t.id == updatedTrip.id);
      if (index != -1) {
        final updatedList = List<TripEntity>.from(current.trips);
        updatedList[index] = updatedTrip;
        emit(
          current.copyWith(
            trips: updatedList,
            selectedTrip: current.selectedTrip?.id == updatedTrip.id
                ? updatedTrip
                : current.selectedTrip,
          ),
        );
      }
    }
  }

  /// Re-fetches a single trip's full details from GraphQL and updates it in the table and sheet.
  Future<void> refreshTrip(String tripId) async {
    final result = await _repository.getTripById(tripId);
    result.when(
      success: (trip) => updateTrip(trip),
      failure: (_) {},
    );
  }

  /// Listens to real-time SSE events for new and updated trips.
  void _startSseSubscriptions() {
    _createdSubscription?.cancel();
    _createdSubscription = _repository.subscribeTripCreated().listen((newTrip) async {
      if (newTrip.id.isEmpty) return;

      final currentState = state;
      if (currentState is TripsLoaded) {
        // Enforce active filter: do not insert if the new trip does not match current filter
        if (!currentState.filter.matches(newTrip)) {
          return;
        }

        final exists = currentState.trips.any((t) => t.id == newTrip.id);
        if (!exists) {
          final updatedNewIds = Set<String>.from(currentState.recentlyCreatedTripIds)
            ..add(newTrip.id);

          emit(
            currentState.copyWith(
              trips: [newTrip, ...currentState.trips],
              totalCount: currentState.totalCount + 1,
              recentlyCreatedTripIds: updatedNewIds,
            ),
          );

          // Enrich with full nested GraphQL data if SSE was minimal (missing rider name or address)
          if (newTrip.rider.name == 'Customer' ||
              newTrip.pickup.name == 'Trip Location' ||
              newTrip.pickup.name == 'Unknown Location') {
            final detailRes = await _repository.getTripById(newTrip.id);
            detailRes.when(
              success: (enrichedTrip) {
                if (state is TripsLoaded) {
                  final cur = state as TripsLoaded;
                  // Double check it still matches filter
                  if (!cur.filter.matches(enrichedTrip)) {
                    final filteredList = List<TripEntity>.from(cur.trips)
                      ..removeWhere((t) => t.id == enrichedTrip.id);
                    emit(cur.copyWith(trips: filteredList));
                    return;
                  }
                  final idx = cur.trips.indexWhere((t) => t.id == enrichedTrip.id);
                  if (idx != -1) {
                    final enrichedList = List<TripEntity>.from(cur.trips);
                    enrichedList[idx] = enrichedTrip;
                    emit(cur.copyWith(trips: enrichedList));
                  }
                }
              },
              failure: (_) {},
            );
          }
        }
      }
    });

    _updatedSubscription?.cancel();
    _updatedSubscription = _repository.subscribeTripUpdated().listen((updatedTrip) async {
      if (updatedTrip.id.isEmpty) return;

      final currentState = state;
      if (currentState is TripsLoaded) {
        final filter = currentState.filter;
        final index = currentState.trips.indexWhere((t) => t.id == updatedTrip.id);

        if (index != -1) {
          final updatedList = List<TripEntity>.from(currentState.trips);
          // If it no longer matches the active filter (e.g. status changed from requested to assigned), remove it
          if (!filter.matches(updatedTrip)) {
            updatedList.removeAt(index);
          } else {
            updatedList[index] = updatedTrip;
          }

          final updatedIds = Set<String>.from(currentState.recentlyUpdatedTripIds)
            ..add(updatedTrip.id);

          TripEntity? selected = currentState.selectedTrip;
          if (selected?.id == updatedTrip.id) {
            selected = updatedTrip;
          }

          emit(
            currentState.copyWith(
              trips: updatedList,
              recentlyUpdatedTripIds: updatedIds,
              selectedTrip: selected,
            ),
          );
        } else if (filter.matches(updatedTrip)) {
          // If trip wasn't in the list before but now matches the active filter (e.g. now assigned)
          final updatedList = [updatedTrip, ...currentState.trips];
          final updatedIds = Set<String>.from(currentState.recentlyUpdatedTripIds)
            ..add(updatedTrip.id);

          emit(
            currentState.copyWith(
              trips: updatedList,
              recentlyUpdatedTripIds: updatedIds,
            ),
          );
        }

        // Enrich with full GraphQL data in background if SSE was minimal
        if (updatedTrip.rider.name == 'Customer' ||
            updatedTrip.pickup.name == 'Trip Location' ||
            updatedTrip.pickup.name == 'Unknown Location') {
          final detailRes = await _repository.getTripById(updatedTrip.id);
          detailRes.when(
            success: (enrichedTrip) {
              if (state is TripsLoaded) {
                final cur = state as TripsLoaded;
                final idx = cur.trips.indexWhere((t) => t.id == enrichedTrip.id);
                if (idx != -1) {
                  final enrichedList = List<TripEntity>.from(cur.trips);
                  if (!cur.filter.matches(enrichedTrip)) {
                    enrichedList.removeAt(idx);
                  } else {
                    enrichedList[idx] = enrichedTrip;
                  }
                  emit(
                    cur.copyWith(
                      trips: enrichedList,
                      selectedTrip: cur.selectedTrip?.id == enrichedTrip.id
                          ? enrichedTrip
                          : cur.selectedTrip,
                    ),
                  );
                }
              }
            },
            failure: (_) {},
          );
        }
      }
    });
  }

  @override
  Future<void> close() {
    _createdSubscription?.cancel();
    _updatedSubscription?.cancel();
    return super.close();
  }
}
