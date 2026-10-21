import 'package:equatable/equatable.dart';
import '../../domain/entities/alert_entity.dart';

/// State representation for Alerts feed module.
abstract class AlertsState extends Equatable {
  const AlertsState();

  @override
  List<Object?> get props => [];
}

class AlertsInitial extends AlertsState {
  const AlertsInitial();
}

class AlertsLoading extends AlertsState {
  const AlertsLoading();
}

class AlertsLoaded extends AlertsState {
  final List<AlertEntity> allAlerts;
  final List<AlertEntity> filteredAlerts;
  final String severityFilter; // 'all', 'critical', 'warning', 'info'
  final String statusFilter; // 'all', 'unacknowledged', 'acknowledged'
  final Set<String> acknowledgingIds;

  const AlertsLoaded({
    required this.allAlerts,
    required this.filteredAlerts,
    this.severityFilter = 'all',
    this.statusFilter = 'all',
    this.acknowledgingIds = const {},
  });

  int get criticalCount => allAlerts.where((a) => a.isCritical).length;
  int get warningCount => allAlerts.where((a) => a.isWarning).length;
  int get infoCount => allAlerts.where((a) => a.isInfo).length;
  int get unacknowledgedCount =>
      allAlerts.where((a) => !a.isAcknowledged).length;
  int get totalCount => allAlerts.length;

  AlertsLoaded copyWith({
    List<AlertEntity>? allAlerts,
    List<AlertEntity>? filteredAlerts,
    String? severityFilter,
    String? statusFilter,
    Set<String>? acknowledgingIds,
  }) {
    return AlertsLoaded(
      allAlerts: allAlerts ?? this.allAlerts,
      filteredAlerts: filteredAlerts ?? this.filteredAlerts,
      severityFilter: severityFilter ?? this.severityFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      acknowledgingIds: acknowledgingIds ?? this.acknowledgingIds,
    );
  }

  @override
  List<Object?> get props => [
        allAlerts,
        filteredAlerts,
        severityFilter,
        statusFilter,
        acknowledgingIds,
      ];
}

class AlertsError extends AlertsState {
  final String message;

  const AlertsError(this.message);

  @override
  List<Object?> get props => [message];
}
