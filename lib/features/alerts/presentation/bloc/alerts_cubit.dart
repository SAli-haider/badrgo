import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/repositories/alerts_repository.dart';
import 'alerts_state.dart';

/// ViewModel / Cubit managing real-time alerts feed and acknowledgment workflow.
class AlertsCubit extends Cubit<AlertsState> {
  final AlertsRepository _repository;
  final UserEntity _currentUser;

  StreamSubscription<AlertEntity>? _createdSub;
  StreamSubscription<AlertEntity>? _ackSub;

  AlertsCubit({
    required AlertsRepository repository,
    required UserEntity currentUser,
  })  : _repository = repository,
        _currentUser = currentUser,
        super(const AlertsInitial());

  Future<void> loadAlerts() async {
    emit(const AlertsLoading());

    // 1. Initial REST fetch (newest first)
    final result = await _repository.fetchAlerts();

    result.when(
      success: (alerts) {
        // Sort newest first
        final sorted = List<AlertEntity>.from(alerts)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final filtered = _filterAlerts(sorted, 'all', 'all');

        emit(
          AlertsLoaded(
            allAlerts: sorted,
            filteredAlerts: filtered,
          ),
        );

        // 2. Attach SSE stream listeners
        _listenToRealtimeEvents();
      },
      failure: (exception) {
        emit(AlertsError(exception.message));
      },
    );
  }

  void _listenToRealtimeEvents() {
    _createdSub?.cancel();
    _createdSub = _repository.onAlertCreated.listen(_onAlertCreated);

    _ackSub?.cancel();
    _ackSub = _repository.onAlertAcknowledged.listen(_onAlertAcknowledged);
  }

  void _onAlertCreated(AlertEntity newAlert) {
    if (state is! AlertsLoaded) return;
    final current = state as AlertsLoaded;

    final updatedAll = List<AlertEntity>.from(current.allAlerts);
    final existingIdx = updatedAll.indexWhere((a) => a.id == newAlert.id);

    if (existingIdx != -1) {
      updatedAll[existingIdx] = newAlert;
    } else {
      updatedAll.insert(0, newAlert);
    }

    final filtered = _filterAlerts(
      updatedAll,
      current.severityFilter,
      current.statusFilter,
    );

    emit(
      current.copyWith(
        allAlerts: updatedAll,
        filteredAlerts: filtered,
      ),
    );
  }

  void _onAlertAcknowledged(AlertEntity acknowledgedAlert) {
    if (state is! AlertsLoaded) return;
    final current = state as AlertsLoaded;

    final updatedAll = current.allAlerts.map((a) {
      return a.id == acknowledgedAlert.id ? acknowledgedAlert : a;
    }).toList();

    final filtered = _filterAlerts(
      updatedAll,
      current.severityFilter,
      current.statusFilter,
    );

    emit(
      current.copyWith(
        allAlerts: updatedAll,
        filteredAlerts: filtered,
      ),
    );
  }

  /// Acknowledges an alert if permitted by RBAC.
  Future<void> acknowledgeAlert(String alertId) async {
    if (state is! AlertsLoaded) return;
    final current = state as AlertsLoaded;

    // RBAC check: Must have alert:acknowledge permission
    if (!_currentUser.hasPermission('alert:acknowledge')) {
      return;
    }

    // Set acknowledging loader
    emit(
      current.copyWith(
        acknowledgingIds: {...current.acknowledgingIds, alertId},
      ),
    );

    final result = await _repository.acknowledgeAlert(alertId);

    if (state is! AlertsLoaded) return;
    final loaded = state as AlertsLoaded;

    final updatedIds =
        loaded.acknowledgingIds.where((id) => id != alertId).toSet();

    result.when(
      success: (ackAlert) {
        final updatedAll = loaded.allAlerts.map((a) {
          return a.id == ackAlert.id ? ackAlert : a;
        }).toList();

        final filtered = _filterAlerts(
          updatedAll,
          loaded.severityFilter,
          loaded.statusFilter,
        );

        emit(
          loaded.copyWith(
            allAlerts: updatedAll,
            filteredAlerts: filtered,
            acknowledgingIds: updatedIds,
          ),
        );
      },
      failure: (_) {
        emit(loaded.copyWith(acknowledgingIds: updatedIds));
      },
    );
  }

  void setSeverityFilter(String severity) {
    if (state is! AlertsLoaded) return;
    final current = state as AlertsLoaded;

    final filtered = _filterAlerts(
      current.allAlerts,
      severity,
      current.statusFilter,
    );

    emit(current.copyWith(severityFilter: severity, filteredAlerts: filtered));
  }

  void setStatusFilter(String status) {
    if (state is! AlertsLoaded) return;
    final current = state as AlertsLoaded;

    final filtered = _filterAlerts(
      current.allAlerts,
      current.severityFilter,
      status,
    );

    emit(current.copyWith(statusFilter: status, filteredAlerts: filtered));
  }

  List<AlertEntity> _filterAlerts(
    List<AlertEntity> alerts,
    String severityFilter,
    String statusFilter,
  ) {
    return alerts.where((alert) {
      // 1. Severity filter
      final matchesSeverity = switch (severityFilter.toLowerCase()) {
        'critical' => alert.isCritical,
        'warning' => alert.isWarning,
        'info' => alert.isInfo,
        _ => true,
      };

      if (!matchesSeverity) return false;

      // 2. Status filter
      final matchesStatus = switch (statusFilter.toLowerCase()) {
        'unacknowledged' || 'pending' => !alert.isAcknowledged,
        'acknowledged' => alert.isAcknowledged,
        _ => true,
      };

      return matchesStatus;
    }).toList();
  }

  @override
  Future<void> close() {
    _createdSub?.cancel();
    _ackSub?.cancel();
    return super.close();
  }
}
