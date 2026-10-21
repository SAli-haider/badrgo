import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/network/ws/ws_connection_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../../../core/widgets/ops_error_view.dart';
import '../../../../core/widgets/ops_loading_indicator.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/driver_location_entity.dart';
import '../../domain/repositories/map_repository.dart';
import '../bloc/live_map_cubit.dart';
import '../bloc/live_map_state.dart';
import 'driver_detail_card.dart';

/// Live Driver Map Screen (M5).
///
/// Complies strictly with assessment requirements:
/// - "Drivers from the WebSocket drivers.locations channel on a map, colour-coded by status"
/// - "Clicking a driver shows their details and current trip"
/// - "The WebSocket reconnects with backoff and subscribes again. Show a visible reconnecting state."
/// - "Needs driver:track permission" (Graceful restricted fallback for roles like Support)
class LiveMapScreen extends StatelessWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;
    final token = authState is Authenticated ? authState.token : '';

    return BlocProvider(
      create: (ctx) => LiveMapCubit(
        repository: ctx.read<MapRepository>(),
        currentUser: user ??
            const UserEntity(
              id: '',
              name: 'Operator',
              email: '',
              role: 'unknown',
              city: 'Doha',
              permissions: [],
            ),
        token: token,
      ),
      child: const _LiveMapView(),
    );
  }
}

class _LiveMapView extends StatefulWidget {
  const _LiveMapView();

  @override
  State<_LiveMapView> createState() => _LiveMapViewState();
}

