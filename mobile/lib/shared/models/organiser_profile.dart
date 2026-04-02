import 'package:json_annotation/json_annotation.dart';

part 'organiser_profile.g.dart';

@JsonSerializable()
class OrganiserProfile {
  const OrganiserProfile({
    required this.id,
    required this.userId,
    this.userEmail,
    required this.displayName,
    this.bio,
    this.avatarUrl,
    this.logoUrl,
    this.coverUrl,
    this.website,
    this.contactEmail,
    this.contactPhone,
    required this.verified,
    required this.followerCount,
    this.eventsCount = 0,
  });

  factory OrganiserProfile.fromJson(Map<String, dynamic> json) {
    return OrganiserProfile(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      userEmail: json['userEmail'] as String? ?? json['email'] as String?,
      displayName: json['displayName'] as String? ?? json['fullName'] as String? ?? 'Unknown',
      bio: json['bio'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      logoUrl: json['logoUrl'] as String?,
      coverUrl: json['coverUrl'] as String?,
      website: json['website'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      verified: json['verified'] as bool? ?? false,
      followerCount: (json['totalFollowers'] as num?)?.toInt() ?? (json['followerCount'] as num?)?.toInt() ?? 0,
      eventsCount: (json['totalEvents'] as num?)?.toInt() ?? (json['eventsCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String userId;
  final String? userEmail;
  final String displayName;
  final String? bio;
  final String? avatarUrl;
  final String? logoUrl;
  final String? coverUrl;
  final String? website;
  final String? contactEmail;
  final String? contactPhone;
  final bool verified;
  final int followerCount;
  final int eventsCount;

  int get followersCount => followerCount;

  Map<String, dynamic> toJson() => _$OrganiserProfileToJson(this);
}
