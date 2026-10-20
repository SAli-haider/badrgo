import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ops_card.dart';
import '../../../../core/widgets/ops_error_view.dart';
import '../../../../core/widgets/ops_loading_indicator.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/trip_entity.dart';
import '../../domain/repositories/trips_repository.dart';
import '../bloc/trip_action_cubit.dart';
import '../bloc/trips_cubit.dart';
import '../bloc/trips_state.dart';
import 'trip_detail_sheet.dart';
import 'trip_row_card.dart';

/// Full Trips Management Screen adhering strictly to Clean MVVM with BLoC:
/// - Pure View layer: renders state and dispatches UI events.
/// - ZERO direct network calls or Dio/HTTP transport code.
/// - Adheres strictly to M4 requirements:
///   - Paginated list (cursor based) with filters for status, date range and search.
///   - Live updates from SSE `trip.created` and `trip.updated` without full reload.
///   - Visible row highlight markings on new and changed rows.
///   - Nested detail view drawer with timeline, places, and financial breakdowns.
///   - Masked phone numbers for `viewer` role.
///   - City jurisdiction protection (404 state).
class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<TripsRepository>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => TripsCubit(repository: repository)..loadTrips(),
        ),
        BlocProvider(
          create: (_) => TripActionCubit(repository: repository),
        ),
      ],
      child: const _TripsView(),
    );
  }
}

class _TripsView extends StatefulWidget {
  const _TripsView();

  @override
  State<_TripsView> createState() => _TripsViewState();
}

class _TripsViewState extends State<_TripsView> {
  final _searchController = TextEditingController();
  TripStatus? _selectedStatus;
  DateTimeRange? _selectedDateRange;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters(BuildContext context) {
    final cubit = context.read<TripsCubit>();
    final filter = TripFilterEntity(
      status: _selectedStatus != null ? [_selectedStatus!] : null,
      search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      from: _selectedDateRange?.start,
      to: _selectedDateRange?.end,
    );
    cubit.applyFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final user = authState is Authenticated ? authState.user : null;
    final isViewer = user?.isViewer ?? false;

    return BlocBuilder<TripsCubit, TripsState>(
      builder: (context, state) {
        if (state is TripsLoading || state is TripsInitial) {
          return const Center(
            child: OpsLoadingIndicator(message: 'Loading trips via GraphQL...'),
          );
        }

        if (state is TripNotFound) {
          return Center(
            child: OpsCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_off, size: 48, color: AppColors.error),
                  const SizedBox(height: 16),
                  const Text(
                    'Trip Not Found',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.read<TripsCubit>().loadTrips(),
                    child: const Text('Back to Trips List'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is TripsError) {
          return Center(
            child: OpsErrorView(
              message: state.message,
              onRetry: () => context.read<TripsCubit>().loadTrips(),
            ),
          );
        }

        if (state is TripsLoaded) {
          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Table Section
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Bar: Title, Total Count & Live SSE Indicator
                          _buildTopBar(state),
                          const SizedBox(height: 16),

                          // Filter Bar: Status, Search, and Date Range
                          _buildFilterBar(context),
                          const SizedBox(height: 20),

                          // Table Column Labels
                          _buildTableHeader(),
                          const SizedBox(height: 8),

                          // Trip List Items
                          Expanded(
                            child: state.trips.isEmpty
                                ? const Center(
                                    child: OpsCard(
                                      padding: EdgeInsets.all(32),
                                      child: Text(
                                        'No trips match your current filter criteria.',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: state.trips.length + (state.hasNextPage ? 1 : 0),
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      if (index == state.trips.length) {
                                        return _buildLoadMoreButton(context, state);
                                      }

                                      final trip = state.trips[index];
                                      final isSelected = state.selectedTrip?.id == trip.id;
                                      final isRecentlyCreated =
                                          state.recentlyCreatedTripIds.contains(trip.id);
                                      final isRecentlyUpdated =
                                          state.recentlyUpdatedTripIds.contains(trip.id);

                                      return TripRowCard(
                                        trip: trip,
                                        isSelected: isSelected,
                                        isRecentlyCreated: isRecentlyCreated,
                                        isRecentlyUpdated: isRecentlyUpdated,
                                        isViewer: isViewer,
                                        onTap: () {
                                          context.read<TripsCubit>().selectTrip(
                                                trip.id,
                                                userCity: user?.city,
                                                isSuperAdmin: user?.role.toLowerCase() == 'super_admin',
                                              );
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Side Detail Drawer (if a trip is selected)
                  if (state.selectedTrip != null)
                    TripDetailSheet(
                      trip: state.selectedTrip!,
                      onClose: () => context.read<TripsCubit>().clearSelectedTrip(),
                    ),
                ],
              ),
            ],
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTopBar(TripsLoaded state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'Trips Operations',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '${state.totalCount} trips',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Realtime SSE Trip Feed Connected',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return OpsCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Input
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search rider, driver, place...',
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters(context);
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              onSubmitted: (_) => _applyFilters(context),
            ),
          ),

          // Status Filter Dropdown
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TripStatus?>(
                value: _selectedStatus,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                hint: const Text('All Statuses', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                items: [
                  const DropdownMenuItem<TripStatus?>(
                    value: null,
                    child: Text('All Statuses'),
                  ),
                  ...TripStatus.values.map(
                    (s) => DropdownMenuItem<TripStatus?>(
                      value: s,
                      child: Text(s.label),
                    ),
                  ),
                ],
                onChanged: (val) {
                  setState(() => _selectedStatus = val);
                  _applyFilters(context);
                },
              ),
            ),
          ),

          // Date Range Picker Button
          InkWell(
            onTap: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2025),
                lastDate: DateTime.now().add(const Duration(days: 1)),
                initialDateRange: _selectedDateRange,
                builder: (context, child) {
                  return Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppColors.primary,
                        surface: AppColors.surface,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (range != null) {
                setState(() => _selectedDateRange = range);
                if (context.mounted) _applyFilters(context);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedDateRange != null ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range,
                    size: 16,
                    color: _selectedDateRange != null ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedDateRange != null
                        ? '${_selectedDateRange!.start.month}/${_selectedDateRange!.start.day} - ${_selectedDateRange!.end.month}/${_selectedDateRange!.end.day}'
                        : 'Date Range',
                    style: TextStyle(
                      color: _selectedDateRange != null ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (_selectedDateRange != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() => _selectedDateRange = null);
                        _applyFilters(context);
                      },
                      child: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Clear All Filters
          if (_selectedStatus != null || _searchController.text.isNotEmpty || _selectedDateRange != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedStatus = null;
                  _searchController.clear();
                  _selectedDateRange = null;
                });
                _applyFilters(context);
              },
              child: const Text('Reset', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              'ID / TIME',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              'STATUS',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'RIDER',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'DRIVER',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'ROUTE',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 120,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'FARE / DIST',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(BuildContext context, TripsLoaded state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: state.isLoadingMore ? null : () => context.read<TripsCubit>().fetchNextPage(),
          child: state.isLoadingMore
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : const Text('Load More Trips (Cursor Pagination)'),
        ),
      ),
    );
  }
}
