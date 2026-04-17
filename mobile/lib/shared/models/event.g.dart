// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Speaker _$SpeakerFromJson(Map<String, dynamic> json) => Speaker(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      title: json['title'] as String?,
      bio: json['bio'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );

Map<String, dynamic> _$SpeakerToJson(Speaker instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'title': instance.title,
      'bio': instance.bio,
      'imageUrl': instance.imageUrl,
    };

Organiser _$OrganiserFromJson(Map<String, dynamic> json) => Organiser(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );

Map<String, dynamic> _$OrganiserToJson(Organiser instance) => <String, dynamic>{
      'id': instance.id,
      'fullName': instance.fullName,
      'avatarUrl': instance.avatarUrl,
    };

Event _$EventFromJson(Map<String, dynamic> json) => Event(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      registrationDeadline: json['registrationDeadline'] == null
          ? null
          : DateTime.parse(json['registrationDeadline'] as String),
      venue: json['venue'] as String?,
      address: json['address'] as String?,
      imageUrl: json['imageUrl'] as String?,
      ticketPrice: (json['ticketPrice'] as num?)?.toDouble(),
      capacity: (json['capacity'] as num?)?.toInt(),
      approvedCount: (json['approvedCount'] as num?)?.toInt() ?? 0,
      remainingSpots: (json['remainingSpots'] as num?)?.toInt() ?? 0,
      isFull: json['isFull'] as bool? ?? false,
      isAlmostFull: json['isAlmostFull'] as bool? ?? false,
      status: $enumDecode(_$EventStatusEnumMap, json['status']),
      category: json['category'] == null
          ? null
          : Category.fromJson(json['category'] as Map<String, dynamic>),
      city: json['city'] == null
          ? null
          : City.fromJson(json['city'] as Map<String, dynamic>),
      organiser: json['organiser'] == null
          ? null
          : Organiser.fromJson(json['organiser'] as Map<String, dynamic>),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      speakers: (json['speakers'] as List<dynamic>?)
          ?.map((e) => Speaker.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasRegistrationQuestions:
          json['hasRegistrationQuestions'] as bool? ?? false,
      registrationQuestionsCount:
          (json['registrationQuestionsCount'] as num?)?.toInt() ?? 0,
      averageRating: (json['averageRating'] as num?)?.toDouble(),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      recurrenceType:
          $enumDecodeNullable(_$RecurrenceTypeEnumMap, json['recurrenceType']),
      recurrenceInterval: (json['recurrenceInterval'] as num?)?.toInt(),
      recurrenceDaysOfWeek: (json['recurrenceDaysOfWeek'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      recurrenceEndDate: json['recurrenceEndDate'] == null
          ? null
          : DateTime.parse(json['recurrenceEndDate'] as String),
      recurrenceCount: (json['recurrenceCount'] as num?)?.toInt(),
      parentEventId: json['parentEventId'] as String?,
      occurrenceIndex: (json['occurrenceIndex'] as num?)?.toInt(),
      totalOccurrences: (json['totalOccurrences'] as num?)?.toInt() ?? 1,
      isRecurring: json['isRecurring'] as bool? ?? false,
      isBoosted: json['isBoosted'] as bool? ?? false,
      boostPackage: json['boostPackage'] as String?,
      ticketTypes: (json['ticketTypes'] as List<dynamic>?)
              ?.map((e) => TicketType.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      hasTicketTypes: json['hasTicketTypes'] as bool? ?? false,
    );

Map<String, dynamic> _$EventToJson(Event instance) => <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'registrationDeadline': instance.registrationDeadline?.toIso8601String(),
      'venue': instance.venue,
      'address': instance.address,
      'imageUrl': instance.imageUrl,
      'ticketPrice': instance.ticketPrice,
      'capacity': instance.capacity,
      'approvedCount': instance.approvedCount,
      'remainingSpots': instance.remainingSpots,
      'isFull': instance.isFull,
      'isAlmostFull': instance.isAlmostFull,
      'status': _$EventStatusEnumMap[instance.status]!,
      'category': instance.category,
      'city': instance.city,
      'organiser': instance.organiser,
      'createdAt': instance.createdAt?.toIso8601String(),
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'speakers': instance.speakers,
      'hasRegistrationQuestions': instance.hasRegistrationQuestions,
      'registrationQuestionsCount': instance.registrationQuestionsCount,
      'averageRating': instance.averageRating,
      'reviewCount': instance.reviewCount,
      'recurrenceType': _$RecurrenceTypeEnumMap[instance.recurrenceType],
      'recurrenceInterval': instance.recurrenceInterval,
      'recurrenceDaysOfWeek': instance.recurrenceDaysOfWeek,
      'recurrenceEndDate': instance.recurrenceEndDate?.toIso8601String(),
      'recurrenceCount': instance.recurrenceCount,
      'parentEventId': instance.parentEventId,
      'occurrenceIndex': instance.occurrenceIndex,
      'totalOccurrences': instance.totalOccurrences,
      'isRecurring': instance.isRecurring,
      'isBoosted': instance.isBoosted,
      'boostPackage': instance.boostPackage,
      'ticketTypes': instance.ticketTypes,
      'hasTicketTypes': instance.hasTicketTypes,
    };

const _$EventStatusEnumMap = {
  EventStatus.pending: 'PENDING',
  EventStatus.draft: 'DRAFT',
  EventStatus.published: 'PUBLISHED',
  EventStatus.approved: 'APPROVED',
  EventStatus.rejected: 'REJECTED',
  EventStatus.cancelled: 'CANCELLED',
  EventStatus.completed: 'COMPLETED',
};

const _$RecurrenceTypeEnumMap = {
  RecurrenceType.none: 'NONE',
  RecurrenceType.daily: 'DAILY',
  RecurrenceType.weekly: 'WEEKLY',
  RecurrenceType.biweekly: 'BIWEEKLY',
  RecurrenceType.monthly: 'MONTHLY',
};
