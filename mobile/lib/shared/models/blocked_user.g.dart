// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocked_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlockedUser _$BlockedUserFromJson(Map<String, dynamic> json) => BlockedUser(
      id: json['id'] as String,
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      reason: json['reason'] as String?,
      blockedAt: json['blockedAt'] == null
          ? null
          : DateTime.parse(json['blockedAt'] as String),
    );

Map<String, dynamic> _$BlockedUserToJson(BlockedUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'fullName': instance.fullName,
      'avatarUrl': instance.avatarUrl,
      'reason': instance.reason,
      'blockedAt': instance.blockedAt?.toIso8601String(),
    };
