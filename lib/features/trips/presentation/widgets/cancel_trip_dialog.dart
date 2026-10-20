import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/trip_entity.dart';
import '../bloc/trip_action_cubit.dart';
import '../bloc/trip_action_state.dart';

/// Modal dialog to cancel a trip with mandatory reason input.
///
/// Adheres strictly to M4 requirements:
/// - "actions, shown only when permitted: cancel (with a reason)"
/// - "Handle 409 INVALID_STATE clearly."
class CancelTripDialog extends StatefulWidget {
  final TripEntity trip;
  final VoidCallback onCancelled;

  const CancelTripDialog({
    super.key,
    required this.trip,
    required this.onCancelled,
  });

  static Future<void> show(BuildContext context, {
    required TripEntity trip,
    required VoidCallback onCancelled,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<TripActionCubit>(),
        child: CancelTripDialog(trip: trip, onCancelled: onCancelled),
      ),
    );
  }

  @override
  State<CancelTripDialog> createState() => _CancelTripDialogState();
}

class _CancelTripDialogState extends State<CancelTripDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripActionCubit, TripActionState>(
      listener: (context, state) {
        if (state is TripActionSuccess) {
          Navigator.of(context).pop();
          widget.onCancelled();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is TripActionConflict) {
          Navigator.of(context).pop();
          widget.onCancelled();
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

        return Dialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Cancel Trip',
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
                      'Trip #${widget.trip.id.substring(0, widget.trip.id.length > 8 ? 8 : widget.trip.id.length)} will be cancelled immediately.',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'CANCELLATION REASON',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 3,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Rider requested cancellation, Driver vehicle breakdown...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                      validator: (val) {
                        if (val == null || val.trim().length < 3) {
                          return 'Please provide a reason of at least 3 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                          child: const Text('Keep Trip', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState?.validate() ?? false) {
                                    context.read<TripActionCubit>().cancelTrip(
                                          tripId: widget.trip.id,
                                          reason: _reasonController.text.trim(),
                                        );
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Confirm Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
