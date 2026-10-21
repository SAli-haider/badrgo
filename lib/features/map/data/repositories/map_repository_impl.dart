import 'dart:async';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/rest_client.dart';
import '../../../../core/network/ws/ws_client.dart';
import '../../../../core/network/ws/ws_connection_state.dart';
import '../../../trips/data/models/trip_model.dart';
import '../../../trips/domain/entities/trip_entity.dart';
import '../../domain/entities/driver_location_entity.dart';
import '../../domain/repositories/map_repository.dart';
import '../models/driver_location_model.dart';

/// Implementation of MapRepository connecting WebSocket transport and REST endpoints.
class MapRepositoryImpl implements MapRepository {
  final WsClient _wsClient;
  final RestClient _restClient;

  static const String _locationsChannel = 'drivers.locations';

  StreamSubscription<dynamic>? _wsSubscription;
  final _driversLocationController =
      StreamController<List<DriverLocationEntity>>.broadcast();

  // Internal memory cache of active driver locations
  final Map<String, DriverLocationEntity> _drivers = {};

  MapRepositoryImpl({
    required WsClient wsClient,
    required RestClient restClient,
  })  : _wsClient = wsClient,
        _restClient = restClient;

  @override
  Stream<List<DriverLocationEntity>> streamDriverLocations() {
    return _driversLocationController.stream;
  }

  @override
  Stream<WsConnectionState> get connectionStateStream =>
      _wsClient.connectionStateStream;

  @override
  Stream<int?> get countdownStream => _wsClient.countdownStream;

  @override
  WsConnectionState get connectionState => _wsClient.state;

  @override
  List<DriverLocationEntity> get cachedDrivers => _drivers.values.toList();

  @override
  void startTracking(String token) {
    if (!_wsClient.isConnected) {
      _wsClient.connect(token);
    }

    _wsSubscription?.cancel();
    _wsSubscription = _wsClient
        .subscribe(_locationsChannel)
        .listen(_handleIncomingFrame);

    // Immediately push cached telemetry if available
    if (_drivers.isNotEmpty) {
      _emitCurrentDrivers();
    }
  }

  void _handleIncomingFrame(dynamic frame) {
    if (frame == null) return;

    if (frame is List) {
      _processDriverList(frame);
    } else if (frame is Map<String, dynamic>) {
      // Official badrgo WebSocket snapshot: { "at": "...", "drivers": [...] }
      if (frame['drivers'] is List) {
        _processDriverList(frame['drivers'] as List);
      } else if (frame['payload'] is Map &&
          frame['payload']['drivers'] is List) {
        _processDriverList(frame['payload']['drivers'] as List);
      } else if (frame['data'] is List) {
        _processDriverList(frame['data'] as List);
      } else if (frame['data'] is Map<String, dynamic>) {
        _processSingleDriver(frame['data'] as Map<String, dynamic>);
      } else if (frame.containsKey('driverId') ||
          frame.containsKey('id') ||
          frame.containsKey('location')) {
        _processSingleDriver(frame);
      }
    }
  }

  void _processDriverList(List<dynamic> list) {
    // Official requirement: "A full snapshot every ~2 s (not deltas). Replace your map markers each time."
    _drivers.clear();
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final driver = DriverLocationModel.fromJson(item);
        if (driver.id.isNotEmpty) {
          _drivers[driver.id] = driver;
        }
      }
    }
    _emitCurrentDrivers();
  }

  void _processSingleDriver(Map<String, dynamic> json) {
    final driver = DriverLocationModel.fromJson(json);
    if (driver.id.isNotEmpty) {
      _drivers[driver.id] = driver;
      _emitCurrentDrivers();
    }
  }

  void _emitCurrentDrivers() {
    if (!_driversLocationController.isClosed) {
      _driversLocationController.add(_drivers.values.toList());
    }
  }

  @override
  void stopTracking() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
  }

  @override
  Future<ApiResult<DriverEntity>> getDriverDetails(String driverId) async {
    final result = await _restClient.get<DriverEntity>(
      '/api/drivers/$driverId',
      fromJson: (data) => DriverModel.fromJson(data as Map<String, dynamic>?),
    );

    return result.when(
      success: (driver) => ApiSuccess(driver),
      failure: (exception) {
        // Fallback: If REST fetch fails, construct profile from cached live location
        final cached = _drivers[driverId];
        if (cached != null) {
          return ApiSuccess(
            DriverEntity(
              id: cached.id,
              name: cached.name,
              phone: cached.phone,
              vehicle: cached.vehicle,
              status: cached.status,
            ),
          );
        }
        return ApiFailure(exception);
      },
    );
  }

  @override
  Future<ApiResult<TripEntity?>> getActiveTrip(String tripId) async {
    final result = await _restClient.get<TripEntity>(
      '/api/trips/$tripId',
      fromJson: (data) =>
          TripModel.fromJson(data as Map<String, dynamic>),
    );

    return result.when(
      success: (trip) => ApiSuccess(trip),
      failure: (exception) => ApiFailure(exception),
    );
  }

  @override
  void dispose() {
    stopTracking();
    _driversLocationController.close();
  }
}
