import 'package:freezed_annotation/freezed_annotation.dart';

part 'coupon.freezed.dart';
part 'coupon.g.dart';

@freezed
class Coupon with _$Coupon {
  const factory Coupon({
    required String id,
    required String code,
    String? description,
    required String discountType,
    required double discountValue,
    double? maxDiscountAmount,
    double? minOrderAmount,
    String? status,
    int? maxUsageCount,
    int? usedCount,
    int? maxUsagePerUser,
    DateTime? validFrom,
    DateTime? validUntil,
    DateTime? createdAt,
  }) = _Coupon;

  factory Coupon.fromJson(Map<String, dynamic> json) => _$CouponFromJson(json);

  const Coupon._();

  bool get isValid {
    if (status != 'ACTIVE') return false;
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    if (maxUsageCount != null && maxUsageCount! > 0 &&
        (usedCount ?? 0) >= maxUsageCount!) return false;
    return true;
  }

  String get discountDisplay {
    if (discountType == 'PERCENTAGE') {
      return '${discountValue.toInt()}%';
    } else {
      return '\$${discountValue.toStringAsFixed(0)}';
    }
  }

  String get formattedValidity {
    if (validUntil == null) return 'No expiry';
    final daysLeft = validUntil!.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return 'Expired';
    if (daysLeft == 0) return 'Expires today';
    if (daysLeft == 1) return 'Expires tomorrow';
    return 'Expires in $daysLeft days';
  }
}
