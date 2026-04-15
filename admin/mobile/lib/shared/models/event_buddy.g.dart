// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_buddy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventBuddy _$EventBuddyFromJson(Map<String, dynamic> json) => EventBuddy(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      sharedEventsCount: (json['sharedEventsCount'] as num?)?.toInt() ?? 0,
      sharedEvents: (json['sharedEvents'] as List<dynamic>?)
          ?.map((e) => SharedEventInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      lastEventDate: json['lastEventDate'] == null
          ? null
          : DateTime.parse(json['lastEventDate'] as String),
      latestSharedEventName: json['latestSharedEventName'] as String?,
    );

Map<String, dynamic> _$EventBuddyToJson(EventBuddy instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'fullName': instance.fullName,
      'avatarUrl': instance.avatarUrl,
      'sharedEventsCount': instance.sharedEventsCount,
      'sharedEvents': instance.sharedEvents,
      'lastEventDate': instance.lastEventDate?.toIso8601String(),
      'latestSharedEventName': instance.latestSharedEventName,
    };

SharedEventInfo _$SharedEventInfoFromJson(Map<String, dynamic> json) =>
    SharedEventInfo(
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String,
      eventDate: json['eventDate'] == null
          ? null
          : DateTime.parse(json['eventDate'] as String),
      eventImageUrl: json['eventImageUrl'] as String?,
    );

Map<String, dynamic> _$SharedEventInfoToJson(SharedEventInfo instance) =>
    <String, dynamic>{
      'eventId': instance.eventId,
      'eventTitle': instance.eventTitle,
      'eventDate': instance.eventDate?.toIso8601String(),
      'eventImageUrl': instance.eventImageUrl,
    };
