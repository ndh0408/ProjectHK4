class ChatbotMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String? intent;
  final Map<String, dynamic>? data;
  final int? dataPointsUsed;
  final List<ChatbotEvent>? events;
  final List<String>? suggestions;
  final bool isLoading;

  ChatbotMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.intent,
    this.data,
    this.dataPointsUsed,
    this.events,
    this.suggestions,
    this.isLoading = false,
  });

  factory ChatbotMessage.user({
    required String content,
    DateTime? timestamp,
  }) {
    return ChatbotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  factory ChatbotMessage.assistant({
    required String content,
    required String intent,
    required Map<String, dynamic> data,
    required int dataPointsUsed,
    DateTime? timestamp,
    List<ChatbotEvent>? events,
    List<String>? suggestions,
  }) {
    return ChatbotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: timestamp ?? DateTime.now(),
      intent: intent,
      data: data,
      dataPointsUsed: dataPointsUsed,
      events: events,
      suggestions: suggestions,
    );
  }

  factory ChatbotMessage.loading() {
    return ChatbotMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: '',
      isUser: false,
      timestamp: DateTime.now(),
      isLoading: true,
    );
  }
}

class ChatbotEvent {
  final String id;
  final String title;
  final String? startTime;
  final String? venue;
  final String? city;
  final String? category;
  final double? price;
  final int? approvedAttendees;
  final String? imageUrl;

  ChatbotEvent({
    required this.id,
    required this.title,
    this.startTime,
    this.venue,
    this.city,
    this.category,
    this.price,
    this.approvedAttendees,
    this.imageUrl,
  });

  factory ChatbotEvent.fromJson(Map<String, dynamic> json) {
    return ChatbotEvent(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? 'Event',
      startTime: json['startTime'] as String?,
      venue: json['venue'] as String?,
      city: json['city'] as String?,
      category: json['category'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      approvedAttendees: json['approvedAttendees'] as int?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
