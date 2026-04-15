// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'coupon.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Coupon _$CouponFromJson(Map<String, dynamic> json) {
  return _Coupon.fromJson(json);
}

/// @nodoc
mixin _$Coupon {
  String get id => throw _privateConstructorUsedError;
  String get code => throw _privateConstructorUsedError;
  String? get description => throw _privateConstructorUsedError;
  String get discountType => throw _privateConstructorUsedError;
  double get discountValue => throw _privateConstructorUsedError;
  double? get maxDiscountAmount => throw _privateConstructorUsedError;
  double? get minOrderAmount => throw _privateConstructorUsedError;
  String? get status => throw _privateConstructorUsedError;
  int? get maxUsageCount => throw _privateConstructorUsedError;
  int? get usedCount => throw _privateConstructorUsedError;
  int? get maxUsagePerUser => throw _privateConstructorUsedError;
  DateTime? get validFrom => throw _privateConstructorUsedError;
  DateTime? get validUntil => throw _privateConstructorUsedError;
  DateTime? get createdAt => throw _privateConstructorUsedError;

  /// Serializes this Coupon to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CouponCopyWith<Coupon> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CouponCopyWith<$Res> {
  factory $CouponCopyWith(Coupon value, $Res Function(Coupon) then) =
      _$CouponCopyWithImpl<$Res, Coupon>;
  @useResult
  $Res call(
      {String id,
      String code,
      String? description,
      String discountType,
      double discountValue,
      double? maxDiscountAmount,
      double? minOrderAmount,
      String? status,
      int? maxUsageCount,
      int? usedCount,
      int? maxUsagePerUser,
      DateTime? validFrom,
      DateTime? validUntil,
      DateTime? createdAt});
}

/// @nodoc
class _$CouponCopyWithImpl<$Res, $Val extends Coupon>
    implements $CouponCopyWith<$Res> {
  _$CouponCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? description = freezed,
    Object? discountType = null,
    Object? discountValue = null,
    Object? maxDiscountAmount = freezed,
    Object? minOrderAmount = freezed,
    Object? status = freezed,
    Object? maxUsageCount = freezed,
    Object? usedCount = freezed,
    Object? maxUsagePerUser = freezed,
    Object? validFrom = freezed,
    Object? validUntil = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      discountType: null == discountType
          ? _value.discountType
          : discountType // ignore: cast_nullable_to_non_nullable
              as String,
      discountValue: null == discountValue
          ? _value.discountValue
          : discountValue // ignore: cast_nullable_to_non_nullable
              as double,
      maxDiscountAmount: freezed == maxDiscountAmount
          ? _value.maxDiscountAmount
          : maxDiscountAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      minOrderAmount: freezed == minOrderAmount
          ? _value.minOrderAmount
          : minOrderAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      maxUsageCount: freezed == maxUsageCount
          ? _value.maxUsageCount
          : maxUsageCount // ignore: cast_nullable_to_non_nullable
              as int?,
      usedCount: freezed == usedCount
          ? _value.usedCount
          : usedCount // ignore: cast_nullable_to_non_nullable
              as int?,
      maxUsagePerUser: freezed == maxUsagePerUser
          ? _value.maxUsagePerUser
          : maxUsagePerUser // ignore: cast_nullable_to_non_nullable
              as int?,
      validFrom: freezed == validFrom
          ? _value.validFrom
          : validFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      validUntil: freezed == validUntil
          ? _value.validUntil
          : validUntil // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CouponImplCopyWith<$Res> implements $CouponCopyWith<$Res> {
  factory _$$CouponImplCopyWith(
          _$CouponImpl value, $Res Function(_$CouponImpl) then) =
      __$$CouponImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String code,
      String? description,
      String discountType,
      double discountValue,
      double? maxDiscountAmount,
      double? minOrderAmount,
      String? status,
      int? maxUsageCount,
      int? usedCount,
      int? maxUsagePerUser,
      DateTime? validFrom,
      DateTime? validUntil,
      DateTime? createdAt});
}

