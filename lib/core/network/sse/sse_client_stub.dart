import 'dart:async';
import '../network_event_bus.dart';
import 'sse_client.dart';
import 'sse_ready_event.dart';

/// In-memory stub implementation of SseClient for VM / unit testing.
class SseClientStub implements SseClient {
  final NetworkEventBus? eventBus;
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  final StreamController<SseReadyEvent> _readyController =
      StreamController<SseReadyEvent>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  bool _connected = false;
  String? _lastId;

  SseClientStub({this.eventBus});

  @override
  bool get isConnected => _connected;

  @override
  String? get lastEventId => _lastId;

  @override
  Stream<bool> get onConnectionState => _connectionStateController.stream;

  @override
  Stream<SseReadyEvent> get onReady => _readyController.stream;

  @override
  void connect(String token, {String? lastEventId}) {
    _connected = true;
    _lastId = lastEventId;
    _connectionStateController.add(true);
    _readyController.add(const SseReadyEvent(
      topics: ['kpi', 'alerts', 'trips', 'drivers'],
      deniedTopics: [],
    ));
  }

  @override
  void disconnect() {
    _connected = false;
    _connectionStateController.add(false);
  }

  @override
  Stream<Map<String, dynamic>> listenTo(String eventName) {
    return _controllers
        .putIfAbsent(
          eventName,
          () => StreamController<Map<String, dynamic>>.broadcast(),
        )
        .stream;
  }

  /// Test helper to simulate incoming SSE events.
  void simulateEvent(String eventName, Map<String, dynamic> data, {String? id}) {
    if (id != null) _lastId = id;
    if (_controllers.containsKey(eventName)) {
      _controllers[eventName]?.add(data);
    }
  }

  /// Test helper to simulate ready event.
  void simulateReady(SseReadyEvent event) {
    _readyController.add(event);
  }
}

SseClient getSseClientImpl({NetworkEventBus? eventBus}) =>
    SseClientStub(eventBus: eventBus);
