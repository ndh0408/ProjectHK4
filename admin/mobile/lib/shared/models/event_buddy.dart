import 'package:json_annotation/json_annotation.dart';

part 'event_buddy.g.dart';

@JsonSerializable()
class EventBuddy {
  const EventBuddy({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.sharedEventsCount = 0,
    this.sharedEvents,
    this.lastEventDate,
    this.latestSharedEventName,
  });

  factory EventBuddy.fromJson(Map<String, dynamic> json) =>
      _$EventBuddyFromJson(json);

  final String userId;
  final String fullName;
  final String? avatarUrl;
  final int sharedEventsCount;
  final List<SharedEventInfo>? sharedEvents;
  final DateTime? lastEventDate;
  final String? latestSharedEventName;

  Map<String, dynamic> toJson() => _$EventBuddyToJson(this);

  String? get displayLatestEventName {
    if (latestSharedEventName != null) return latestSharedEventName;
    if (sharedEvents != null && sharedEvents!.isNotEmpty) {
      return sharedEvents!.first.eventTitle;
    }
    return null;
  }
}

@JsonSerializable()
class SharedEventInfo {
  const SharedEventInfo({
    required this.eventId,
    required this.eventTitle,
    this.eventDate,
    this.eventImageUrl,
  });

  factory SharedEventInfo.fromJson(Map<String, dynamic> json) =>
      _$SharedEventInfoFromJson(json);

  final String eventId;
  final String eventTitle;
  final DateTime? eventDate;
  final String? eventImageUrl;

  Map<String, dynamic> toJson() => _$SharedEventInfoToJson(this);
}
