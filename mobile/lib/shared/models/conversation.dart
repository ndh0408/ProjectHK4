import 'package:json_annotation/json_annotation.dart';

part 'conversation.g.dart';

enum ConversationType {
  @JsonValue('EVENT_GROUP')
  eventGroup,
  @JsonValue('DIRECT')
  direct,
  @JsonValue('GROUP')
  group,
}

@JsonSerializable()
class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    this.name,
    this.imageUrl,
    this.eventId,
    this.eventTitle,
    this.lastMessageContent,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.muted = false,
    this.pinned = false,
    this.archived = false,
    this.participants,
    this.participantCount,
    this.closedAt,
    this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);

  final String id;
  final ConversationType type;
  final String? name;
  final String? imageUrl;
  final String? eventId;
  final String? eventTitle;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool muted;
  final bool pinned;
  final bool archived;
  final List<ChatParticipant>? participants;
  final int? participantCount;
  final DateTime? closedAt;
  final DateTime? createdAt;

  bool get isClosed => closedAt != null;

  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    if (type == ConversationType.eventGroup || type == ConversationType.group) {
      if (eventTitle != null && eventTitle!.isNotEmpty) {
        return eventTitle!;
      }
      return 'Group Chat';
    }
    return 'Chat';
  }

  String? get displayImage {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl;
    }
    return null;
  }

  bool get isGroup => type == ConversationType.eventGroup || type == ConversationType.group;
}

@JsonSerializable()
class ChatParticipant {
  const ChatParticipant({
    required this.userId,
    required this.fullName,
    this.avatarUrl,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) =>
      _$ChatParticipantFromJson(json);

  final String userId;
  final String fullName;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => _$ChatParticipantToJson(this);
}
