import '../../domain/entities/health_entity.dart';

/// Data Transfer Object (DTO) for `/api/health` response.
class HealthModel {
  final bool ok;
  final String time;
  final bool simulator;
  final int openStreams;
  final int openSockets;

  const HealthModel({
    required this.ok,
    required this.time,
    required this.simulator,
    required this.openStreams,
    required this.openSockets,
  });

  factory HealthModel.fromJson(Map<String, dynamic> json) {
    return HealthModel(
      ok: json['ok'] == true,
      time: json['time']?.toString() ?? '',
      simulator: json['simulator'] == true,
      openStreams: (json['openStreams'] as num?)?.toInt() ?? 0,
      openSockets: (json['openSockets'] as num?)?.toInt() ?? 0,
    );
  }

  HealthEntity toEntity() {
    return HealthEntity(
      isOk: ok,
      time: time,
      simulatorActive: simulator,
      openStreams: openStreams,
      openSockets: openSockets,
    );
  }
}
