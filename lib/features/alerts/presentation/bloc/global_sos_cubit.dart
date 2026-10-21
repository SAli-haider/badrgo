import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/alert_entity.dart';
import '../../domain/repositories/alerts_repository.dart';
import 'global_sos_state.dart';

/// App-wide BLoC/Cubit ensuring critical SOS emergencies are instantly surfaced
/// regardless of the current active route or tab.
class GlobalSosCubit extends Cubit<GlobalSosState> {
  final AlertsRepository _repository;

  StreamSubscription<AlertEntity>? _createdSub;
  StreamSubscription<AlertEntity>? _ackSub;

  GlobalSosCubit({required AlertsRepository repository})
      : _repository = repository,
        super(const GlobalSosState());

  /// Starts listening and fetches existing critical alerts when user is Authenticated.
  Future<void> start() async {
    // 1. Initial fetch to detect any existing unacknowledged SOS alerts
    final result = await _repository.fetchAlerts(pageSize: 50);
    result.when(
      success: (alerts) {
        final criticals = alerts
            .where((a) => a.isCritical && !a.isAcknowledged)
            .toList();

        emit(state.copyWith(activeCriticalAlerts: criticals));
      },
      failure: (_) {},
    );

    // 2. Real-time SSE subscriptions
    _createdSub?.cancel();
    _createdSub = _repository.onAlertCreated.listen((alert) {
      if (alert.isCritical && !alert.isAcknowledged) {
        final updated = List<AlertEntity>.from(state.activeCriticalAlerts);
        final idx = updated.indexWhere((a) => a.id == alert.id);
        if (idx != -1) {
          updated[idx] = alert;
        } else {
          updated.insert(0, alert);
        }

        // When a new emergency arrives, wake up the banner and remove from dismissed
        final updatedDismissed =
            state.dismissedIds.where((id) => id != alert.id).toSet();

        emit(
          state.copyWith(
            activeCriticalAlerts: updated,
            dismissedIds: updatedDismissed,
            isBannerDismissed: false,
          ),
        );
      }
    });

    _ackSub?.cancel();
    _ackSub = _repository.onAlertAcknowledged.listen((alert) {
      final updated = state.activeCriticalAlerts
          .where((a) => a.id != alert.id)
          .toList();
      emit(state.copyWith(activeCriticalAlerts: updated));
    });
  }

  /// Stops tracking and clears all critical alerts when user logs out.
  void stop() {
    _createdSub?.cancel();
    _createdSub = null;
    _ackSub?.cancel();
    _ackSub = null;
    emit(const GlobalSosState());
  }

  /// Closes the top banner completely. The banner stays hidden until a new critical alert arrives via SSE.
  void dismissBanner() {
    final allCurrentIds = state.activeCriticalAlerts.map((a) => a.id).toSet();
    emit(
      state.copyWith(
        isBannerDismissed: true,
        dismissedIds: {...state.dismissedIds, ...allCurrentIds},
        currentIndex: 0,
      ),
    );
  }

  /// Dismisses a single alert from the view.
  void dismissAlert(String alertId) {
    emit(state.copyWith(dismissedIds: {...state.dismissedIds, alertId}));
  }

  /// Navigates to the next SOS alert if multiple exist.
  void nextAlert() {
    final count = state.visibleAlerts.length;
    if (count <= 1) return;
    final nextIdx = (state.currentIndex + 1) % count;
    emit(state.copyWith(currentIndex: nextIdx));
  }

  /// Navigates to the previous SOS alert if multiple exist.
  void prevAlert() {
    final count = state.visibleAlerts.length;
    if (count <= 1) return;
    final prevIdx = (state.currentIndex - 1 + count) % count;
    emit(state.copyWith(currentIndex: prevIdx));
  }

  /// One-click acknowledge from global banner with optimistic removal.
  Future<void> acknowledgeSos(String alertId) async {
    // 1. Optimistic removal so UI updates instantly
    final optimisticAlerts =
        state.activeCriticalAlerts.where((a) => a.id != alertId).toList();

    emit(
      state.copyWith(
        activeCriticalAlerts: optimisticAlerts,
        acknowledgingIds: {...state.acknowledgingIds, alertId},
      ),
    );

    final result = await _repository.acknowledgeAlert(alertId);

    final updatedAcknowledging =
        state.acknowledgingIds.where((id) => id != alertId).toSet();

    result.when(
      success: (ackAlert) {
        final ackId = ackAlert.id.isNotEmpty ? ackAlert.id : alertId;
        final updated = state.activeCriticalAlerts
            .where((a) => a.id != ackId && a.id != alertId)
            .toList();
        emit(
          state.copyWith(
            activeCriticalAlerts: updated,
            acknowledgingIds: updatedAcknowledging,
          ),
        );
      },
      failure: (_) {
        emit(state.copyWith(acknowledgingIds: updatedAcknowledging));
      },
    );
  }

  @override
  Future<void> close() {
    _createdSub?.cancel();
    _ackSub?.cancel();
    return super.close();
  }
}
