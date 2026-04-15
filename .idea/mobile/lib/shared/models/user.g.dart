// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

User _$UserFromJson(Map<String, dynamic> json) => User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['fullName'] as String?,
      role: $enumDecode(_$UserRoleEnumMap, json['role']),
      status: $enumDecode(_$UserStatusEnumMap, json['status']),
      avatarUrl: json['avatarUrl'] as String?,
      signatureUrl: json['signatureUrl'] as String?,
      phone: json['phone'] as String?,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      emailNotificationsEnabled:
          json['emailNotificationsEnabled'] as bool? ?? true,
      emailEventReminders: json['emailEventReminders'] as bool? ?? true,
      bio: json['bio'] as String?,
      interests: json['interests'] as String?,
      networkingVisible: json['networkingVisible'] as bool? ?? true,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      lastLoginAt: json['lastLoginAt'] == null
          ? null
          : DateTime.parse(json['lastLoginAt'] as String),
    );

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'fullName': instance.fullName,
      'role': _$UserRoleEnumMap[instance.role]!,
      'status': _$UserStatusEnumMap[instance.status]!,
      'avatarUrl': instance.avatarUrl,
      'signatureUrl': instance.signatureUrl,
      'phone': instance.phone,
      'phoneVerified': instance.phoneVerified,
      'emailVerified': instance.emailVerified,
      'emailNotificationsEnabled': instance.emailNotificationsEnabled,
      'emailEventReminders': instance.emailEventReminders,
      'bio': instance.bio,
      'interests': instance.interests,
      'networkingVisible': instance.networkingVisible,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'lastLoginAt': instance.lastLoginAt?.toIso8601String(),
    };

const _$UserRoleEnumMap = {
  UserRole.admin: 'ADMIN',
  UserRole.organiser: 'ORGANISER',
  UserRole.user: 'USER',
};

const _$UserStatusEnumMap = {
  UserStatus.active: 'ACTIVE',
  UserStatus.locked: 'LOCKED',
  UserStatus.pending: 'PENDING',
};
