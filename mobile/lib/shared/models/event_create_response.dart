import 'event.dart';

class EventCreateResponse {
  const EventCreateResponse({
    required this.event,
    this.newToken,
    this.roleChanged = false,
  });

  factory EventCreateResponse.fromJson(Map<String, dynamic> json) {
    return EventCreateResponse(
      event: Event.fromJson(json['event'] as Map<String, dynamic>),
      newToken: json['newToken'] as String?,
      roleChanged: json['roleChanged'] as bool? ?? false,
    );
  }

  final Event event;
  final String? newToken;
  final bool roleChanged;
}
