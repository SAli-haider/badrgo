import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../config/app_config.dart';
import '../../errors/app_exception.dart';
import '../../errors/error_code.dart';
import '../network_event_bus.dart';
import 'sse_client.dart';
import 'sse_ready_event.dart';

/// Web implementation of SSE Client using `package:web` EventSource.
///
/// Adheres strictly to requirements:
/// - "For SSE on Flutter web, use package:web EventSource"
/// - "Browsers cannot set headers on EventSource or WebSocket, so pass `?token=<token>`"
/// - "SSE events: ready, kpi, alert.created, alert.acknowledged, trip.created, trip.updated"
class SseClientWeb implements SseClient {
  final NetworkEventBus? eventBus;
  web.EventSource? _eventSource;
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  final StreamController<SseReadyEvent> _readyController =
      StreamController<SseReadyEvent>.broadcast();
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  bool _connected = false;
  String? _lastId;

  SseClientWeb({this.eventBus});

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
    if (_eventSource != null) {
      disconnect();
    }

    _lastId = lastEventId;
    final url = AppConfig.buildSseUrl(token, lastEventId: lastEventId);

    try {
      final es = web.EventSource(url);
      _eventSource = es;

      es.onopen = ((web.Event _) {
        _connected = true;
        _connectionStateController.add(true);
      }).toJS;

      es.onerror = ((web.Event _) {
        _connected = false;
        _connectionStateController.add(false);
      }).toJS;

      // Register listener for initial `ready` event
      _registerRawListener(es, 'ready', (data) {
        final readyEvent = SseReadyEvent.fromJson(data);
        _readyController.add(readyEvent);
      });

      // Re-register any active topic listeners
      for (final eventName in _controllers.keys) {
        _registerRawListener(es, eventName, (data) {
          _controllers[eventName]?.add(data);
        });
      }
    } catch (_) {
      _connected = false;
      _connectionStateController.add(false);
    }
  }

  void _registerRawListener(
    web.EventSource es,
    String eventName,
    void Function(Map<String, dynamic> data) onData,
  ) {
    es.addEventListener(
      eventName,
      ((web.MessageEvent event) {
        try {
          final id = event.lastEventId;
          if (id.isNotEmpty) {
            _lastId = id;
          }

          final rawData = event.data;
          final dartString = rawData.dartify()?.toString();
          if (dartString != null && dartString.isNotEmpty) {
            final decoded = jsonDecode(dartString);
            if (decoded is Map<String, dynamic>) {
              // Check for SSE error payload
              if (decoded.containsKey('error') && decoded['error'] is Map) {
                final errMap = decoded['error'] as Map<String, dynamic>;
                final codeStr = errMap['code']?.toString() ?? '';
                if (codeStr == 'UNAUTHENTICATED') {
                  eventBus?.onUnauthorized(
                    AppException(
                      code: ErrorCode.unauthenticated,
                      message: errMap['message']?.toString() ?? 'Unauthorized SSE',
                      statusCode: 401,
                    ),
                  );
                  return;
                }
              }

              onData(decoded);
            }
          }
        } catch (_) {}
      }).toJS,
    );
  }

  @override
  Stream<Map<String, dynamic>> listenTo(String eventName) {
    final controller = _controllers.putIfAbsent(
      eventName,
      () {
        final ctrl = StreamController<Map<String, dynamic>>.broadcast();
        // If eventSource is already open, attach the listener
        if (_eventSource != null) {
          _registerRawListener(_eventSource!, eventName, (data) {
            ctrl.add(data);
          });
        }
        return ctrl;
      },
    );

    return controller.stream;
  }

  @override
  void disconnect() {
    _connected = false;
    _connectionStateController.add(false);
    try {
      _eventSource?.close();
    } catch (_) {}
    _eventSource = null;
  }
}

SseClient getSseClientImpl({NetworkEventBus? eventBus}) =>
    SseClientWeb(eventBus: eventBus);
