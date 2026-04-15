// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'city.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

City _$CityFromJson(Map<String, dynamic> json) => City(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      slug: json['slug'] as String?,
      country: json['country'] as String?,
      continent: json['continent'] as String?,
      imageUrl: json['imageUrl'] as String?,
      eventCount: (json['eventCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$CityToJson(City instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'country': instance.country,
      'continent': instance.continent,
      'imageUrl': instance.imageUrl,
      'eventCount': instance.eventCount,
    };
