// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'certificate.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Certificate _$CertificateFromJson(Map<String, dynamic> json) => Certificate(
      id: json['id'] as String,
      eventId: json['eventId'] as String?,
      eventTitle: json['eventTitle'] as String?,
      userId: json['userId'] as String?,
      userName: json['userName'] as String?,
      registrationId: json['registrationId'] as String?,
      certificateUrl: json['certificateUrl'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$CertificateToJson(Certificate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'eventTitle': instance.eventTitle,
      'userId': instance.userId,
      'userName': instance.userName,
      'registrationId': instance.registrationId,
      'certificateUrl': instance.certificateUrl,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
