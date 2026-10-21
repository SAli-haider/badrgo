import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/phone_masker.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../../../core/widgets/ops_error_view.dart';
import '../../../../core/widgets/ops_loading_indicator.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../bloc/health_cubit.dart';
import '../bloc/health_state.dart';

/// Pure View conforming strictly to Clean MVVM with BLoC:
/// - Renders UI state from HealthCubit.
/// - Sends events (checkHealth) to HealthCubit.
/// - ZERO API calls or transport logic in the widget.
class Phase0Screen extends StatelessWidget {
  const Phase0Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.local_taxi_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'badrgo Ops Console — Clean MVVM Foundation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: BlocBuilder<HealthCubit, HealthState>(
                builder: (context, state) {
                  return switch (state) {
                    HealthInitial() || HealthLoading() => const OpsBadge(
                        label: 'CONNECTING...',
                        color: AppColors.warning,
                      ),
                    HealthLoaded() => const OpsBadge(
                        label: 'API ONLINE (200 OK)',
                        color: AppColors.success,
                      ),
                    HealthError() => const OpsBadge(
                        label: 'API OFFLINE',
                        color: AppColors.error,
                      ),
                  };
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.muted),
            tooltip: 'Sign Out (Revoke Token)',
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Health Status via ViewModel (Clean MVVM with BLoC)
            OpsCard(
              title: '1. Live Sandbox Health via Clean Architecture',
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                tooltip: 'Trigger checkHealth() in ViewModel',
                onPressed: () => context.read<HealthCubit>().checkHealth(),
              ),
              child: BlocBuilder<HealthCubit, HealthState>(
                builder: (context, state) {
                  return switch (state) {
                    HealthInitial() || HealthLoading() => const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: OpsLoadingIndicator(
                          message: 'Calling HealthRepository via HealthCubit...',
                        ),
                      ),
                    HealthLoaded(health: final h) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow('Status', h.isOk ? 'HEALTHY (ok: true)' : 'DEGRADED'),
                          _infoRow('Simulator Active', '${h.simulatorActive}'),
                          _infoRow('Open SSE Streams', '${h.openStreams}'),
                          _infoRow('Open WebSockets', '${h.openSockets}'),
                          _infoRow('Server Time', h.time),
                        ],
                      ),
                    HealthError(message: final err) => OpsErrorView(
                        message: 'Health Check Failed: $err',
                        onRetry: () => context.read<HealthCubit>().checkHealth(),
                      ),
                  };
                },
              ),
            ),
            const SizedBox(height: 20),

            // 2. API & Environment Configuration
            OpsCard(
              title: '2. API & Environment Configuration',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Base REST/GraphQL URL', AppConfig.baseUrl),
                  _infoRow('WebSocket Base URL', AppConfig.baseWsUrl),
                  _infoRow('SSE Events Endpoint', '${AppConfig.baseUrl}${AppConfig.sseEndpoint}'),
                  _infoRow('Config Flag', '--dart-define=API_URL=...'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Reusable Status Badges (OpsBadge)
            OpsCard(
              title: '3. Reusable Status Badges (OpsBadge)',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OpsBadge(label: 'Available', color: AppColors.forDriverStatus('available')),
                  OpsBadge(label: 'On Trip', color: AppColors.forDriverStatus('on_trip')),
                  OpsBadge(label: 'Busy', color: AppColors.forDriverStatus('busy')),
                  OpsBadge(label: 'Offline', color: AppColors.forDriverStatus('offline')),
                  OpsBadge(label: 'Completed', color: AppColors.forTripStatus('completed')),
                  OpsBadge(label: 'Active', color: AppColors.forTripStatus('active')),
                  OpsBadge(label: 'Cancelled', color: AppColors.forTripStatus('cancelled')),
                  OpsBadge(
                    label: 'Critical SOS',
                    color: AppColors.forAlertSeverity('critical'),
                    icon: Icons.warning_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Reusable Formatters (DRY Utilities)
            OpsCard(
              title: '4. Reusable Formatters (DRY Utilities)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Currency Formatter (Standard)', CurrencyFormatter.format(12450.75, 'QAR')),
                  _infoRow('Currency Formatter (Compact)', CurrencyFormatter.formatCompact(1500000, 'QAR')),
                  _infoRow('Phone Masking (Viewer: true)', PhoneMasker.mask('+97455123456', shouldMask: true)),
                  _infoRow('Phone Masking (Viewer: false)', PhoneMasker.mask('+97455123456', shouldMask: false)),
                  _infoRow('Date Formatter (Full)', DateFormatter.formatFull(DateTime.now())),
                  _infoRow('Duration Formatter (Downtime)', DateFormatter.formatDuration(const Duration(minutes: 14, seconds: 32))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
