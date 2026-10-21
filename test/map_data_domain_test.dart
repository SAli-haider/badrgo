import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:badrgo_ops_console/core/network/api_result.dart';
import 'package:badrgo_ops_console/core/network/rest_client.dart';
import 'package:badrgo_ops_console/core/network/ws/ws_client.dart';
import 'package:badrgo_ops_console/core/network/ws/ws_connection_state.dart';
import 'package:badrgo_ops_console/features/map/data/models/driver_location_model.dart';
import 'package:badrgo_ops_console/features/map/data/repositories/map_repository_impl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory mock for WebSocketChannel
class _MockWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  final StreamController<dynamic> _sinkController =
      StreamController<dynamic>();

  List<dynamic> sentMessages = [];

  _MockWebSocketChannel() {
    _sinkController.stream.listen((message) {
      sentMessages.add(message);
    });
  }

  void emit(dynamic data) {
    _streamController.add(data);
  }

  void closeWithError(dynamic error) {
    _streamController.addError(error);
  }

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  WebSocketSink get sink => _MockWebSocketSink(_sinkController);

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Future<void> get ready => Future.value();

  @override
  String? get protocol => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockWebSocketSink implements WebSocketSink {
  final StreamController<dynamic> _controller;
  _MockWebSocketSink(this._controller);

  @override
  void add(dynamic data) => _controller.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _controller.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) =>
      _controller.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) =>
      _controller.close();

  @override
  Future<void> get done => _controller.done;
}

