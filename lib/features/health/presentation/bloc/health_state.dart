import 'package:equatable/equatable.dart';
import '../../domain/entities/health_entity.dart';

sealed class HealthState extends Equatable {
  const HealthState();

  @override
  List<Object?> get props => [];
}

class HealthInitial extends HealthState {
  const HealthInitial();
}

class HealthLoading extends HealthState {
  const HealthLoading();
}

class HealthLoaded extends HealthState {
  final HealthEntity health;

  const HealthLoaded(this.health);

  @override
  List<Object?> get props => [health];
}

class HealthError extends HealthState {
  final String message;

  const HealthError(this.message);

  @override
  List<Object?> get props => [message];
}
