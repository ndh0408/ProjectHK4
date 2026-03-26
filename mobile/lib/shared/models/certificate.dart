import 'package:json_annotation/json_annotation.dart';

part 'certificate.g.dart';

@JsonSerializable()
class Certificate {
  final String id;
  final String? eventId;
  final String? eventTitle;
  final String? userId;
  final String? userName;
  final String? registrationId;
  final String? certificateUrl;
  final String? verificationCode;
  final DateTime? issuedAt;
  final DateTime? createdAt;

  Certificate({
    required this.id,
    this.eventId,
    this.eventTitle,
    this.userId,
    this.userName,
    this.registrationId,
    this.certificateUrl,
    this.verificationCode,
    this.issuedAt,
    this.createdAt,
  });

  factory Certificate.fromJson(Map<String, dynamic> json) =>
      _$CertificateFromJson(json);

  Map<String, dynamic> toJson() => _$CertificateToJson(this);
}
