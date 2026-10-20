import 'package:equatable/equatable.dart';
import '../../domain/entities/kpi_entity.dart';

/// State representation for Dashboard operations adhering to MVVM.
abstract class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => [];
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final KpiEntity kpi;
  final KpiRange selectedRange;
  final bool isLivePulse;
  final bool isSwitchingRange;
  final DateTime lastUpdated;

  const DashboardLoaded({
    required this.kpi,
    this.selectedRange = KpiRange.last24h,
    this.isLivePulse = false,
    this.isSwitchingRange = false,
    required this.lastUpdated,
  });

  DashboardLoaded copyWith({
    KpiEntity? kpi,
    KpiRange? selectedRange,
    bool? isLivePulse,
    bool? isSwitchingRange,
    DateTime? lastUpdated,
  }) {
    return DashboardLoaded(
      kpi: kpi ?? this.kpi,
      selectedRange: selectedRange ?? this.selectedRange,
      isLivePulse: isLivePulse ?? this.isLivePulse,
      isSwitchingRange: isSwitchingRange ?? this.isSwitchingRange,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        kpi,
        selectedRange,
        isLivePulse,
        isSwitchingRange,
        lastUpdated,
      ];
}

class DashboardError extends DashboardState {
  final String message;

  const DashboardError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Fallback state when active operator lacks `kpi:read` permission (e.g. support role).
class DashboardRestricted extends DashboardState {
  final String message;

  const DashboardRestricted({
    this.message = 'Access Restricted: You do not have permission to view operations KPIs (kpi:read required).',
  });

  @override
  List<Object?> get props => [message];
}
