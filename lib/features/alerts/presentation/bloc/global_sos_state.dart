import 'package:equatable/equatable.dart';
import '../../domain/entities/alert_entity.dart';

/// State representing active unacknowledged critical SOS emergencies
/// across the entire app workspace.
class GlobalSosState extends Equatable {
  final List<AlertEntity> activeCriticalAlerts;
  final Set<String> dismissedIds;
  final Set<String> acknowledgingIds;
  final bool isBannerDismissed;
  final int currentIndex;

  const GlobalSosState({
    this.activeCriticalAlerts = const [],
    this.dismissedIds = const {},
    this.acknowledgingIds = const {},
    this.isBannerDismissed = false,
    this.currentIndex = 0,
  });

  /// Visible active critical alerts that haven't been dismissed by the operator individually.
  List<AlertEntity> get visibleAlerts => activeCriticalAlerts
      .where((a) => !dismissedIds.contains(a.id) && !a.isAcknowledged)
      .toList();

  /// Whether the top SOS emergency banner should show.
  /// If the operator dismissed the banner (`isBannerDismissed == true`), it stays hidden.
  bool get hasActiveSos => !isBannerDismissed && visibleAlerts.isNotEmpty;

  /// The currently viewed critical alert in the banner.
  AlertEntity? get latestSos {
    if (visibleAlerts.isEmpty) return null;
    final safeIndex = (currentIndex < visibleAlerts.length && currentIndex >= 0)
        ? currentIndex
        : 0;
    return visibleAlerts[safeIndex];
  }

  GlobalSosState copyWith({
    List<AlertEntity>? activeCriticalAlerts,
    Set<String>? dismissedIds,
    Set<String>? acknowledgingIds,
    bool? isBannerDismissed,
    int? currentIndex,
  }) {
    return GlobalSosState(
      activeCriticalAlerts: activeCriticalAlerts ?? this.activeCriticalAlerts,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      acknowledgingIds: acknowledgingIds ?? this.acknowledgingIds,
      isBannerDismissed: isBannerDismissed ?? this.isBannerDismissed,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }

  @override
  List<Object?> get props => [
        activeCriticalAlerts,
        dismissedIds,
        acknowledgingIds,
        isBannerDismissed,
        currentIndex,
      ];
}
