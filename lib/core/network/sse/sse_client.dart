import '../network_event_bus.dart';
import 'sse_ready_event.dart';
import 'sse_client_stub.dart'
    if (dart.library.js_interop) 'sse_client_web.dart';

/// Abstract contract for Server-Sent Events (SSE) Client.
///
/// Automatically resolves to:
/// - `SseClientWeb` (browser EventSource via package:web) in Web runtime.
/// - `SseClientStub` (in-memory simulator) in VM and unit test runtime.
///
/// Adheres strictly to requirements:
/// - TR-3: "SSE (/api/events): Live KPI tiles, alerts feed, live updates to trip list. Pass `?token=<token>`."
/// - "For SSE on Flutter web, use package:web EventSource"
abstract class SseClient {
  /// Connects to the SSE endpoint with query parameter `?token=<token>`.
  void connect(String token, {String? lastEventId});

  /// Disconnects the active EventSource and marks connection closed.
  void disconnect();

  /// Listens to a named SSE event (e.g. 'kpi', 'alert.created', 'trip.created').
  Stream<Map<String, dynamic>> listenTo(String eventName);

  /// Stream of initial `ready` handshake event payload with deniedTopics.
  Stream<SseReadyEvent> get onReady;

  /// Stream of connection state changes (true = open, false = closed/reconnecting).
  Stream<bool> get onConnectionState;

  /// Current connection state.
  bool get isConnected;

  /// Last received Event ID for reconnect resumption.
  String? get lastEventId;

  factory SseClient({NetworkEventBus? eventBus}) =>
      getSseClientImpl(eventBus: eventBus);
}
