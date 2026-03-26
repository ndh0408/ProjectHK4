import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

enum UserRole {
  @JsonValue('ADMIN')
  admin,
  @JsonValue('ORGANISER')
  organiser,
  @JsonValue('USER')
  user,
}

enum UserStatus {
  @JsonValue('ACTIVE')
  active,
  @JsonValue('LOCKED')
  locked,
  @JsonValue('PENDING')
  pending,
}

@JsonSerializable()
class User {
  const User({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
    required this.status,
    this.avatarUrl,
    this.signatureUrl,
    this.phone,
    this.phoneVerified = false,
    this.emailVerified = false,
    this.emailNotificationsEnabled = true,
    this.emailEventReminders = true,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final String id;
  final String email;
  final String? fullName;
  final UserRole role;
  final UserStatus status;
  final String? avatarUrl;
  final String? signatureUrl;
  final String? phone;
  @JsonKey(defaultValue: false)
  final bool phoneVerified;
  @JsonKey(defaultValue: false)
  final bool emailVerified;
  @JsonKey(defaultValue: true)
  final bool emailNotificationsEnabled;
  @JsonKey(defaultValue: true)
  final bool emailEventReminders;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  Map<String, dynamic> toJson() => _$UserToJson(this);

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    UserStatus? status,
    String? avatarUrl,
    String? signatureUrl,
    String? phone,
    bool? phoneVerified,
    bool? emailVerified,
    bool? emailNotificationsEnabled,
    bool? emailEventReminders,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      status: status ?? this.status,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      phone: phone ?? this.phone,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      emailNotificationsEnabled: emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      emailEventReminders: emailEventReminders ?? this.emailEventReminders,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
