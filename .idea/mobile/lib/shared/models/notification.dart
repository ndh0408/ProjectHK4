import 'package:json_annotation/json_annotation.dart';

part 'notification.g.dart';

@JsonSerializable()
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.type,
    this.relatedEventId,
    this.senderId,
    this.senderName,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      userId: json['userId']?.toString() ?? '',
      title: json['title'] as String,
      body: (json['message'] ?? json['body'] ?? '') as String,
      isRead: json['read'] as bool? ?? json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      type: json['type'] as String?,
      relatedEventId: (json['referenceId'] ?? json['relatedEventId'])?.toString(),
      senderId: json['senderId']?.toString(),
      senderName: json['senderName'] as String?,
    );
  }

  final String id;
  final String userId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? type;
  final String? relatedEventId;
  final String? senderId;
  final String? senderName;

  bool get canReply => senderId != null && type == 'NEW_QUESTION';

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'message': body,
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
        'type': type,
        'relatedEventId': relatedEventId,
        'senderId': senderId,
        'senderName': senderName,
      };

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    bool? isRead,
    DateTime? createdAt,
    String? type,
    String? relatedEventId,
    String? senderId,
    String? senderName,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      relatedEventId: relatedEventId ?? this.relatedEventId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
    );
  }
}
