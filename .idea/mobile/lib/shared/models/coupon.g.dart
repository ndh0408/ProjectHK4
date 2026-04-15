// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coupon.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$CouponImpl _$$CouponImplFromJson(Map<String, dynamic> json) => _$CouponImpl(
      id: json['id'] as String,
      code: json['code'] as String,
      description: json['description'] as String?,
      discountType: json['discountType'] as String,
      discountValue: (json['discountValue'] as num).toDouble(),
      maxDiscountAmount: (json['maxDiscountAmount'] as num?)?.toDouble(),
      minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble(),
      status: json['status'] as String?,
      maxUsageCount: (json['maxUsageCount'] as num?)?.toInt(),
      usedCount: (json['usedCount'] as num?)?.toInt(),
      maxUsagePerUser: (json['maxUsagePerUser'] as num?)?.toInt(),
      validFrom: json['validFrom'] == null
          ? null
          : DateTime.parse(json['validFrom'] as String),
      validUntil: json['validUntil'] == null
          ? null
          : DateTime.parse(json['validUntil'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$CouponImplToJson(_$CouponImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'code': instance.code,
      'description': instance.description,
      'discountType': instance.discountType,
      'discountValue': instance.discountValue,
      'maxDiscountAmount': instance.maxDiscountAmount,
      'minOrderAmount': instance.minOrderAmount,
      'status': instance.status,
      'maxUsageCount': instance.maxUsageCount,
      'usedCount': instance.usedCount,
      'maxUsagePerUser': instance.maxUsagePerUser,
      'validFrom': instance.validFrom?.toIso8601String(),
      'validUntil': instance.validUntil?.toIso8601String(),
      'createdAt': instance.createdAt?.toIso8601String(),
    };
