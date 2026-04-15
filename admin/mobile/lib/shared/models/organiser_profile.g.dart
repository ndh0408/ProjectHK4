// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organiser_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganiserProfile _$OrganiserProfileFromJson(Map<String, dynamic> json) =>
    OrganiserProfile(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userEmail: json['userEmail'] as String?,
      displayName: json['displayName'] as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      logoUrl: json['logoUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      website: json['website'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      verified: json['verified'] as bool,
      followerCount: (json['followerCount'] as num).toInt(),
      eventsCount: (json['eventsCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$OrganiserProfileToJson(OrganiserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'userEmail': instance.userEmail,
      'displayName': instance.displayName,
      'bio': instance.bio,
      'avatarUrl': instance.avatarUrl,
      'logoUrl': instance.logoUrl,
      'coverUrl': instance.coverUrl,
      'website': instance.website,
      'contactEmail': instance.contactEmail,
      'contactPhone': instance.contactPhone,
      'verified': instance.verified,
      'followerCount': instance.followerCount,
      'eventsCount': instance.eventsCount,
    };
