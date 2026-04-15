import 'package:json_annotation/json_annotation.dart';

import 'category.dart';
import 'city.dart';

part 'event.g.dart';

enum EventStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('DRAFT')
  draft,
  @JsonValue('PUBLISHED')
  published,
  @JsonValue('APPROVED')
  approved,
  @JsonValue('REJECTED')
  rejected,
  @JsonValue('CANCELLED')
  cancelled,
  @JsonValue('COMPLETED')
  completed,
}

enum RecurrenceType {
  @JsonValue('NONE')
  none,
  @JsonValue('DAILY')
  daily,
  @JsonValue('WEEKLY')
  weekly,
  @JsonValue('BIWEEKLY')
  biweekly,
  @JsonValue('MONTHLY')
  monthly,
}

@JsonSerializable()
class Speaker {
  const Speaker({
    required this.id,
    required this.name,
    this.title,
    this.bio,
    this.imageUrl,
  });

  factory Speaker.fromJson(Map<String, dynamic> json) => _$SpeakerFromJson(json);

  final int id;
  final String name;
  final String? title;
  final String? bio;
  final String? imageUrl;

  Map<String, dynamic> toJson() => _$SpeakerToJson(this);
}

@JsonSerializable()
class Organiser {
  const Organiser({
    required this.id,
    required this.fullName,
    this.avatarUrl,
  });