/// @nodoc
class __$$CouponImplCopyWithImpl<$Res>
    extends _$CouponCopyWithImpl<$Res, _$CouponImpl>
    implements _$$CouponImplCopyWith<$Res> {
  __$$CouponImplCopyWithImpl(
      _$CouponImpl _value, $Res Function(_$CouponImpl) _then)
      : super(_value, _then);

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? code = null,
    Object? description = freezed,
    Object? discountType = null,
    Object? discountValue = null,
    Object? maxDiscountAmount = freezed,
    Object? minOrderAmount = freezed,
    Object? status = freezed,
    Object? maxUsageCount = freezed,
    Object? usedCount = freezed,
    Object? maxUsagePerUser = freezed,
    Object? validFrom = freezed,
    Object? validUntil = freezed,
    Object? createdAt = freezed,
  }) {
    return _then(_$CouponImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      description: freezed == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      discountType: null == discountType
          ? _value.discountType
          : discountType // ignore: cast_nullable_to_non_nullable
              as String,
      discountValue: null == discountValue
          ? _value.discountValue
          : discountValue // ignore: cast_nullable_to_non_nullable
              as double,
      maxDiscountAmount: freezed == maxDiscountAmount
          ? _value.maxDiscountAmount
          : maxDiscountAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      minOrderAmount: freezed == minOrderAmount
          ? _value.minOrderAmount
          : minOrderAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      status: freezed == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as String?,
      maxUsageCount: freezed == maxUsageCount
          ? _value.maxUsageCount
          : maxUsageCount // ignore: cast_nullable_to_non_nullable
              as int?,
      usedCount: freezed == usedCount
          ? _value.usedCount
          : usedCount // ignore: cast_nullable_to_non_nullable
              as int?,
      maxUsagePerUser: freezed == maxUsagePerUser
          ? _value.maxUsagePerUser
          : maxUsagePerUser // ignore: cast_nullable_to_non_nullable
              as int?,
      validFrom: freezed == validFrom
          ? _value.validFrom
          : validFrom // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      validUntil: freezed == validUntil
          ? _value.validUntil
          : validUntil // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: freezed == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CouponImpl extends _Coupon {
  const _$CouponImpl(
      {required this.id,
      required this.code,
      this.description,
      required this.discountType,
      required this.discountValue,
      this.maxDiscountAmount,
      this.minOrderAmount,
      this.status,
      this.maxUsageCount,
      this.usedCount,
      this.maxUsagePerUser,
      this.validFrom,
      this.validUntil,
      this.createdAt})
      : super._();

  factory _$CouponImpl.fromJson(Map<String, dynamic> json) =>
      _$$CouponImplFromJson(json);

  @override
  final String id;
  @override
  final String code;
  @override
  final String? description;
  @override
  final String discountType;
  @override
  final double discountValue;
  @override
  final double? maxDiscountAmount;
  @override
  final double? minOrderAmount;
  @override
  final String? status;
  @override
  final int? maxUsageCount;
  @override
  final int? usedCount;
  @override
  final int? maxUsagePerUser;
  @override
  final DateTime? validFrom;
  @override
  final DateTime? validUntil;
  @override
  final DateTime? createdAt;

  @override
  String toString() {
    return 'Coupon(id: $id, code: $code, description: $description, discountType: $discountType, discountValue: $discountValue, maxDiscountAmount: $maxDiscountAmount, minOrderAmount: $minOrderAmount, status: $status, maxUsageCount: $maxUsageCount, usedCount: $usedCount, maxUsagePerUser: $maxUsagePerUser, validFrom: $validFrom, validUntil: $validUntil, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CouponImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.discountType, discountType) ||
                other.discountType == discountType) &&
            (identical(other.discountValue, discountValue) ||
                other.discountValue == discountValue) &&
            (identical(other.maxDiscountAmount, maxDiscountAmount) ||
                other.maxDiscountAmount == maxDiscountAmount) &&
            (identical(other.minOrderAmount, minOrderAmount) ||
                other.minOrderAmount == minOrderAmount) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.maxUsageCount, maxUsageCount) ||
                other.maxUsageCount == maxUsageCount) &&
            (identical(other.usedCount, usedCount) ||
                other.usedCount == usedCount) &&
            (identical(other.maxUsagePerUser, maxUsagePerUser) ||
                other.maxUsagePerUser == maxUsagePerUser) &&
            (identical(other.validFrom, validFrom) ||
                other.validFrom == validFrom) &&
            (identical(other.validUntil, validUntil) ||
                other.validUntil == validUntil) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      code,
      description,
      discountType,
      discountValue,
      maxDiscountAmount,
      minOrderAmount,
      status,
      maxUsageCount,
      usedCount,
      maxUsagePerUser,
      validFrom,
      validUntil,
      createdAt);

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CouponImplCopyWith<_$CouponImpl> get copyWith =>
      __$$CouponImplCopyWithImpl<_$CouponImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CouponImplToJson(
      this,
    );
  }
}

abstract class _Coupon extends Coupon {
  const factory _Coupon(
      {required final String id,
      required final String code,
      final String? description,
      required final String discountType,
      required final double discountValue,
      final double? maxDiscountAmount,
      final double? minOrderAmount,
      final String? status,
      final int? maxUsageCount,
      final int? usedCount,
      final int? maxUsagePerUser,
      final DateTime? validFrom,
      final DateTime? validUntil,
      final DateTime? createdAt}) = _$CouponImpl;
  const _Coupon._() : super._();

  factory _Coupon.fromJson(Map<String, dynamic> json) = _$CouponImpl.fromJson;

  @override
  String get id;
  @override
  String get code;
  @override
  String? get description;
  @override
  String get discountType;
  @override
  double get discountValue;
  @override
  double? get maxDiscountAmount;
  @override
  double? get minOrderAmount;
  @override
  String? get status;
  @override
  int? get maxUsageCount;
  @override
  int? get usedCount;
  @override
  int? get maxUsagePerUser;
  @override
  DateTime? get validFrom;
  @override
  DateTime? get validUntil;
  @override
  DateTime? get createdAt;

  /// Create a copy of Coupon
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CouponImplCopyWith<_$CouponImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
