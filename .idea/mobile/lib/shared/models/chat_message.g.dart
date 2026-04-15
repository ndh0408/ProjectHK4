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
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversationId': instance.conversationId,
      'type': _$MessageTypeEnumMap[instance.type]!,
      'content': instance.content,
      'mediaUrl': instance.mediaUrl,
      'sender': instance.sender,
      'replyTo': instance.replyTo,
      'createdAt': instance.createdAt.toIso8601String(),
      'editedAt': instance.editedAt?.toIso8601String(),
      'deleted': instance.deleted,
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'TEXT',
  MessageType.image: 'IMAGE',
  MessageType.file: 'FILE',
  MessageType.system: 'SYSTEM',
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
