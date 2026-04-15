import 'package:json_annotation/json_annotation.dart';

part 'blocked_user.g.dart';

@JsonSerializable()
class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.userId,
    required this.fullName,
    this.avatarUrl,
    this.reason,
    this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) =>
      _$BlockedUserFromJson(json);

  final String id;
  final String userId;
  final String fullName;
  final String? avatarUrl;
  final String? reason;
  final DateTime? blockedAt;

  Map<String, dynamic> toJson() => _$BlockedUserToJson(this);
}