void main() {
  group('Part 5.1: WsClient & Reconnection Engine Tests', () {
    test('calculateBackoffSeconds follows exponential progression capped at 30s', () {
      expect(WsClient.calculateBackoffSeconds(0), 1);
      expect(WsClient.calculateBackoffSeconds(1), 2);
      expect(WsClient.calculateBackoffSeconds(2), 4);
      expect(WsClient.calculateBackoffSeconds(3), 8);
      expect(WsClient.calculateBackoffSeconds(4), 16);
      expect(WsClient.calculateBackoffSeconds(5), 30); // Capped at 30s
      expect(WsClient.calculateBackoffSeconds(10), 30); // Capped at 30s
    });

    test('WsClient connects, sends subscription frame and receives channel messages', () async {
      late _MockWebSocketChannel mockChannel;
      final wsClient = WsClient(
        channelFactory: (uri) {
          mockChannel = _MockWebSocketChannel();
          return mockChannel;
        },
      );

      final stateHistory = <WsConnectionState>[];
      final stateSub = wsClient.connectionStateStream.listen(stateHistory.add);

      // Subscribe to drivers.locations channel before connecting
      final locationsStream = wsClient.subscribe('drivers.locations');
      final receivedData = <dynamic>[];
      final dataSub = locationsStream.listen(receivedData.add);

      wsClient.connect('dummy_token_123');

      // Allow event loop to process connection
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(wsClient.isConnected, isTrue);
      expect(stateHistory, contains(WsConnectionState.connected));

      // Verify subscription frame was sent to the sink
      expect(mockChannel.sentMessages.length, 1);
      final sentFrame = jsonDecode(mockChannel.sentMessages.first as String);
      expect(sentFrame['type'], 'subscribe');
      expect(sentFrame['payload']['channel'], 'drivers.locations');

      // Emit simulated driver location payload
      mockChannel.emit(jsonEncode({
        'channel': 'drivers.locations',
        'data': [
          {
            'driverId': 'drv-101',
            'status': 'available',
            'latitude': 25.2867,
            'longitude': 51.5333,
          }
        ]
      }));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(receivedData.length, 1);
      expect((receivedData.first as List).first['driverId'], 'drv-101');

      // Cleanup
      wsClient.disconnect();
      expect(wsClient.isConnected, isFalse);

      await stateSub.cancel();
      await dataSub.cancel();
      wsClient.dispose();
    });
  });

  group('Part 5.2 & 5.3: DriverLocationModel Deserialization Tests', () {
    test('parses nested location format with complex vehicle object and heading', () {
      final json = {
        'driverId': 'drv-777',
        'name': 'Ali Hassan',
        'phone': '+97455001122',
        'status': 'on_trip',
        'currentTripId': 'trip-999',
        'cityId': 'city-doha',
        'location': {
          'lat': 25.2867,
          'lng': 51.5333,
          'heading': 180.5,
        },
        'vehicle': {
          'make': 'Toyota',
          'model': 'Camry',
          'plate': '998877',
          'color': 'White',
        },
        'updatedAt': '2026-10-21T10:00:00.000Z',
      };

      final model = DriverLocationModel.fromJson(json);

      expect(model.id, 'drv-777');
      expect(model.name, 'Ali Hassan');
      expect(model.phone, '+97455001122');
      expect(model.status, 'on_trip');
      expect(model.isOnTrip, isTrue);
      expect(model.isAvailable, isFalse);
      expect(model.latitude, 25.2867);
      expect(model.longitude, 51.5333);
      expect(model.heading, 180.5);
      expect(model.vehicle, 'Toyota Camry · White · 998877');
      expect(model.currentTripId, 'trip-999');
      expect(model.cityId, 'city-doha');
    });

    test('parses flat location format with string lat/lng', () {
      final json = {
        'id': 'drv-888',
        'name': 'Omar',
        'lat': '25.1768',
        'lng': '51.6048',
        'status': 'available',
        'vehicle': 'Honda Civic · Black',
      };

      final model = DriverLocationModel.fromJson(json);

      expect(model.id, 'drv-888');
      expect(model.name, 'Omar');
      expect(model.latitude, 25.1768);
      expect(model.longitude, 51.6048);
      expect(model.status, 'available');
      expect(model.isAvailable, isTrue);
      expect(model.vehicle, 'Honda Civic · Black');
    });
  });

  group('Part 5.3: MapRepositoryImpl Tests', () {
    test('ingests driver batches and updates live driver stream', () async {
      late _MockWebSocketChannel mockChannel;
      final wsClient = WsClient(
        channelFactory: (uri) {
          mockChannel = _MockWebSocketChannel();
          return mockChannel;
        },
      );
      final restClient = RestClient();
      final repository = MapRepositoryImpl(
        wsClient: wsClient,
        restClient: restClient,
      );

      final receivedBatches = <List<dynamic>>[];
      final sub = repository.streamDriverLocations().listen(receivedBatches.add);

      repository.startTracking('test_token');
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Emit initial batch of 2 drivers
      mockChannel.emit(jsonEncode({
        'channel': 'drivers.locations',
        'data': [
          {
            'driverId': 'd1',
            'name': 'Driver One',
            'status': 'available',
            'latitude': 25.28,
            'longitude': 51.53,
          },
          {
            'driverId': 'd2',
            'name': 'Driver Two',
            'status': 'busy',
            'latitude': 25.29,
            'longitude': 51.54,
          },
        ]
      }));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(receivedBatches.length, 1);
      expect(receivedBatches.first.length, 2);

      // Now emit single update for driver d1 moving to on_trip
      mockChannel.emit(jsonEncode({
        'channel': 'drivers.locations',
        'data': {
          'driverId': 'd1',
          'name': 'Driver One',
          'status': 'on_trip',
          'latitude': 25.285,
          'longitude': 51.535,
          'currentTripId': 'trip-100',
        }
      }));

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(receivedBatches.length, 2);
      final latestList = receivedBatches.last;
      expect(latestList.length, 2);

      final updatedD1 = latestList.firstWhere((d) => d.id == 'd1');
      expect(updatedD1.status, 'on_trip');
      expect(updatedD1.latitude, 25.285);
      expect(updatedD1.currentTripId, 'trip-100');

      // Test fallback getDriverDetails uses cached location data if REST fails
      final driverDetailResult = await repository.getDriverDetails('d1');
      expect(driverDetailResult, isA<ApiSuccess>());
      driverDetailResult.when(
        success: (driver) {
          expect(driver.id, 'd1');
          expect(driver.name, 'Driver One');
          expect(driver.status, 'on_trip');
        },
        failure: (_) => fail('Expected cached fallback success'),
      );

      // Cleanup
      await sub.cancel();
      repository.dispose();
      wsClient.dispose();
    });
  });
}
