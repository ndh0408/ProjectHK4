// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      type: $enumDecode(_$MessageTypeEnumMap, json['type']),
      content: json['content'] as String,
      mediaUrl: json['mediaUrl'] as String?,
      sender: json['sender'] == null
          ? null
          : MessageSender.fromJson(json['sender'] as Map<String, dynamic>),
      replyTo: json['replyTo'] == null
          ? null
          : MessageReply.fromJson(json['replyTo'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      editedAt: json['editedAt'] == null
          ? null
          : DateTime.parse(json['editedAt'] as String),
      deleted: json['deleted'] as bool? ?? false,
      poll: json['poll'] == null
          ? null
          : PollSnapshot.fromJson(json['poll'] as Map<String, dynamic>),
      senderRole: json['senderRole'] as String?,
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversationId': instance.conversationId,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'content': instance.content,
      'mediaUrl': instance.mediaUrl,
      'sender': instance.sender?.toJson(),
      'replyTo': instance.replyTo?.toJson(),
      'createdAt': instance.createdAt.toIso8601String(),
      'editedAt': instance.editedAt?.toIso8601String(),
      'deleted': instance.deleted,
      'poll': instance.poll?.toJson(),
      'senderRole': instance.senderRole,
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'TEXT',
  MessageType.image: 'IMAGE',
  MessageType.file: 'FILE',
  MessageType.system: 'SYSTEM',
  MessageType.poll: 'POLL',
};

MessageSender _$MessageSenderFromJson(Map<String, dynamic> json) =>
    MessageSender(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$MessageSenderToJson(MessageSender instance) =>
    <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'avatarUrl': instance.avatarUrl,
    };

MessageReply _$MessageReplyFromJson(Map<String, dynamic> json) => MessageReply(
      id: json['id'] as String,
      content: json['content'] as String,
      senderName: json['senderName'] as String,
    );

Map<String, dynamic> _$MessageReplyToJson(MessageReply instance) =>
    <String, dynamic>{
      'id': instance.id,
      'content': instance.content,
      'senderName': instance.senderName,
    };

PollSnapshot _$PollSnapshotFromJson(Map<String, dynamic> json) => PollSnapshot(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      question: json['question'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      isActive: json['isActive'] as bool,
      totalVotes: (json['totalVotes'] as num).toInt(),
      maxRating: (json['maxRating'] as num?)?.toInt(),
      closesAt: json['closesAt'] == null
          ? null
          : DateTime.parse(json['closesAt'] as String),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      options: (json['options'] as List<dynamic>)
          .map((e) => PollSnapshotOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasVoted: json['hasVoted'] as bool,
      votedOptionIds: (json['votedOptionIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      votedRating: (json['votedRating'] as num?)?.toInt(),
      hideResultsUntilClosed: json['hideResultsUntilClosed'] as bool,
      resultsHidden: json['resultsHidden'] as bool,
    );

Map<String, dynamic> _$PollSnapshotToJson(PollSnapshot instance) =>
    <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'question': instance.question,
      'type': instance.type,
      'status': instance.status,
      'isActive': instance.isActive,
      'totalVotes': instance.totalVotes,
      'maxRating': instance.maxRating,
      'closesAt': instance.closesAt?.toIso8601String(),
      'closedAt': instance.closedAt?.toIso8601String(),
      'options': instance.options.map((e) => e.toJson()).toList(),
      'hasVoted': instance.hasVoted,
      'votedOptionIds': instance.votedOptionIds,
      'votedRating': instance.votedRating,
      'hideResultsUntilClosed': instance.hideResultsUntilClosed,
      'resultsHidden': instance.resultsHidden,
    };

PollSnapshotOption _$PollSnapshotOptionFromJson(Map<String, dynamic> json) =>
    PollSnapshotOption(
      id: json['id'] as String,
      text: json['text'] as String,
      voteCount: (json['voteCount'] as num).toInt(),
      percentage: (json['percentage'] as num).toDouble(),
      displayOrder: (json['displayOrder'] as num).toInt(),
    );

Map<String, dynamic> _$PollSnapshotOptionToJson(PollSnapshotOption instance) =>
    <String, dynamic>{
      'id': instance.id,
      'text': instance.text,
      'voteCount': instance.voteCount,
      'percentage': instance.percentage,
      'displayOrder': instance.displayOrder,
    };
