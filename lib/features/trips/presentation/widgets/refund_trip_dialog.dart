import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/trip_entity.dart';
import '../bloc/trip_action_cubit.dart';
import '../bloc/trip_action_state.dart';

/// Modal dialog to process a refund for a completed trip.
///
/// Adheres strictly to M4 requirements:
/// - "refund (amount and reason, validated against the remaining amount)"
/// - Validates amount <= remaining refundable balance.
class RefundTripDialog extends StatefulWidget {
  final TripEntity trip;
  final VoidCallback onRefunded;

  const RefundTripDialog({
    super.key,
    required this.trip,
    required this.onRefunded,
  });

  static Future<void> show(BuildContext context, {
    required TripEntity trip,
    required VoidCallback onRefunded,
  }) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<TripActionCubit>(),
        child: RefundTripDialog(trip: trip, onRefunded: onRefunded),
      ),
    );
  }

  @override
  State<RefundTripDialog> createState() => _RefundTripDialogState();
}

class _RefundTripDialogState extends State<RefundTripDialog> {
  late final TextEditingController _amountController;
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.trip.remainingRefundableAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxRefundable = widget.trip.remainingRefundableAmount;
    final currency = widget.trip.fare.currency;

    return BlocConsumer<TripActionCubit, TripActionState>(
      listener: (context, state) {
        if (state is TripActionSuccess) {
          Navigator.of(context).pop();
          widget.onRefunded();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is TripActionConflict) {
          Navigator.of(context).pop();
          widget.onRefunded();
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
                          'Issue Trip Refund',
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
                      'Original Fare: ${CurrencyFormatter.format(widget.trip.fare.amount, currency)} · Remaining Refundable: ${CurrencyFormatter.format(maxRefundable, currency)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'REFUND AMOUNT',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        prefixText: '$currency ',
                        prefixStyle: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a refund amount.';
                        }
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Refund amount must be greater than zero.';
                        }
                        if (parsed > maxRefundable) {
                          return 'Cannot exceed maximum refundable amount of ${maxRefundable.toStringAsFixed(2)}.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'REFUND REASON',
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
                      maxLines: 2,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Route discrepancy, Rider dissatisfaction...',
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
                          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: isLoading
                              ? null
                              : () {
                                  if (_formKey.currentState?.validate() ?? false) {
                                    final amt = double.parse(_amountController.text.trim());
                                    context.read<TripActionCubit>().refundTrip(
                                          tripId: widget.trip.id,
                                          amount: amt,
                                          reason: _reasonController.text.trim(),
                                          maxRefundable: maxRefundable,
                                        );
                                  }
                                },
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Text('Process Refund', style: TextStyle(fontWeight: FontWeight.bold)),
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
