import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ops_badge.dart';
import '../../../../core/widgets/ops_loading_indicator.dart';
import '../../domain/entities/trip_entity.dart';
import '../bloc/trip_action_cubit.dart';
import '../bloc/trip_action_state.dart';

/// Modal dialog to pick and assign an available driver to a trip.
///
/// Adheres strictly to M4 requirements:
/// - "actions, shown only when permitted: assign driver (pick from available drivers)"
/// - ZERO direct network calls (dispatches only to TripActionCubit).
class AssignDriverDialog extends StatefulWidget {
  final TripEntity trip;
  final VoidCallback onAssigned;

  const AssignDriverDialog({
    super.key,
    required this.trip,
    required this.onAssigned,
  });

  static Future<void> show(BuildContext context, {
    required TripEntity trip,
    required VoidCallback onAssigned,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<TripActionCubit>(),
        child: AssignDriverDialog(trip: trip, onAssigned: onAssigned),
      ),
    );
  }

  @override
  State<AssignDriverDialog> createState() => _AssignDriverDialogState();
}

class _AssignDriverDialogState extends State<AssignDriverDialog> {
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    context.read<TripActionCubit>().fetchAvailableDrivers(cityId: widget.trip.cityId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripActionCubit, TripActionState>(
      listener: (context, state) {
        if (state is TripActionSuccess) {
          Navigator.of(context).pop();
          widget.onAssigned();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is TripActionConflict) {
          Navigator.of(context).pop();
          widget.onAssigned();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (state is TripActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is TripActionLoading;
        List<DriverEntity> availableDrivers = [];
        if (state is AvailableDriversLoaded) {
          availableDrivers = state.drivers;
        }

        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Assign Driver',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Trip: #${widget.trip.id.substring(0, widget.trip.id.length > 8 ? 8 : widget.trip.id.length)} · ${widget.trip.pickup.name} → ${widget.trip.dropoff.name}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AVAILABLE DRIVERS',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (state is! TripActionLoading)
                        InkWell(
                          onTap: () => context.read<TripActionCubit>().fetchAvailableDrivers(cityId: widget.trip.cityId),
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh, size: 14, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Refresh',
                                  style: TextStyle(color: AppColors.primary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (state is TripActionLoading && availableDrivers.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: OpsLoadingIndicator(message: 'Loading available drivers...'),
                      ),
                    )
                  else if (availableDrivers.isEmpty && state is! TripActionLoading)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'No drivers are currently marked as available. Click Refresh or wait a few seconds for the simulator.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                            tooltip: 'Refresh Available Drivers',
                            onPressed: () => context.read<TripActionCubit>().fetchAvailableDrivers(cityId: widget.trip.cityId),
                          ),
                        ],
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _selectedDriverId,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      hint: const Text(
                        'Select an available driver',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      items: availableDrivers.map((driver) {
                        return DropdownMenuItem<String>(
                          value: driver.id,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  driver.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (driver.vehicle != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: OpsBadge(
                                    label: driver.vehicle!,
                                    color: AppColors.primary,
                                    showDot: false,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedDriverId = val;
                        });
                      },
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: (_selectedDriverId == null || isLoading)
                            ? null
                            : () {
                                context.read<TripActionCubit>().assignDriver(
                                      tripId: widget.trip.id,
                                      driverId: _selectedDriverId!,
                                    );
                              },
                        child: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Assign Driver', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
