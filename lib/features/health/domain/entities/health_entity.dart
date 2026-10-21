import 'package:equatable/equatable.dart';

/// Pure domain entity representing system health status.
/// Zero transport or UI dependencies.
class HealthEntity extends Equatable {
  final bool isOk;
  final String time;
  final bool simulatorActive;
  final int openStreams;
  final int openSockets;

  const HealthEntity({
    required this.isOk,
    required this.time,
    required this.simulatorActive,
    required this.openStreams,
    required this.openSockets,
  });

  @override
  List<Object?> get props => [isOk, time, simulatorActive, openStreams, openSockets];
}
