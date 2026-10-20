import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/kpi_entity.dart';
import '../../domain/repositories/dashboard_repository.dart';
import 'dashboard_state.dart';

/// ViewModel for Operations Dashboard adhering strictly to Clean MVVM with BLoC:
/// - Manages UI state and permissions (`kpi:read`).
/// - Loads initial metrics via GraphQL.
/// - Keeps KPI tiles live via SSE `kpi` event stream.
/// - Handles 24h / 7d range switching with instant optimistic UI feedback.
/// - Contains ZERO UI rendering code and ZERO direct network/Dio calls.
class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repository;
  StreamSubscription<KpiEntity>? _sseSubscription;
  KpiRange _currentRange = KpiRange.last24h;

  /// In-memory cache for loaded KPI periods to provide instant 0ms switching.
  final Map<KpiRange, KpiEntity> _kpiCache = {};

  DashboardCubit({
    required DashboardRepository repository,
  })  : _repository = repository,
        super(const DashboardInitial());

  /// Loads initial KPIs with permissions check.
  Future<void> loadDashboard({
    required bool hasKpiPermission,
    KpiRange range = KpiRange.last24h,
  }) async {
    // Permission guard (M3 / RBAC): support role lacks kpi:read
    if (!hasKpiPermission) {
      emit(const DashboardRestricted());
      return;
    }

    _currentRange = range;
    emit(const DashboardLoading());

    final result = await _repository.getKpis(_currentRange);

    result.when(
      success: (kpi) {
        _kpiCache[_currentRange] = kpi;
        emit(
          DashboardLoaded(
            kpi: kpi,
            selectedRange: _currentRange,
            lastUpdated: DateTime.now(),
          ),
        );
        _startSseSubscription();
      },
      failure: (exception) {
        emit(DashboardError(exception.message));
      },
    );
  }

  /// Switches the KPI range (Last 24 Hours vs Last 7 Days).
  ///
  /// Optimistic UI Pattern:
  /// 1. Instantly highlights the selected button in UI (0ms perceived latency).
  /// 2. If cached, renders cached data immediately and refreshes in background.
  /// 3. Does NOT unmount the dashboard screen with a full-page spinner.
  Future<void> switchRange(KpiRange newRange) async {
    if (_currentRange == newRange &&
        state is DashboardLoaded &&
        !(state as DashboardLoaded).isSwitchingRange) {
      return;
    }

    _currentRange = newRange;
    final currentState = state;

    if (currentState is DashboardLoaded) {
      // If already in cache, switch instantly!
      if (_kpiCache.containsKey(newRange)) {
        emit(
          currentState.copyWith(
            kpi: _kpiCache[newRange]!,
            selectedRange: newRange,
            isSwitchingRange: false,
            lastUpdated: DateTime.now(),
          ),
        );
      } else {
        // Optimistically update selection indicator immediately without wiping screen
        emit(
          currentState.copyWith(
            selectedRange: newRange,
            isSwitchingRange: true,
          ),
        );
      }
    }

    final result = await _repository.getKpis(newRange);

    result.when(
      success: (kpi) {
        _kpiCache[newRange] = kpi;
        // Only apply if user is still on this range
        if (_currentRange == newRange) {
          emit(
            DashboardLoaded(
              kpi: kpi,
              selectedRange: newRange,
              isSwitchingRange: false,
              lastUpdated: DateTime.now(),
            ),
          );
        }
      },
      failure: (exception) {
        if (state is DashboardLoaded) {
          emit((state as DashboardLoaded).copyWith(isSwitchingRange: false));
        } else {
          emit(DashboardError(exception.message));
        }
      },
    );
  }

  /// Listens to live SSE `kpi` event stream and updates state reactively.
  ///
  /// Note: Backend SSE pushes 24-hour live simulator ticks.
  /// When user is viewing Last 7 Days, SSE updates the 24h cache without
  /// corrupting the 7-day display.
  void _startSseSubscription() {
    _sseSubscription?.cancel();
    _sseSubscription = _repository.subscribeKpiUpdates().listen(
      (liveKpi) {
        // Always keep 24h cache up to date
        _kpiCache[KpiRange.last24h] = liveKpi;

        final currentState = state;
        if (currentState is DashboardLoaded) {
          // Only update UI reactively if user is currently viewing Last 24 Hours
          if (_currentRange == KpiRange.last24h) {
            final mergedSeries = liveKpi.series.isNotEmpty
                ? liveKpi.series
                : currentState.kpi.series;

            final updatedKpi = liveKpi.copyWith(
              range: KpiRange.last24h,
              series: mergedSeries,
            );

            emit(
              currentState.copyWith(
                kpi: updatedKpi,
                isLivePulse: true,
                lastUpdated: DateTime.now(),
              ),
            );
          }
        }
      },
      onError: (_) {
        // Realtime stream errors do not destroy existing loaded data
      },
    );
  }

  @override
  Future<void> close() {
    _sseSubscription?.cancel();
    return super.close();
  }
}
