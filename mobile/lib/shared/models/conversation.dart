import 'package:json_annotation/json_annotation.dart';

part 'conversation.g.dart';

enum ConversationType {
  @JsonValue('EVENT_GROUP')
  eventGroup,
  @JsonValue('DIRECT')
  direct,
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
    this.participants,
    this.participantCount,
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
  final List<ChatParticipant>? participants;
  final int? participantCount;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => _$ConversationToJson(this);

  // Get display name for the conversation
  String get displayName {
    if (type == ConversationType.eventGroup) {
      return name ?? eventTitle ?? 'Event Chat';
    }
    // For direct chat, return the other participant's name
    if (participants != null && participants!.isNotEmpty) {
      return participants!.first.fullName;
    }
    return 'Chat';
  }

  // Get display image
  String? get displayImage {
    if (type == ConversationType.eventGroup) {
      return imageUrl;
    }
    // For direct chat, return the other participant's avatar
    if (participants != null && participants!.isNotEmpty) {
      return participants!.first.avatarUrl;
    }
    return null;
  }
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
