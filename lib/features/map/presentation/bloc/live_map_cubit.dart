import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/ws/ws_connection_state.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../trips/domain/entities/trip_entity.dart';
import '../../domain/entities/driver_location_entity.dart';
import '../../domain/repositories/map_repository.dart';
import 'live_map_state.dart';

/// ViewModel / Cubit managing real-time WebSocket state, driver positions,
/// marker selection, and RBAC permission enforcement for Live Map.
class LiveMapCubit extends Cubit<LiveMapState> {
  final MapRepository _repository;
  final UserEntity _currentUser;
  final String _token;

  StreamSubscription<List<DriverLocationEntity>>? _locationsSub;
  StreamSubscription<WsConnectionState>? _stateSub;
  StreamSubscription<int?>? _countdownSub;

  LiveMapCubit({
    required MapRepository repository,
    required UserEntity currentUser,
    required String token,
  })  : _repository = repository,
        _currentUser = currentUser,
        _token = token,
        super(const LiveMapInitial());

  /// Coordinates for default city centers
  static (double, double) getCityCenter(String? city) {
    final lower = city?.toLowerCase() ?? '';
    if (lower.contains('rayyan')) {
      return (25.2919, 51.4244);
    } else if (lower.contains('wakrah')) {
      return (25.1768, 51.6048);
    }
    // Default to Doha center
    return (25.2867, 51.5333);
  }

  /// Initializes tracking if permitted by RBAC.
  void initTracking() {
    // 1. RBAC Guard: Verify driver:track permission
    if (!_currentUser.hasPermission('driver:track')) {
      emit(const LiveMapRestricted(requiredPermission: 'driver:track'));
      return;
    }

    final (centerLat, centerLng) = getCityCenter(_currentUser.city);
    final cached = _repository.cachedDrivers;
    final initialFiltered = _filterDrivers(cached, 'all', '');
    final initialConn = _repository.connectionState;

    // Initial loaded state with cached telemetry & active connection state
    emit(
      LiveMapLoaded(
        allDrivers: cached,
        filteredDrivers: initialFiltered,
        centerLat: centerLat,
        centerLng: centerLng,
        connectionState: initialConn,
      ),
    );

    // 2. Set up listeners BEFORE calling startTracking
    _stateSub?.cancel();
    _stateSub = _repository.connectionStateStream.listen((connState) {
      if (state is LiveMapLoaded) {
        final current = state as LiveMapLoaded;
        emit(current.copyWith(connectionState: connState));
      }
    });

    _countdownSub?.cancel();
    _countdownSub = _repository.countdownStream.listen((seconds) {
      if (state is LiveMapLoaded) {
        final current = state as LiveMapLoaded;
        emit(
          current.copyWith(
            secondsRemaining: seconds,
            clearCountdown: seconds == null,
          ),
        );
      }
    });

    _locationsSub?.cancel();
    _locationsSub =
        _repository.streamDriverLocations().listen(_onLocationsUpdated);

    // 3. Start or resume WebSocket Tracking
    _repository.startTracking(_token);
  }

  void _onLocationsUpdated(List<DriverLocationEntity> newDrivers) {
    if (state is! LiveMapLoaded) return;
    final current = state as LiveMapLoaded;

    final filtered = _filterDrivers(
      newDrivers,
      current.statusFilter,
      current.searchQuery,
    );

    // Keep selected driver synced if position or status changed
    DriverLocationEntity? updatedSelected = current.selectedDriver;
    if (updatedSelected != null) {
      final matchIndex =
          newDrivers.indexWhere((d) => d.id == updatedSelected!.id);
      if (matchIndex != -1) {
        updatedSelected = newDrivers[matchIndex];
      }
    }

    emit(
      current.copyWith(
        allDrivers: newDrivers,
        filteredDrivers: filtered,
        selectedDriver: updatedSelected,
        connectionState: WsConnectionState.connected,
      ),
    );
  }

  /// Changes status filter ('all', 'available', 'on_trip', 'busy').
  void setFilter(String status) {
    if (state is! LiveMapLoaded) return;
    final current = state as LiveMapLoaded;

    final filtered = _filterDrivers(
      current.allDrivers,
      status,
      current.searchQuery,
    );

    emit(current.copyWith(statusFilter: status, filteredDrivers: filtered));
  }

  /// Changes search filter query.
  void setSearch(String query) {
    if (state is! LiveMapLoaded) return;
    final current = state as LiveMapLoaded;

    final filtered = _filterDrivers(
      current.allDrivers,
      current.statusFilter,
      query,
    );

    emit(current.copyWith(searchQuery: query, filteredDrivers: filtered));
  }

  List<DriverLocationEntity> _filterDrivers(
    List<DriverLocationEntity> drivers,
    String statusFilter,
    String searchQuery,
  ) {
    return drivers.where((driver) {
      // Status match
      final matchesStatus = switch (statusFilter.toLowerCase()) {
        'available' => driver.isAvailable,
        'on_trip' => driver.isOnTrip,
        'busy' => driver.isBusy || driver.isOffline,
        _ => true,
      };

      if (!matchesStatus) return false;

      // Search match
      if (searchQuery.trim().isEmpty) return true;
      final q = searchQuery.toLowerCase().trim();
      final inName = driver.name.toLowerCase().contains(q);
      final inPhone = driver.phone.toLowerCase().contains(q);
      final inVehicle = driver.vehicle?.toLowerCase().contains(q) ?? false;
      final inId = driver.id.toLowerCase().contains(q);

      return inName || inPhone || inVehicle || inId;
    }).toList();
  }

  /// Selects a driver marker and fetches comprehensive profile & active trip.
  Future<void> selectDriver(DriverLocationEntity? driver) async {
    if (state is! LiveMapLoaded) return;
    final current = state as LiveMapLoaded;

    if (driver == null) {
      emit(
        current.copyWith(
          clearSelectedDriver: true,
          clearSelectedDetail: true,
          clearSelectedTrip: true,
          isLoadingDetail: false,
        ),
      );
      return;
    }

    emit(
      current.copyWith(
        selectedDriver: driver,
        isLoadingDetail: true,
      ),
    );

    // Fetch detailed profile
    final detailResult = await _repository.getDriverDetails(driver.id);
    final driverDetail = detailResult.when(
      success: (data) => data,
      failure: (_) => null,
    );

    // If driver is currently on trip, fetch active trip details
    TripEntity? tripDetail;
    if (driver.currentTripId != null && driver.currentTripId!.isNotEmpty) {
      final tripResult =
          await _repository.getActiveTrip(driver.currentTripId!);
      tripDetail = tripResult.when(
        success: (data) => data,
        failure: (_) => null,
      );
    }

    if (state is LiveMapLoaded) {
      emit(
        (state as LiveMapLoaded).copyWith(
          selectedDriverDetail: driverDetail,
          selectedDriverTrip: tripDetail,
          isLoadingDetail: false,
        ),
      );
    }
  }

  /// Re-centers map coordinates.
  void recenter(double lat, double lng, {double zoom = 12.0}) {
    if (state is! LiveMapLoaded) return;
    final current = state as LiveMapLoaded;
    emit(current.copyWith(centerLat: lat, centerLng: lng, currentZoom: zoom));
  }

  @override
  Future<void> close() {
    _locationsSub?.cancel();
    _stateSub?.cancel();
    _countdownSub?.cancel();
    _repository.stopTracking();
    return super.close();
  }
}
