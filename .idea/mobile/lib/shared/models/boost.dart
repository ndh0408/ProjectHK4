import 'package:json_annotation/json_annotation.dart';

part 'boost.g.dart';

enum BoostPackage {
  @JsonValue('BASIC')
  basic,
  @JsonValue('STANDARD')
  standard,
  @JsonValue('PREMIUM')
  premium,
  @JsonValue('VIP')
  vip,
}

enum BoostStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('ACTIVE')
  active,
  @JsonValue('EXPIRED')
  expired,
  @JsonValue('CANCELLED')
  cancelled,
}

@JsonSerializable()
class EventBoost {
  const EventBoost({
    required this.id,
    required this.eventId,
    this.eventTitle,
    required this.boostPackage,
    required this.status,
    this.startDate,
    this.endDate,
    this.price,
    this.impressions = 0,
    this.clicks = 0,
    this.featuredOnHome = false,
    this.featuredInCategory = false,
    this.priorityInSearch = false,
    this.homeBanner = false,
    this.createdAt,
  });

  factory EventBoost.fromJson(Map<String, dynamic> json) {
    return EventBoost(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      eventTitle: json['eventTitle'] as String?,
      boostPackage: _parseBoostPackage(json['boostPackage'] as String?),
      status: _parseBoostStatus(json['status'] as String?),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      price: (json['price'] as num?)?.toDouble(),
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
      featuredOnHome: json['featuredOnHome'] as bool? ?? false,
      featuredInCategory: json['featuredInCategory'] as bool? ?? false,
      priorityInSearch: json['priorityInSearch'] as bool? ?? false,
      homeBanner: json['homeBanner'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  static BoostPackage _parseBoostPackage(String? value) {
    switch (value?.toUpperCase()) {
      case 'BASIC':
        return BoostPackage.basic;
      case 'STANDARD':
        return BoostPackage.standard;
      case 'PREMIUM':
        return BoostPackage.premium;
      case 'VIP':
        return BoostPackage.vip;
      default:
        return BoostPackage.basic;
    }
  }

  static BoostStatus _parseBoostStatus(String? value) {
    switch (value?.toUpperCase()) {
      case 'PENDING':
        return BoostStatus.pending;
      case 'ACTIVE':
        return BoostStatus.active;
      case 'EXPIRED':
        return BoostStatus.expired;
      case 'CANCELLED':
        return BoostStatus.cancelled;
      default:
        return BoostStatus.pending;
    }
  }

  final String id;
  final String eventId;
  final String? eventTitle;
  final BoostPackage boostPackage;
  final BoostStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? price;
  final int impressions;
  final int clicks;
  final bool featuredOnHome;
  final bool featuredInCategory;
  final bool priorityInSearch;
  final bool homeBanner;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => _$EventBoostToJson(this);

  bool get isActive => status == BoostStatus.active;

  String get packageDisplayName {
    switch (boostPackage) {
      case BoostPackage.basic:
        return 'Basic';
      case BoostPackage.standard:
        return 'Standard';
      case BoostPackage.premium:
        return 'Premium';
      case BoostPackage.vip:
        return 'VIP';
    }
  }

  double get ctr {
    if (impressions == 0) return 0;
    return (clicks / impressions) * 100;
  }
}

@JsonSerializable()
class BoostPackageInfo {
  const BoostPackageInfo({
    required this.name,
    required this.price,
    required this.durationDays,
    required this.boostMultiplier,
    required this.featuredOnHome,
    required this.featuredInCategory,
    required this.priorityInSearch,
    required this.homeBanner,
    this.description,
  });

  factory BoostPackageInfo.fromJson(Map<String, dynamic> json) {
    return BoostPackageInfo(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      boostMultiplier: (json['boostMultiplier'] as num?)?.toDouble() ?? 1.0,
      featuredOnHome: json['featuredOnHome'] as bool? ?? false,
      featuredInCategory: json['featuredInCategory'] as bool? ?? false,
      priorityInSearch: json['priorityInSearch'] as bool? ?? false,
      homeBanner: json['homeBanner'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }

  final String name;
  final double price;
  final int durationDays;
  final double boostMultiplier;
  final bool featuredOnHome;
  final bool featuredInCategory;
  final bool priorityInSearch;
  final bool homeBanner;
  final String? description;

  Map<String, dynamic> toJson() => _$BoostPackageInfoToJson(this);

  List<String> get features {
    final features = <String>[];
    features.add('${boostMultiplier.toStringAsFixed(1)}x visibility boost');
    features.add('$durationDays days duration');
    if (priorityInSearch) features.add('Priority in search results');
    if (featuredInCategory) features.add('Featured in category');
    if (featuredOnHome) features.add('Featured on home page');
    if (homeBanner) features.add('Home page banner');
    return features;
  }
}
