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
  final List<ChatbotTicket>? tickets;
  final List<ChatbotTicketType>? ticketTypes;
  final String? supportRequestId;
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
    this.tickets,
    this.ticketTypes,
    this.supportRequestId,
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
    List<ChatbotTicket>? tickets,
    List<ChatbotTicketType>? ticketTypes,
    String? supportRequestId,
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
      tickets: tickets,
      ticketTypes: ticketTypes,
      supportRequestId: supportRequestId,
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

/// Ticket payload returned by TICKET_QR and CANCEL_REGISTRATION intents.
class ChatbotTicket {
  final String registrationId;
  final String? ticketCode;
  final String? status;
  final bool checkedIn;
  final String? eventId;
  final String? eventTitle;
  final String? startTime;
  final String? venue;
  final String? address;
  final String? city;
  final String? imageUrl;

  ChatbotTicket({
    required this.registrationId,
    this.ticketCode,
    this.status,
    this.checkedIn = false,
    this.eventId,
    this.eventTitle,
    this.startTime,
    this.venue,
    this.address,
    this.city,
    this.imageUrl,
  });

  factory ChatbotTicket.fromJson(Map<String, dynamic> json) {
    return ChatbotTicket(
      registrationId: json['registrationId']?.toString() ?? '',
      ticketCode: json['ticketCode'] as String?,
      status: json['status'] as String?,
      checkedIn: json['checkedIn'] == true,
      eventId: json['eventId']?.toString(),
      eventTitle: json['eventTitle'] as String?,
      startTime: json['startTime'] as String?,
      venue: json['venue'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}

/// Ticket type option for BOOK_TICKET intent — user picks one to continue to
/// checkout.
class ChatbotTicketType {
  final String id;
  final String name;
  final String? description;
  final double price;
  final int available;
  final bool soldOut;
  final int? maxPerOrder;

  ChatbotTicketType({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.available,
    required this.soldOut,
    this.maxPerOrder,
  });

  factory ChatbotTicketType.fromJson(Map<String, dynamic> json) {
    return ChatbotTicketType(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? 'Ticket',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      available: (json['available'] as num?)?.toInt() ?? 0,
      soldOut: json['soldOut'] == true,
      maxPerOrder: (json['maxPerOrder'] as num?)?.toInt(),
    );
  }
}
