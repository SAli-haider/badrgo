import 'package:equatable/equatable.dart';
import '../../../../core/network/ws/ws_connection_state.dart';
import '../../../trips/domain/entities/trip_entity.dart';
import '../../domain/entities/driver_location_entity.dart';

/// State representation for Live Driver Map module.
abstract class LiveMapState extends Equatable {
  const LiveMapState();

  @override
  List<Object?> get props => [];
}

/// Initial state before tracking starts.
class LiveMapInitial extends LiveMapState {
  const LiveMapInitial();
}

/// Loading state while establishing socket or loading initial dataset.
class LiveMapLoading extends LiveMapState {
  const LiveMapLoading();
}

/// Access restricted state when user lacks `driver:track` permission (e.g. Support role).
class LiveMapRestricted extends LiveMapState {
  final String requiredPermission;

  const LiveMapRestricted({this.requiredPermission = 'driver:track'});

  @override
  List<Object?> get props => [requiredPermission];
}

/// Successfully loaded live driver map state.
class LiveMapLoaded extends LiveMapState {
  final List<DriverLocationEntity> allDrivers;
  final List<DriverLocationEntity> filteredDrivers;
  final String statusFilter; // 'all', 'available', 'on_trip', 'busy'
  final String searchQuery;
  final DriverLocationEntity? selectedDriver;
  final DriverEntity? selectedDriverDetail;
  final TripEntity? selectedDriverTrip;
  final bool isLoadingDetail;
  final WsConnectionState connectionState;
  final int? secondsRemaining;
  final double centerLat;
  final double centerLng;
  final double currentZoom;

  const LiveMapLoaded({
    required this.allDrivers,
    required this.filteredDrivers,
    this.statusFilter = 'all',
    this.searchQuery = '',
    this.selectedDriver,
    this.selectedDriverDetail,
    this.selectedDriverTrip,
    this.isLoadingDetail = false,
    this.connectionState = WsConnectionState.connected,
    this.secondsRemaining,
    required this.centerLat,
    required this.centerLng,
    this.currentZoom = 12.0,
  });

  int get availableCount =>
      allDrivers.where((d) => d.isAvailable).length;
  int get onTripCount => allDrivers.where((d) => d.isOnTrip).length;
  int get busyCount =>
      allDrivers.where((d) => d.isBusy || d.isOffline).length;
  int get totalCount => allDrivers.length;

  LiveMapLoaded copyWith({
    List<DriverLocationEntity>? allDrivers,
    List<DriverLocationEntity>? filteredDrivers,
    String? statusFilter,
    String? searchQuery,
    DriverLocationEntity? selectedDriver,
    bool clearSelectedDriver = false,
    DriverEntity? selectedDriverDetail,
    bool clearSelectedDetail = false,
    TripEntity? selectedDriverTrip,
    bool clearSelectedTrip = false,
    bool? isLoadingDetail,
    WsConnectionState? connectionState,
    int? secondsRemaining,
    bool clearCountdown = false,
    double? centerLat,
    double? centerLng,
    double? currentZoom,
  }) {
    return LiveMapLoaded(
      allDrivers: allDrivers ?? this.allDrivers,
      filteredDrivers: filteredDrivers ?? this.filteredDrivers,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDriver: clearSelectedDriver
          ? null
          : (selectedDriver ?? this.selectedDriver),
      selectedDriverDetail: clearSelectedDetail
          ? null
          : (selectedDriverDetail ?? this.selectedDriverDetail),
      selectedDriverTrip: clearSelectedTrip
          ? null
          : (selectedDriverTrip ?? this.selectedDriverTrip),
      isLoadingDetail: isLoadingDetail ?? this.isLoadingDetail,
      connectionState: connectionState ?? this.connectionState,
      secondsRemaining: clearCountdown
          ? null
          : (secondsRemaining ?? this.secondsRemaining),
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      currentZoom: currentZoom ?? this.currentZoom,
    );
  }

  @override
  List<Object?> get props => [
        allDrivers,
        filteredDrivers,
        statusFilter,
        searchQuery,
        selectedDriver,
        selectedDriverDetail,
        selectedDriverTrip,
        isLoadingDetail,
        connectionState,
        secondsRemaining,
        centerLat,
        centerLng,
        currentZoom,
      ];
}

/// Error state when connection or critical tracking failure occurs.
class LiveMapError extends LiveMapState {
  final String message;

  const LiveMapError(this.message);

  @override
  List<Object?> get props => [message];
}
