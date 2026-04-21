class EventChatSummary {
  const EventChatSummary({
    required this.eventId,
    required this.eventTitle,
    required this.joined,
    required this.closed,
    this.eventImageUrl,
    this.eventStartTime,
    this.eventEndTime,
    this.venue,
    this.conversationId,
    this.closedAt,
    this.participantCount = 0,
    this.lastMessageContent,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory EventChatSummary.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) {
      final raw = json[key];
      if (raw == null) return null;
      return DateTime.tryParse(raw as String);
    }

    return EventChatSummary(
      eventId: json['eventId'] as String,
      eventTitle: json['eventTitle'] as String? ?? '',
      eventImageUrl: json['eventImageUrl'] as String?,
      eventStartTime: parse('eventStartTime'),
      eventEndTime: parse('eventEndTime'),
      venue: json['venue'] as String?,
      conversationId: json['conversationId'] as String?,
      joined: json['joined'] as bool? ?? false,
      closed: json['closed'] as bool? ?? false,
      closedAt: parse('closedAt'),
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      lastMessageContent: json['lastMessageContent'] as String?,
      lastMessageAt: parse('lastMessageAt'),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String eventId;
  final String eventTitle;
  final String? eventImageUrl;
  final DateTime? eventStartTime;
  final DateTime? eventEndTime;
  final String? venue;
  final String? conversationId;
  final bool joined;
  final bool closed;
  final DateTime? closedAt;
  final int participantCount;
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final int unreadCount;

  EventChatSummary copyWith({
    String? eventId,
    String? eventTitle,
    String? eventImageUrl,
    DateTime? eventStartTime,
    DateTime? eventEndTime,
    String? venue,
    String? conversationId,
    bool? joined,
    bool? closed,
    DateTime? closedAt,
    int? participantCount,
    String? lastMessageContent,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return EventChatSummary(
      eventId: eventId ?? this.eventId,
      eventTitle: eventTitle ?? this.eventTitle,
      eventImageUrl: eventImageUrl ?? this.eventImageUrl,
      eventStartTime: eventStartTime ?? this.eventStartTime,
      eventEndTime: eventEndTime ?? this.eventEndTime,
      venue: venue ?? this.venue,
      conversationId: conversationId ?? this.conversationId,
      joined: joined ?? this.joined,
      closed: closed ?? this.closed,
      closedAt: closedAt ?? this.closedAt,
      participantCount: participantCount ?? this.participantCount,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
