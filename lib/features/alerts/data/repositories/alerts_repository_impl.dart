import 'dart:async';
import '../../../../core/network/api_result.dart';
import '../../../../core/network/rest_client.dart';
import '../../../../core/network/sse/sse_client.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/repositories/alerts_repository.dart';
import '../models/alert_model.dart';

/// Implementation of AlertsRepository connecting REST endpoints and SSE streams.
class AlertsRepositoryImpl implements AlertsRepository {
  final RestClient _restClient;
  final SseClient _sseClient;

  StreamSubscription<Map<String, dynamic>>? _createdSub;
  StreamSubscription<Map<String, dynamic>>? _ackSub;

  final _alertCreatedController = StreamController<AlertEntity>.broadcast();
  final _alertAcknowledgedController =
      StreamController<AlertEntity>.broadcast();

  AlertsRepositoryImpl({
    required RestClient restClient,
    required SseClient sseClient,
  })  : _restClient = restClient,
        _sseClient = sseClient {
    _initSseListeners();
  }

  void _initSseListeners() {
    _createdSub = _sseClient.listenTo('alert.created').listen((payload) {
      final alertData = payload['alert'] ?? payload;
      if (alertData is Map<String, dynamic>) {
        final alert = AlertModel.fromJson(alertData);
        _alertCreatedController.add(alert);
      }
    });

    _ackSub = _sseClient.listenTo('alert.acknowledged').listen((payload) {
      final alertData = payload['alert'] ?? payload;
      if (alertData is Map<String, dynamic>) {
        final alert = AlertModel.fromJson(alertData);
        _alertAcknowledgedController.add(alert);
      }
    });
  }

  @override
  Stream<AlertEntity> get onAlertCreated => _alertCreatedController.stream;

  @override
  Stream<AlertEntity> get onAlertAcknowledged =>
      _alertAcknowledgedController.stream;

  @override
  Future<ApiResult<List<AlertEntity>>> fetchAlerts({
    int page = 1,
    int pageSize = 50,
  }) async {
    return _restClient.get<List<AlertEntity>>(
      '/api/alerts?page=$page&pageSize=$pageSize',
      fromJson: (dynamic json) {
        if (json is Map<String, dynamic> && json['data'] is List) {
          final list = json['data'] as List;
          return list
              .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
              .toList();
        } else if (json is List) {
          return json
              .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        return <AlertEntity>[];
      },
    );
  }

  @override
  Future<ApiResult<AlertEntity>> acknowledgeAlert(String alertId) async {
    final result = await _restClient.post<AlertEntity>(
      '/api/alerts/$alertId/acknowledge',
      body: const {},
      fromJson: (dynamic json) {
        Map<String, dynamic> data = const {};
        if (json is Map<String, dynamic>) {
          if (json['alert'] is Map<String, dynamic>) {
            data = json['alert'] as Map<String, dynamic>;
          } else {
            data = json;
          }
        }
        final parsed = AlertModel.fromJson(data);
        if (parsed.id.isEmpty) {
          return parsed.copyWith(id: alertId);
        }
        return parsed;
      },
    );

    result.when(
      success: (acknowledgedAlert) {
        // Immediate local dispatch so UI updates instantly
        _alertAcknowledgedController.add(acknowledgedAlert);
      },
      failure: (_) {},
    );

    return result;
  }

  @override
  void dispose() {
    _createdSub?.cancel();
    _ackSub?.cancel();
    _alertCreatedController.close();
    _alertAcknowledgedController.close();
  }
}
