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
  @JsonValue('POLL')
  poll,
}

@JsonSerializable(explicitToJson: true)
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
    this.poll,
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
  final PollSnapshot? poll;
  /// "ORGANISER" when the sender owns this conversation's event, otherwise
  /// "ATTENDEE" (or null for legacy messages). Drives the "Organiser" chip
  /// on bubbles so attendees can tell official announcements apart.
  final String? senderRole;

  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  bool get isEdited => editedAt != null;
  bool get isDeleted => deleted;
  bool get isFromOrganiser => senderRole == 'ORGANISER';

  ChatMessage copyWith({
    PollSnapshot? poll,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      sender: sender,
      replyTo: replyTo,
      createdAt: createdAt,
      editedAt: editedAt,
      deleted: deleted,
      poll: poll ?? this.poll,
      senderRole: senderRole,
    );
  }
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

/// Embedded inside POLL-type messages so the chat bubble can render the
/// poll card inline and let users vote without leaving the conversation.
@JsonSerializable(explicitToJson: true)
class PollSnapshot {
  const PollSnapshot({
    required this.id,
    required this.eventId,
    required this.question,
    required this.type,
    required this.status,
    required this.isActive,
    required this.totalVotes,
    this.maxRating,
    this.closesAt,
    this.closedAt,
    required this.options,
    required this.hasVoted,
    this.votedOptionIds,
    this.votedRating,
    required this.hideResultsUntilClosed,
    required this.resultsHidden,
  });

  factory PollSnapshot.fromJson(Map<String, dynamic> json) =>
      _$PollSnapshotFromJson(json);

  final String id;
  final String eventId;
  final String question;
  final String type; // SINGLE_CHOICE | MULTIPLE_CHOICE | RATING
  final String status; // DRAFT | SCHEDULED | ACTIVE | CLOSED | CANCELLED
  @JsonKey(name: 'isActive')
  final bool isActive;
  final int totalVotes;
  final int? maxRating;
  final DateTime? closesAt;
  final DateTime? closedAt;
  final List<PollSnapshotOption> options;
  final bool hasVoted;
  /// Option IDs the current viewer picked — populated for the person who
  /// voted, used by the UI to highlight their own selections. Null when
  /// the poll hasn't been voted on or for rating polls.
  final List<String>? votedOptionIds;
  final int? votedRating;
  final bool hideResultsUntilClosed;
  final bool resultsHidden;

  Map<String, dynamic> toJson() => _$PollSnapshotToJson(this);

  PollSnapshot copyWith({
    String? status,
    bool? isActive,
    int? totalVotes,
    List<PollSnapshotOption>? options,
    bool? hasVoted,
    List<String>? votedOptionIds,
    int? votedRating,
    bool? resultsHidden,
    DateTime? closedAt,
  }) {
    return PollSnapshot(
      id: id,
      eventId: eventId,
      question: question,
      type: type,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      totalVotes: totalVotes ?? this.totalVotes,
      maxRating: maxRating,
      closesAt: closesAt,
      closedAt: closedAt ?? this.closedAt,
      options: options ?? this.options,
      hasVoted: hasVoted ?? this.hasVoted,
      votedOptionIds: votedOptionIds ?? this.votedOptionIds,
      votedRating: votedRating ?? this.votedRating,
      hideResultsUntilClosed: hideResultsUntilClosed,
      resultsHidden: resultsHidden ?? this.resultsHidden,
    );
  }
}

@JsonSerializable()
class PollSnapshotOption {
  const PollSnapshotOption({
    required this.id,
    required this.text,
    required this.voteCount,
    required this.percentage,
    required this.displayOrder,
  });

  factory PollSnapshotOption.fromJson(Map<String, dynamic> json) =>
      _$PollSnapshotOptionFromJson(json);

  final String id;
  final String text;
  final int voteCount;
  final double percentage;
  final int displayOrder;

  Map<String, dynamic> toJson() => _$PollSnapshotOptionToJson(this);
}
