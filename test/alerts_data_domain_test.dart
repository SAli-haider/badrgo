import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:badrgo_ops_console/core/network/rest_client.dart';
import 'package:badrgo_ops_console/core/network/sse/sse_client.dart';
import 'package:badrgo_ops_console/core/network/sse/sse_ready_event.dart';
import 'package:badrgo_ops_console/features/alerts/data/models/alert_model.dart';
import 'package:badrgo_ops_console/features/alerts/data/repositories/alerts_repository_impl.dart';
import 'package:badrgo_ops_console/features/alerts/domain/entities/alert_entity.dart';

class _MockSseClient implements SseClient {
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};

  void emitEvent(String eventName, Map<String, dynamic> data) {
    if (_controllers.containsKey(eventName)) {
      _controllers[eventName]!.add(data);
    }
  }

  @override
  Stream<Map<String, dynamic>> listenTo(String eventName) {
    if (!_controllers.containsKey(eventName)) {
      _controllers[eventName] =
          StreamController<Map<String, dynamic>>.broadcast();
    }
    return _controllers[eventName]!.stream;
  }

  @override
  void connect(String token, {String? lastEventId}) {}

  @override
  void disconnect() {}

  @override
  bool get isConnected => true;

  @override
  String? get lastEventId => null;

  @override
  Stream<bool> get onConnectionState => const Stream.empty();

  @override
  Stream<SseReadyEvent> get onReady => const Stream.empty();

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}

void main() {
  group('Part 6.1 & 6.2: AlertModel Deserialization Tests', () {
    test('parses critical SOS alert with null acknowledged status', () {
      final json = {
        'id': 'alt-100',
        'cityId': 'city_doh',
        'type': 'sos',
        'severity': 'critical',
        'message': 'Driver triggered SOS emergency on West Bay route',
        'tripId': 'trip-555',
        'driverId': 'drv-999',
        'createdAt': '2026-10-21T10:00:00.000Z',
        'acknowledgedAt': null,
        'acknowledgedBy': null,
      };

      final alert = AlertModel.fromJson(json);

      expect(alert.id, 'alt-100');
      expect(alert.cityId, 'city_doh');
      expect(alert.type, AlertType.sos);
      expect(alert.severity, AlertSeverity.critical);
      expect(alert.isCritical, isTrue);
      expect(alert.isAcknowledged, isFalse);
      expect(alert.tripId, 'trip-555');
      expect(alert.driverId, 'drv-999');
    });

    test('parses acknowledged warning alert with timestamp & operator', () {
      final json = {
        'id': 'alt-200',
        'cityId': 'city_ray',
        'type': 'high_demand',
        'severity': 'warning',
        'message': 'Surge demand detected in Education City',
        'createdAt': '2026-10-21T09:00:00.000Z',
        'acknowledgedAt': '2026-10-21T09:15:00.000Z',
        'acknowledgedBy': 'usr-ops-manager',
      };

      final alert = AlertModel.fromJson(json);

      expect(alert.id, 'alt-200');
      expect(alert.type, AlertType.highDemand);
      expect(alert.severity, AlertSeverity.warning);
      expect(alert.isCritical, isFalse);
      expect(alert.isWarning, isTrue);
      expect(alert.isAcknowledged, isTrue);
      expect(alert.acknowledgedBy, 'usr-ops-manager');
      expect(alert.acknowledgedAt, isNotNull);
    });
  });

  group('Part 6.2: AlertsRepositoryImpl SSE Integration Tests', () {
    test('listens to SSE alert.created and alert.acknowledged and emits models', () async {
      final mockSse = _MockSseClient();
      final restClient = RestClient();
      final repository = AlertsRepositoryImpl(
        restClient: restClient,
        sseClient: mockSse,
      );

      final createdAlerts = <AlertEntity>[];
      final createdSub = repository.onAlertCreated.listen(createdAlerts.add);

      final ackAlerts = <AlertEntity>[];
      final ackSub = repository.onAlertAcknowledged.listen(ackAlerts.add);

      // 1. Emit live SSE alert.created event
      mockSse.emitEvent('alert.created', {
        'alert': {
          'id': 'alt-301',
          'cityId': 'city_doh',
          'type': 'sos',
          'severity': 'critical',
          'message': 'SOS: Immediate assistance required',
          'createdAt': '2026-10-21T11:00:00.000Z',
        }
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(createdAlerts.length, 1);
      expect(createdAlerts.first.id, 'alt-301');
      expect(createdAlerts.first.isCritical, isTrue);

      // 2. Emit live SSE alert.acknowledged event
      mockSse.emitEvent('alert.acknowledged', {
        'alert': {
          'id': 'alt-301',
          'cityId': 'city_doh',
          'type': 'sos',
          'severity': 'critical',
          'message': 'SOS: Immediate assistance required',
          'createdAt': '2026-10-21T11:00:00.000Z',
          'acknowledgedAt': '2026-10-21T11:05:00.000Z',
          'acknowledgedBy': 'dispatch.doha@demo.test',
        }
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(ackAlerts.length, 1);
      expect(ackAlerts.first.id, 'alt-301');
      expect(ackAlerts.first.isAcknowledged, isTrue);
      expect(ackAlerts.first.acknowledgedBy, 'dispatch.doha@demo.test');

      await createdSub.cancel();
      await ackSub.cancel();
      repository.dispose();
      mockSse.dispose();
    });
  });
}
