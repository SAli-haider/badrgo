import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/health_repository.dart';
import 'health_state.dart';

/// ViewModel for system health adhering strictly to Clean MVVM:
/// Calls domain repository interface. Zero knowledge of Dio or HTTP.
class HealthCubit extends Cubit<HealthState> {
  final HealthRepository _healthRepository;

  HealthCubit({required HealthRepository healthRepository})
      : _healthRepository = healthRepository,
        super(const HealthInitial());

  Future<void> checkHealth() async {
    emit(const HealthLoading());
    final result = await _healthRepository.getHealth();

    result.when(
      success: (health) => emit(HealthLoaded(health)),
      failure: (exception) => emit(HealthError(exception.message)),
    );
  }
}