class _LiveMapViewState extends State<_LiveMapView> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize live WebSocket tracking on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveMapCubit>().initTracking();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveMapCubit, LiveMapState>(
      builder: (context, state) {
        if (state is LiveMapRestricted) {
          return _buildRestrictedView(state.requiredPermission);
        }

        if (state is LiveMapLoading || state is LiveMapInitial) {
          return const Center(child: OpsLoadingIndicator());
        }

        if (state is LiveMapError) {
          return Center(
            child: OpsErrorView(
              message: state.message,
              onRetry: () => context.read<LiveMapCubit>().initTracking(),
            ),
          );
        }

        if (state is LiveMapLoaded) {
          return _buildLoadedMap(context, state);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRestrictedView(String requiredPermission) {
    return Center(
      child: OpsCard(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_outlined,
                  size: 48,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Live Map Restricted',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your account role lacks the required "$requiredPermission" permission to track live fleet telemetry. Please contact operations if you need tracking access.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              OpsBadge(
                label: 'Required Permission: $requiredPermission',
                color: AppColors.warning,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadedMap(BuildContext context, LiveMapLoaded state) {
    final cubit = context.read<LiveMapCubit>();
    final authState = context.read<AuthCubit>().state;
    final isViewer = authState is Authenticated && authState.user.isViewer;

    return Stack(
      children: [
        // 1. OpenStreetMap Tile & Marker Layers
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(state.centerLat, state.centerLng),
            initialZoom: state.currentZoom,
            minZoom: 9.0,
            maxZoom: 18.0,
            onTap: (_, _) => cubit.selectDriver(null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.badrgo.ops_console',
            ),
            MarkerLayer(
              markers: state.filteredDrivers.map((driver) {
                final isSelected = state.selectedDriver?.id == driver.id;
                return Marker(
                  point: LatLng(driver.latitude, driver.longitude),
                  width: isSelected ? 48 : 38,
                  height: isSelected ? 48 : 38,
                  child: _buildDriverMarker(driver, isSelected, () {
                    cubit.selectDriver(driver);
                  }),
                );
              }).toList(),
            ),
          ],
        ),

        // 2. Top Controls Overlay: Filter Bar, Search, Quick Centering & Reconnect Pill
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OpsCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Status Filter Chips
                    _buildFilterChip(
                      label: 'All (${state.totalCount})',
                      isSelected: state.statusFilter == 'all',
                      color: AppColors.primary,
                      onTap: () => cubit.setFilter('all'),
                    ),
                    _buildFilterChip(
                      label: 'Available (${state.availableCount})',
                      isSelected: state.statusFilter == 'available',
                      color: AppColors.success,
                      onTap: () => cubit.setFilter('available'),
                    ),
                    _buildFilterChip(
                      label: 'On Trip (${state.onTripCount})',
                      isSelected: state.statusFilter == 'on_trip',
                      color: AppColors.info,
                      onTap: () => cubit.setFilter('on_trip'),
                    ),
                    _buildFilterChip(
                      label: 'Busy (${state.busyCount})',
                      isSelected: state.statusFilter == 'busy',
                      color: AppColors.warning,
                      onTap: () => cubit.setFilter('busy'),
                    ),

                    // Quick Search Box
                    SizedBox(
                      width: 200,
                      height: 34,
                      child: TextField(
                        controller: _searchController,
                        onChanged: cubit.setSearch,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search driver or vehicle...',
                          hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 14, color: AppColors.textSecondary),
                                  onPressed: () {
                                    _searchController.clear();
                                    cubit.setSearch('');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                    ),

                    // City Quick-Centering Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCityButton('Doha', 25.2867, 51.5333, cubit),
                        const SizedBox(width: 4),
                        _buildCityButton('Al Rayyan', 25.2919, 51.4244, cubit),
                        const SizedBox(width: 4),
                        _buildCityButton('Al Wakrah', 25.1768, 51.6048, cubit),
                      ],
                    ),

                    // Live WebSocket Reconnection State Pill
                    _buildConnectionBadge(state.connectionState, state.secondsRemaining),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 3. Floating Driver Detail Card (Bottom Left/Right)
        if (state.selectedDriver != null)
          Positioned(
            bottom: 24,
            right: 24,
            child: DriverDetailCard(
              driver: state.selectedDriver!,
              driverDetail: state.selectedDriverDetail,
              activeTrip: state.selectedDriverTrip,
              isLoadingDetail: state.isLoadingDetail,
              isViewer: isViewer,
              onClose: () => cubit.selectDriver(null),
            ),
          ),
      ],
    );
  }

  Widget _buildDriverMarker(
    DriverLocationEntity driver,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final statusColor = AppColors.forDriverStatus(driver.status);
    final heading = driver.heading ?? 0.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : statusColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: isSelected ? 0.8 : 0.4),
              blurRadius: isSelected ? 12 : 6,
              spreadRadius: isSelected ? 3 : 1,
            ),
          ],
          border: Border.all(
            color: isSelected ? statusColor : Colors.white,
            width: isSelected ? 3 : 2,
          ),
        ),
        child: Center(
          child: Transform.rotate(
            angle: heading * (math.pi / 180),
            child: Icon(
              Icons.navigation,
              size: isSelected ? 24 : 18,
              color: isSelected ? statusColor : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCityButton(
    String city,
    double lat,
    double lng,
    LiveMapCubit cubit,
  ) {
    return ActionChip(
      label: Text(city, style: const TextStyle(fontSize: 11)),
      avatar: const Icon(Icons.location_city, size: 14, color: AppColors.textSecondary),
      backgroundColor: AppColors.surface,
      side: const BorderSide(color: AppColors.border),
      padding: EdgeInsets.zero,
      onPressed: () {
        _mapController.move(LatLng(lat, lng), 12.5);
        cubit.recenter(lat, lng, zoom: 12.5);
      },
    );
  }

  Widget _buildConnectionBadge(
    WsConnectionState connState,
    int? secondsRemaining,
  ) {
    return switch (connState) {
      WsConnectionState.connected => const OpsBadge(
          label: 'Live (WS)',
          color: AppColors.success,
        ),
      WsConnectionState.reconnecting => OpsBadge(
          label: secondsRemaining != null
              ? 'Reconnecting in ${secondsRemaining}s...'
              : 'Reconnecting...',
          color: AppColors.warning,
        ),
      WsConnectionState.connecting => const OpsBadge(
          label: 'Connecting...',
          color: AppColors.info,
        ),
      WsConnectionState.disconnected => const OpsBadge(
          label: 'Offline',
          color: AppColors.muted,
        ),
      WsConnectionState.error => const OpsBadge(
          label: 'Connection Error',
          color: AppColors.error,
        ),
    };
  }
}
