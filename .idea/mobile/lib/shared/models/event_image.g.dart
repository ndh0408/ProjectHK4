// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_image.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventImage _$EventImageFromJson(Map<String, dynamic> json) => EventImage(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String?,
      imageUrl: json['imageUrl'] as String,
      caption: json['caption'] as String?,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      isCover: json['isCover'] as bool? ?? false,
      uploadedByName: json['uploadedByName'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$EventImageToJson(EventImage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'eventId': instance.eventId,
      'eventTitle': instance.eventTitle,
      'imageUrl': instance.imageUrl,
      'caption': instance.caption,
      'displayOrder': instance.displayOrder,
      'isCover': instance.isCover,
      'uploadedByName': instance.uploadedByName,
      'createdAt': instance.createdAt?.toIso8601String(),
    };
