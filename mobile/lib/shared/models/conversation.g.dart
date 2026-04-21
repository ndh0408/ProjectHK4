// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Conversation _$ConversationFromJson(Map<String, dynamic> json) => Conversation(
      id: json['id'] as String,
      type: $enumDecode(_$ConversationTypeEnumMap, json['type']),
      name: json['name'] as String?,
      imageUrl: json['imageUrl'] as String?,
      eventId: json['eventId'] as String?,
      eventTitle: json['eventTitle'] as String?,
      lastMessageContent: json['lastMessageContent'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      muted: json['muted'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      archived: json['archived'] as bool? ?? false,
      participants: (json['participants'] as List<dynamic>?)
          ?.map((e) => ChatParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
      participantCount: (json['participantCount'] as num?)?.toInt(),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      pinnedMessage: json['pinnedMessage'] == null
          ? null
          : PinnedMessage.fromJson(
              json['pinnedMessage'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ConversationToJson(Conversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': _$ConversationTypeEnumMap[instance.type]!,
      'name': instance.name,
      'imageUrl': instance.imageUrl,
      'eventId': instance.eventId,
      'eventTitle': instance.eventTitle,
      'lastMessageContent': instance.lastMessageContent,
      'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'muted': instance.muted,
      'pinned': instance.pinned,
      'archived': instance.archived,
      'participants': instance.participants?.map((e) => e.toJson()).toList(),
      'participantCount': instance.participantCount,
      'closedAt': instance.closedAt?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
      'pinnedMessage': instance.pinnedMessage?.toJson(),
    };

const _$ConversationTypeEnumMap = {
  ConversationType.eventGroup: 'EVENT_GROUP',
  ConversationType.direct: 'DIRECT',
  ConversationType.group: 'GROUP',
};

ChatParticipant _$ChatParticipantFromJson(Map<String, dynamic> json) =>
    ChatParticipant(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      lastReadAt: json['lastReadAt'] == null
          ? null
          : DateTime.parse(json['lastReadAt'] as String),
    );

Map<String, dynamic> _$ChatParticipantToJson(ChatParticipant instance) =>
    <String, dynamic>{
      'userId': instance.userId,
      'fullName': instance.fullName,
      'avatarUrl': instance.avatarUrl,
      'lastReadAt': instance.lastReadAt?.toIso8601String(),
    };

PinnedMessage _$PinnedMessageFromJson(Map<String, dynamic> json) =>
    PinnedMessage(
      id: json['id'] as String,
      content: json['content'] as String?,
      senderName: json['senderName'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      pinnedAt: json['pinnedAt'] == null
          ? null
          : DateTime.parse(json['pinnedAt'] as String),
      pinnedByUserId: json['pinnedByUserId'] as String?,
    );

Map<String, dynamic> _$PinnedMessageToJson(PinnedMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'senderName': instance.senderName,
      'createdAt': instance.createdAt?.toIso8601String(),
      'pinnedAt': instance.pinnedAt?.toIso8601String(),
      'pinnedByUserId': instance.pinnedByUserId,
    };
