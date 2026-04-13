import 'package:json_annotation/json_annotation.dart';

part 'event_image.g.dart';

@JsonSerializable()
class EventImage {
  final String id;
  final String eventId;
  final String? eventTitle;
  final String imageUrl;
  final String? caption;
  final int displayOrder;
  final bool isCover;
  final String? uploadedByName;
  final DateTime? createdAt;

  EventImage({
    required this.id,
    required this.eventId,
    this.eventTitle,
    required this.imageUrl,
    this.caption,
    this.displayOrder = 0,
    this.isCover = false,
    this.uploadedByName,
    this.createdAt,
  });

  factory EventImage.fromJson(Map<String, dynamic> json) => _$EventImageFromJson(json);

  Map<String, dynamic> toJson() => _$EventImageToJson(this);
}
