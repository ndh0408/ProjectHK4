class Question {
  const Question({
    required this.id,
    required this.eventId,
    this.eventTitle,
    required this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.question,
    this.answer,
    this.isAnswered = false,
    required this.createdAt,
    this.answeredAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      eventTitle: json['eventTitle'] as String?,
      userId: json['userId']?.toString() ?? '',
      userName: json['userName'] as String?,
      userAvatarUrl: json['userAvatarUrl'] as String?,
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String?,
      isAnswered: json['isAnswered'] as bool? ?? json['answered'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      answeredAt: json['answeredAt'] != null
          ? DateTime.parse(json['answeredAt'] as String)
          : null,
    );
  }

  final String id;
  final String eventId;
  final String? eventTitle;
  final String userId;
  final String? userName;
  final String? userAvatarUrl;
  final String question;
  final String? answer;
  final bool isAnswered;
  final DateTime createdAt;
  final DateTime? answeredAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'eventTitle': eventTitle,
        'userId': userId,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'question': question,
        'answer': answer,
        'isAnswered': isAnswered,
        'createdAt': createdAt.toIso8601String(),
        'answeredAt': answeredAt?.toIso8601String(),
      };
}
