import 'package:json_annotation/json_annotation.dart';

import 'certificate.dart';
import 'event.dart';

part 'registration.g.dart';

enum RegistrationStatusEnum {
  @JsonValue('PENDING')
  pending,
  @JsonValue('APPROVED')
  approved,
  @JsonValue('REJECTED')
  rejected,
  @JsonValue('WAITING_LIST')
  waitingList,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('CONFIRMED')
  confirmed,
  @JsonValue('CHECKED_IN')
  checkedIn,
  @JsonValue('NO_SHOW')
  noShow,
}

class RegistrationStatus {
  const RegistrationStatus({
    required this.isRegistered,
    this.registrationId,
    this.status,
    this.statusMessage,
    this.requiresPayment = false,
    this.ticketPrice,
    this.eventTitle,
    this.waitingListPosition,
    this.ticketTypeId,
    this.ticketTypeName,
    this.quantity = 1,
  });

  factory RegistrationStatus.fromJson(Map<String, dynamic> json) {
    RegistrationStatusEnum? parseStatus(String? statusStr) {
      if (statusStr == null) return null;
      switch (statusStr.toUpperCase()) {
        case 'PENDING':
          return RegistrationStatusEnum.pending;
        case 'APPROVED':
          return RegistrationStatusEnum.approved;
        case 'REJECTED':
          return RegistrationStatusEnum.rejected;
        case 'WAITING_LIST':
          return RegistrationStatusEnum.waitingList;
        case 'CANCELLED':
          return RegistrationStatusEnum.cancelled;
        case 'CONFIRMED':
          return RegistrationStatusEnum.confirmed;
        case 'CHECKED_IN':
          return RegistrationStatusEnum.checkedIn;
        case 'NO_SHOW':
          return RegistrationStatusEnum.noShow;
        default:
          return RegistrationStatusEnum.pending;
      }
    }

    return RegistrationStatus(
      isRegistered: (json['registered'] as bool?) ?? (json['isRegistered'] as bool?) ?? false,
      registrationId: json['registrationId'] as String?,
      status: parseStatus(json['status'] as String?),
      statusMessage: json['statusMessage'] as String?,
      requiresPayment: json['requiresPayment'] as bool? ?? false,
      ticketPrice: (json['ticketPrice'] as num?)?.toDouble(),
      eventTitle: json['eventTitle'] as String?,
      waitingListPosition: json['waitingListPosition'] as int?,
      ticketTypeId: json['ticketTypeId']?.toString(),
      ticketTypeName: json['ticketTypeName'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  final bool isRegistered;
  final String? registrationId;
  final RegistrationStatusEnum? status;
  final String? statusMessage;
  final bool requiresPayment;
  final double? ticketPrice;
  final String? eventTitle;
  final int? waitingListPosition;
  final String? ticketTypeId;
  final String? ticketTypeName;
  final int quantity;

  double get totalAmount => (ticketPrice ?? 0) * quantity;

  bool get isOnWaitingList => status == RegistrationStatusEnum.waitingList;
}

@JsonSerializable()
class Registration {
  const Registration({
    required this.id,
    required this.eventId,
    this.eventTitle,
    required this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.userAvatarUrl,
    this.event,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.approvedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.ticketCode,
    this.waitingListPosition,
    this.requiresPayment = false,
    this.ticketPrice,
    this.checkedInAt,
    this.eligibleForCertificate = false,
    this.certificate,
    this.ticketTypeId,
    this.ticketTypeName,
    this.ticketTypePrice,
    this.quantity = 1,
  });

  factory Registration.fromJson(Map<String, dynamic> json) {
    RegistrationStatusEnum parseStatus(dynamic statusValue) {
      if (statusValue == null) return RegistrationStatusEnum.pending;
      final statusStr = statusValue.toString().toUpperCase();
      switch (statusStr) {
        case 'PENDING':
          return RegistrationStatusEnum.pending;
        case 'APPROVED':
          return RegistrationStatusEnum.approved;
        case 'REJECTED':
          return RegistrationStatusEnum.rejected;
        case 'WAITING_LIST':
          return RegistrationStatusEnum.waitingList;
        case 'CANCELLED':
          return RegistrationStatusEnum.cancelled;
        case 'CONFIRMED':
          return RegistrationStatusEnum.confirmed;
        case 'CHECKED_IN':
          return RegistrationStatusEnum.checkedIn;
        case 'NO_SHOW':
          return RegistrationStatusEnum.noShow;
        default:
          return RegistrationStatusEnum.pending;
      }
    }

    return Registration(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      eventTitle: json['eventTitle'] as String?,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName'] as String?,
      userEmail: json['userEmail'] as String?,
      userPhone: json['userPhone'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      event: json['event'] != null
          ? Event.fromJson(json['event'] as Map<String, dynamic>)
          : null,
      status: parseStatus(json['status']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      rejectedAt: json['rejectedAt'] != null
          ? DateTime.parse(json['rejectedAt'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      ticketCode: json['ticketCode'] as String?,
      waitingListPosition: (json['waitingListPosition'] as num?)?.toInt(),
      requiresPayment: json['requiresPayment'] as bool? ?? false,
      ticketPrice: (json['ticketPrice'] as num?)?.toDouble(),
      checkedInAt: json['checkedInAt'] != null
          ? DateTime.parse(json['checkedInAt'] as String)
          : null,
      eligibleForCertificate: json['eligibleForCertificate'] as bool? ?? false,
      certificate: json['certificate'] != null
          ? Certificate.fromJson(json['certificate'] as Map<String, dynamic>)
          : null,
      ticketTypeId: json['ticketTypeId']?.toString(),
      ticketTypeName: json['ticketTypeName'] as String?,
      ticketTypePrice: (json['ticketTypePrice'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  final String id;
  final String eventId;
  final String? eventTitle;
  final String userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? userAvatarUrl;
  final Event? event;
  final RegistrationStatusEnum status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? ticketCode;
  final int? waitingListPosition;
  @JsonKey(defaultValue: false)
  final bool requiresPayment;
  final double? ticketPrice;
  final DateTime? checkedInAt;
  @JsonKey(defaultValue: false)
  final bool eligibleForCertificate;
  final Certificate? certificate;
  final String? ticketTypeId;
  final String? ticketTypeName;
  final double? ticketTypePrice;
  @JsonKey(defaultValue: 1)
  final int quantity;

  double get totalAmount => (ticketTypePrice ?? ticketPrice ?? 0) * quantity;

  Map<String, dynamic> toJson() => _$RegistrationToJson(this);

  bool get isPending => status == RegistrationStatusEnum.pending;
  bool get isApproved => status == RegistrationStatusEnum.approved;
  bool get isRejected => status == RegistrationStatusEnum.rejected;
  bool get isWaiting => status == RegistrationStatusEnum.waitingList;
  bool get isCancelled => status == RegistrationStatusEnum.cancelled;
  bool get isConfirmed => status == RegistrationStatusEnum.confirmed;
  bool get isCheckedIn => status == RegistrationStatusEnum.checkedIn;
  bool get isNoShow => status == RegistrationStatusEnum.noShow;

  /// User đã chính thức có vé (đã confirm hoặc đã check-in)
  bool get hasValidTicket => isConfirmed || isCheckedIn;

  /// User đã từng check-in thành công (dữ liệu uy tín)
  bool get hasAttended => checkedInAt != null;

  DateTime get registrationDate => createdAt;
}
