// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'registration.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Registration _$RegistrationFromJson(Map<String, dynamic> json) => Registration(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String?,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
      userPhone: json['userPhone'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      event: json['event'] == null
          ? null
          : Event.fromJson(json['event'] as Map<String, dynamic>),
      status: $enumDecode(_$RegistrationStatusEnumEnumMap, json['status']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      approvedAt: json['approvedAt'] == null
          ? null
          : DateTime.parse(json['approvedAt'] as String),
      rejectedAt: json['rejectedAt'] == null
          ? null
          : DateTime.parse(json['rejectedAt'] as String),
      rejectionReason: json['rejectionReason'] as String?,
      ticketCode: json['ticketCode'] as String?,
      waitingListPosition: (json['waitingListPosition'] as num?)?.toInt(),
      requiresPayment: json['requiresPayment'] as bool? ?? false,
      ticketPrice: (json['ticketPrice'] as num?)?.toDouble(),
      checkedInAt: json['checkedInAt'] == null
          ? null
          : DateTime.parse(json['checkedInAt'] as String),
      eligibleForCertificate: json['eligibleForCertificate'] as bool? ?? false,
      certificate: json['certificate'] == null
          ? null
          : Certificate.fromJson(json['certificate'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$RegistrationToJson(Registration instance) =>
    <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'eventTitle': instance.eventTitle,
      'userId': instance.userId,
      'userName': instance.userName,
      'userEmail': instance.userEmail,
      'userPhone': instance.userPhone,
      'userAvatarUrl': instance.userAvatarUrl,
      'event': instance.event,
      'status': _$RegistrationStatusEnumEnumMap[instance.status]!,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'approvedAt': instance.approvedAt?.toIso8601String(),
      'rejectedAt': instance.rejectedAt?.toIso8601String(),
      'rejectionReason': instance.rejectionReason,
      'ticketCode': instance.ticketCode,
      'waitingListPosition': instance.waitingListPosition,
      'requiresPayment': instance.requiresPayment,
      'ticketPrice': instance.ticketPrice,
      'checkedInAt': instance.checkedInAt?.toIso8601String(),
      'eligibleForCertificate': instance.eligibleForCertificate,
      'certificate': instance.certificate,
    };

const _$RegistrationStatusEnumEnumMap = {
  RegistrationStatusEnum.pending: 'PENDING',
  RegistrationStatusEnum.approved: 'APPROVED',
  RegistrationStatusEnum.rejected: 'REJECTED',
  RegistrationStatusEnum.waitingList: 'WAITING_LIST',
  RegistrationStatusEnum.cancelled: 'CANCELLED',
};
