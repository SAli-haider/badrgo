import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/error_code.dart';
import '../../domain/repositories/trips_repository.dart';
import 'trip_action_state.dart';

/// ViewModel managing Trip mutation actions:
/// - Assign driver (from available drivers)
/// - Cancel trip with stated reason
/// - Refund trip with balance validation
/// - Clean 409 INVALID_STATE conflict detection
class TripActionCubit extends Cubit<TripActionState> {
  final TripsRepository _repository;

  TripActionCubit({
    required TripsRepository repository,
  })  : _repository = repository,
        super(const TripActionInitial());

  /// Fetches available drivers for the assignment dropdown picker.
  Future<void> fetchAvailableDrivers({String? cityId}) async {
    emit(const TripActionLoading());
    final result = await _repository.getAvailableDrivers(cityId: cityId);
    result.when(
      success: (drivers) => emit(AvailableDriversLoaded(drivers)),
      failure: (exception) => emit(TripActionError(exception.message)),
    );
  }

  /// Assigns a driver to a requested trip.
  Future<void> assignDriver({
    required String tripId,
    required String driverId,
  }) async {
    emit(const TripActionLoading());
    final result = await _repository.assignDriver(
      tripId: tripId,
      driverId: driverId,
    );

    result.when(
      success: (trip) {
        emit(
          TripActionSuccess(
            message: 'Driver assigned successfully.',
            trip: trip,
          ),
        );
      },
      failure: (exception) {
        if (exception.code == ErrorCode.invalidState || exception.statusCode == 409) {
          emit(
            TripActionConflict(
              message: 'Trip state was altered on the server (409 Conflict). The simulator may have already changed or assigned this trip.',
              tripId: tripId,
            ),
          );
        } else {
          emit(TripActionError(exception.message));
        }
      },
    );
  }

  /// Cancels a trip with a required reason.
  Future<void> cancelTrip({
    required String tripId,
    required String reason,
  }) async {
    if (reason.trim().length < 3) {
      emit(const TripActionError('Please provide a reason of at least 3 characters.'));
      return;
    }

    emit(const TripActionLoading());
    final result = await _repository.cancelTrip(
      tripId: tripId,
      reason: reason.trim(),
    );

    result.when(
      success: (trip) {
        emit(
          TripActionSuccess(
            message: 'Trip was cancelled successfully.',
            trip: trip,
          ),
        );
      },
      failure: (exception) {
        if (exception.code == ErrorCode.invalidState || exception.statusCode == 409) {
          emit(
            TripActionConflict(
              message: 'Trip state conflict (409): Trip is no longer in a cancellable state on the server.',
              tripId: tripId,
            ),
          );
        } else {
          emit(TripActionError(exception.message));
        }
      },
    );
  }

  /// Issues a refund with remaining balance validation.
  Future<void> refundTrip({
    required String tripId,
    required double amount,
    required String reason,
    required double maxRefundable,
  }) async {
    if (amount <= 0) {
      emit(const TripActionError('Refund amount must be greater than zero.'));
      return;
    }

    if (amount > maxRefundable) {
      emit(
        TripActionError(
          'Refund amount exceeds remaining refundable balance of ${maxRefundable.toStringAsFixed(2)}.',
        ),
      );
      return;
    }

    if (reason.trim().length < 3) {
      emit(const TripActionError('Please provide a reason of at least 3 characters.'));
      return;
    }

    emit(const TripActionLoading());
    final result = await _repository.refundTrip(
      tripId: tripId,
      amount: amount,
      reason: reason.trim(),
    );

    result.when(
      success: (trip) {
        emit(
          TripActionSuccess(
            message: 'Refund was processed successfully.',
            trip: trip,
          ),
        );
      },
      failure: (exception) {
        if (exception.code == ErrorCode.invalidState || exception.statusCode == 409) {
          emit(
            TripActionConflict(
              message: 'Refund conflict (409): Trip state or balance has changed on the server.',
              tripId: tripId,
            ),
          );
        } else {
          emit(TripActionError(exception.message));
        }
      },
    );
  }
}
