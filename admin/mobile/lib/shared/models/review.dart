class Review {
  const Review({
    required this.id,
    required this.rating,
    this.comment,
    this.userId,
    this.userName,
    this.userAvatarUrl,
    this.eventId,
    this.eventTitle,
    this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      userId: json['userId']?.toString(),
      userName: json['userName'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      eventId: json['eventId']?.toString(),
      eventTitle: json['eventTitle'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  final String id;
  final int rating;
  final String? comment;
  final String? userId;
  final String? userName;
  final String? userAvatarUrl;
  final String? eventId;
  final String? eventTitle;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'rating': rating,
        'comment': comment,
        'userId': userId,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'createdAt': createdAt?.toIso8601String(),
      };
}
