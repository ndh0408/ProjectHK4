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

@JsonSerializable(explicitToJson: true)
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
    this.pinnedMessage,
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
  /// Organiser-pinned announcement sitting at the top of the chat. Null when
  /// nothing is pinned. Attendees see it read-only; only organisers can
  /// pin/unpin (handled on the web admin).
  final PinnedMessage? pinnedMessage;

  bool get isClosed => closedAt != null;

  Conversation copyWith({
    String? id,
    ConversationType? type,
    String? name,
    String? imageUrl,
    String? eventId,
    String? eventTitle,
    String? lastMessageContent,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? muted,
    bool? pinned,
    bool? archived,
    List<ChatParticipant>? participants,
    int? participantCount,
    DateTime? closedAt,
    DateTime? createdAt,
    PinnedMessage? pinnedMessage,
    bool clearPinnedMessage = false,
  }) {
    return Conversation(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      eventId: eventId ?? this.eventId,
      eventTitle: eventTitle ?? this.eventTitle,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      muted: muted ?? this.muted,
      pinned: pinned ?? this.pinned,
      archived: archived ?? this.archived,
      participants: participants ?? this.participants,
      participantCount: participantCount ?? this.participantCount,
      closedAt: closedAt ?? this.closedAt,
      createdAt: createdAt ?? this.createdAt,
      pinnedMessage:
          clearPinnedMessage ? null : (pinnedMessage ?? this.pinnedMessage),
    );
  }

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
    this.lastReadAt,
  });

  factory ChatParticipant.fromJson(Map<String, dynamic> json) =>
      _$ChatParticipantFromJson(json);

  final String userId;
  final String fullName;
  final String? avatarUrl;
  /// When this participant last marked the conversation as read. Used by the
  /// message bubble to decide whether to show ✓ (sent) or ✓✓ (read) on the
  /// current user's own messages.
  final DateTime? lastReadAt;

  Map<String, dynamic> toJson() => _$ChatParticipantToJson(this);
}

/// Lightweight shape of the currently-pinned announcement. Comes straight
/// from the backend's ConversationResponse.PinnedMessageResponse — a
/// snapshot of the message body + who pinned it, so the attendee UI can
/// render the banner without fetching the full message row.
@JsonSerializable()
class PinnedMessage {
  const PinnedMessage({
    required this.id,
    this.content,
    this.senderName,
    this.createdAt,
    this.pinnedAt,
    this.pinnedByUserId,
  });

  factory PinnedMessage.fromJson(Map<String, dynamic> json) =>
      _$PinnedMessageFromJson(json);

  final String id;
  final String? content;
  final String? senderName;
  final DateTime? createdAt;
  final DateTime? pinnedAt;
  final String? pinnedByUserId;

  Map<String, dynamic> toJson() => _$PinnedMessageToJson(this);
}
