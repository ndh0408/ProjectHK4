import 'package:json_annotation/json_annotation.dart';

part 'city.g.dart';

@JsonSerializable()
class City {
  const City({
    required this.id,
    required this.name,
    this.slug,
    this.country,
    this.continent,
    this.imageUrl,
    this.eventCount = 0,
  });

  factory City.fromJson(Map<String, dynamic> json) => _$CityFromJson(json);

  final int id;
  final String name;
  final String? slug;
  final String? country;
  final String? continent;
  final String? imageUrl;
  final int eventCount;

  Map<String, dynamic> toJson() => _$CityToJson(this);
}
