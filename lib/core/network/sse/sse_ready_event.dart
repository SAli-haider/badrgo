import 'package:equatable/equatable.dart';

/// Payload of the initial SSE `ready` event.
/// Contains subscribed topics and denied topics for the active role.
class SseReadyEvent extends Equatable {
  final List<String> topics;
  final List<String> deniedTopics;

  const SseReadyEvent({
    required this.topics,
    required this.deniedTopics,
  });

  factory SseReadyEvent.fromJson(Map<String, dynamic> json) {
    return SseReadyEvent(
      topics: (json['topics'] as List?)?.map((e) => e.toString()).toList() ?? [],
      deniedTopics: (json['deniedTopics'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  bool isTopicDenied(String topic) => deniedTopics.contains(topic);

  @override
  List<Object?> get props => [topics, deniedTopics];
}
