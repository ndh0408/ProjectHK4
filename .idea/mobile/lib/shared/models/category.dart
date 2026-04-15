import 'package:json_annotation/json_annotation.dart';

part 'category.g.dart';

@JsonSerializable()
class Category {
  const Category({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.iconUrl,
    this.eventsCount,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) =>
      _$CategoryFromJson(json);

  final int id;
  final String name;
  final String? slug;
  final String? description;
  final String? iconUrl;
  final int? eventsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => _$CategoryToJson(this);
}
