import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

enum MessageType {
  @JsonValue('TEXT')
  text,
  @JsonValue('IMAGE')
  image,
  @JsonValue('FILE')
  file,
  @JsonValue('SYSTEM')
  system,
}

@JsonSerializable()
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.content,
    this.mediaUrl,
    this.sender,
    this.replyTo,
    required this.createdAt,
    this.editedAt,
    this.deleted = false,
    this.deletedByName,
    this.deletedAt,
    this.senderRole,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      _$ChatMessageFromJson(json);

  final String id;
  final String conversationId;
  final MessageType type;
  final String content;
  final String? mediaUrl;
  final MessageSender? sender;
  final MessageReply? replyTo;
  final DateTime createdAt;
  final DateTime? editedAt;
  final bool deleted;
  final String? deletedByName;
  final DateTime? deletedAt;
  final String? senderRole;

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  bool get isEdited => editedAt != null;
  bool get isDeleted => deleted;
  bool get isFromOrganiser => senderRole == 'ORGANISER';
}

@JsonSerializable()
class MessageSender {
  const MessageSender({
    required this.id,
    required this.fullName,
    this.avatarUrl,
  });

  factory MessageSender.fromJson(Map<String, dynamic> json) =>
      _$MessageSenderFromJson(json);

  final String id;
  final String fullName;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => _$MessageSenderToJson(this);
}

@JsonSerializable()
class MessageReply {
  const MessageReply({
    required this.id,
    required this.content,
    required this.senderName,
  });

  factory MessageReply.fromJson(Map<String, dynamic> json) =>
      _$MessageReplyFromJson(json);

  final String id;
  final String content;
  final String senderName;

  Map<String, dynamic> toJson() => _$MessageReplyToJson(this);
}
