// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'boost.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventBoost _$EventBoostFromJson(Map<String, dynamic> json) => EventBoost(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String?,
      boostPackage: $enumDecode(_$BoostPackageEnumMap, json['boostPackage']),
      status: $enumDecode(_$BoostStatusEnumMap, json['status']),
      startDate: json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
      price: (json['price'] as num?)?.toDouble(),
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
      featuredOnHome: json['featuredOnHome'] as bool? ?? false,
      featuredInCategory: json['featuredInCategory'] as bool? ?? false,
      priorityInSearch: json['priorityInSearch'] as bool? ?? false,
      homeBanner: json['homeBanner'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$EventBoostToJson(EventBoost instance) =>
    <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'eventTitle': instance.eventTitle,
      'boostPackage': _$BoostPackageEnumMap[instance.boostPackage]!,
      'status': _$BoostStatusEnumMap[instance.status]!,
      'startDate': instance.startDate?.toIso8601String(),
      'endDate': instance.endDate?.toIso8601String(),
      'price': instance.price,
      'impressions': instance.impressions,
      'clicks': instance.clicks,
      'featuredOnHome': instance.featuredOnHome,
      'featuredInCategory': instance.featuredInCategory,
      'priorityInSearch': instance.priorityInSearch,
      'homeBanner': instance.homeBanner,
      'createdAt': instance.createdAt?.toIso8601String(),
    };

const _$BoostPackageEnumMap = {
  BoostPackage.basic: 'BASIC',
  BoostPackage.standard: 'STANDARD',
  BoostPackage.premium: 'PREMIUM',
  BoostPackage.vip: 'VIP',
};

const _$BoostStatusEnumMap = {
  BoostStatus.pending: 'PENDING',
  BoostStatus.active: 'ACTIVE',
  BoostStatus.expired: 'EXPIRED',
  BoostStatus.cancelled: 'CANCELLED',
};

BoostPackageInfo _$BoostPackageInfoFromJson(Map<String, dynamic> json) =>
    BoostPackageInfo(
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      durationDays: (json['durationDays'] as num).toInt(),
      boostMultiplier: (json['boostMultiplier'] as num).toDouble(),
      featuredOnHome: json['featuredOnHome'] as bool,
      featuredInCategory: json['featuredInCategory'] as bool,
      priorityInSearch: json['priorityInSearch'] as bool,
      homeBanner: json['homeBanner'] as bool,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$BoostPackageInfoToJson(BoostPackageInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'price': instance.price,
      'durationDays': instance.durationDays,
      'boostMultiplier': instance.boostMultiplier,
      'featuredOnHome': instance.featuredOnHome,
      'featuredInCategory': instance.featuredInCategory,
      'priorityInSearch': instance.priorityInSearch,
      'homeBanner': instance.homeBanner,
      'description': instance.description,
    };