  factory Organiser.fromJson(Map<String, dynamic> json) {
    return Organiser(
      id: json['id']?.toString() ?? '',
      fullName: json['fullName'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  final String id;
  final String fullName;
  final String? avatarUrl;

  Map<String, dynamic> toJson() => _$OrganiserToJson(this);
}

@JsonSerializable()
class Event {
  const Event({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.registrationDeadline,
    this.venue,
    this.address,
    this.imageUrl,
    this.ticketPrice,
    this.capacity,
    this.approvedCount = 0,
    this.remainingSpots = 0,
    this.isFull = false,
    this.isAlmostFull = false,
    required this.status,
    this.category,
    this.city,
    this.organiser,
    this.createdAt,
    this.latitude,
    this.longitude,
    this.speakers,
    this.hasRegistrationQuestions = false,
    this.registrationQuestionsCount = 0,
    this.averageRating,
    this.reviewCount = 0,
    this.recurrenceType,
    this.recurrenceInterval,
    this.recurrenceDaysOfWeek,
    this.recurrenceEndDate,
    this.recurrenceCount,
    this.parentEventId,
    this.occurrenceIndex,
    this.totalOccurrences = 1,
    this.isRecurring = false,
    this.isBoosted = false,
    this.boostPackage,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';

    EventStatus status;
    try {
      final statusStr = json['status'] as String? ?? 'DRAFT';
      status = EventStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == statusStr.toUpperCase(),
        orElse: () => EventStatus.draft,
      );
    } catch (_) {
      status = EventStatus.draft;
    }

    return Event(
      id: id,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : DateTime.now().add(const Duration(hours: 1)),
      registrationDeadline: json['registrationDeadline'] != null
          ? DateTime.parse(json['registrationDeadline'] as String)
          : null,
      venue: json['venue'] as String?,
      address: json['address'] as String?,
      imageUrl: json['imageUrl'] as String?,
      ticketPrice: (json['ticketPrice'] as num?)?.toDouble(),
      capacity: (json['capacity'] as num?)?.toInt(),
      approvedCount: (json['approvedCount'] as num?)?.toInt() ?? 0,
      remainingSpots: (json['remainingSpots'] as num?)?.toInt() ?? 0,
      isFull: json['isFull'] as bool? ?? json['full'] as bool? ?? false,
      isAlmostFull: json['isAlmostFull'] as bool? ?? json['almostFull'] as bool? ?? false,
      status: status,
      category: json['category'] != null
          ? Category.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      city: json['city'] != null
          ? City.fromJson(json['city'] as Map<String, dynamic>)
          : null,
      organiser: json['organiser'] != null
          ? Organiser.fromJson(json['organiser'] as Map<String, dynamic>)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      speakers: (json['speakers'] as List<dynamic>?)
          ?.map((e) => Speaker.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasRegistrationQuestions: json['hasRegistrationQuestions'] as bool? ?? false,
      registrationQuestionsCount: (json['registrationQuestionsCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      recurrenceType: _parseRecurrenceType(json['recurrenceType'] as String?),
      recurrenceInterval: (json['recurrenceInterval'] as num?)?.toInt(),
      recurrenceDaysOfWeek: (json['recurrenceDaysOfWeek'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      recurrenceEndDate: json['recurrenceEndDate'] != null
          ? DateTime.parse(json['recurrenceEndDate'] as String)
          : null,
      recurrenceCount: (json['recurrenceCount'] as num?)?.toInt(),
      parentEventId: json['parentEventId']?.toString(),
      occurrenceIndex: (json['occurrenceIndex'] as num?)?.toInt(),
      totalOccurrences: (json['totalOccurrences'] as num?)?.toInt() ?? 1,
      isRecurring: json['isRecurring'] as bool? ?? json['recurring'] as bool? ?? false,
      isBoosted: json['isBoosted'] as bool? ?? json['boosted'] as bool? ?? false,
      boostPackage: json['boostPackage'] as String?,
    );
  }

  static RecurrenceType? _parseRecurrenceType(String? type) {
    if (type == null) return null;
    switch (type.toUpperCase()) {
      case 'DAILY':
        return RecurrenceType.daily;
      case 'WEEKLY':
        return RecurrenceType.weekly;
      case 'BIWEEKLY':
        return RecurrenceType.biweekly;
      case 'MONTHLY':
        return RecurrenceType.monthly;
      case 'NONE':
      default:
        return RecurrenceType.none;
    }
  }

  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? registrationDeadline;
  final String? venue;
  final String? address;
  final String? imageUrl;
  final double? ticketPrice;
  final int? capacity;
  @JsonKey(defaultValue: 0)
  final int approvedCount;
  @JsonKey(defaultValue: 0)
  final int remainingSpots;
  @JsonKey(defaultValue: false)
  final bool isFull;
  @JsonKey(defaultValue: false)
  final bool isAlmostFull;
  final EventStatus status;
  final Category? category;
  final City? city;
  final Organiser? organiser;
  final DateTime? createdAt;
  final double? latitude;
  final double? longitude;
  final List<Speaker>? speakers;
  @JsonKey(defaultValue: false)
  final bool hasRegistrationQuestions;
  @JsonKey(defaultValue: 0)
  final int registrationQuestionsCount;
  final double? averageRating;
  @JsonKey(defaultValue: 0)
  final int reviewCount;

  final RecurrenceType? recurrenceType;
  final int? recurrenceInterval;
  final List<String>? recurrenceDaysOfWeek;
  final DateTime? recurrenceEndDate;
  final int? recurrenceCount;
  final String? parentEventId;
  final int? occurrenceIndex;
  @JsonKey(defaultValue: 1)
  final int totalOccurrences;
  @JsonKey(defaultValue: false)
  final bool isRecurring;

  @JsonKey(defaultValue: false)
  final bool isBoosted;
  final String? boostPackage;

  Map<String, dynamic> toJson() => _$EventToJson(this);

  String get location => venue ?? address ?? 'TBD';
  String get organiserId => organiser?.id ?? '';
  String get organiserName => organiser?.fullName ?? 'Unknown';
  int? get categoryId => category?.id;
  double get price => ticketPrice ?? 0.0;

  bool get isFree => ticketPrice == null || ticketPrice == 0;

  int get availableSpots => remainingSpots;

  double get fillPercentage => (capacity != null && capacity! > 0) ? approvedCount / capacity! * 100 : 0;

  DateTime get startDate => startTime;
  DateTime get endDate => endTime;
  int get registeredCount => approvedCount;

  bool get isRegistrationClosed {
    if (registrationDeadline == null) return false;
    return DateTime.now().isAfter(registrationDeadline!);
  }

  bool get isEventStarted => DateTime.now().isAfter(startTime);

  bool get isEventEnded => DateTime.now().isAfter(endTime);

  bool get canRegister => !isFull && !isRegistrationClosed && !isEventEnded;

  String? get registrationStatusMessage {
    if (isEventEnded) return 'Event has ended';
    if (isRegistrationClosed) return 'Registration closed';
    if (isFull) return 'Event is full';
    return null;
  }
}
