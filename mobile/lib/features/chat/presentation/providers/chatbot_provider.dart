import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../../services/api_service.dart';
import '../models/chatbot_message.dart';

class ChatbotNotifier extends StateNotifier<AsyncValue<List<ChatbotMessage>>> {
  final ApiService _api;
  ChatbotNotifier(this._api) : super(const AsyncValue.data([])) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('chatbot_history');
      if (historyJson != null) {
        final decoded = jsonDecode(historyJson) as List;
        final messages = decoded
            .map((m) => _messageFromJson(m as Map<String, dynamic>))
            .toList();
        state = AsyncValue.data(messages);
      }
    } catch (e) {
      // Silently fail, use empty state
    }
  }

  Future<void> _saveHistory(List<ChatbotMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only save last 50 messages to prevent storage bloat
      final toSave = messages.length > 50 ? messages.sublist(messages.length - 50) : messages;
      final jsonList = toSave.map((m) => _messageToJson(m)).toList();
      await prefs.setString('chatbot_history', jsonEncode(jsonList));
    } catch (e) {
      // Silently fail
    }
  }

  Map<String, dynamic> _messageToJson(ChatbotMessage m) {
    return {
      'id': m.id,
      'content': m.content,
      'isUser': m.isUser,
      'timestamp': m.timestamp.toIso8601String(),
      'intent': m.intent,
      'dataPointsUsed': m.dataPointsUsed,
      'events': m.events?.map((e) => <String, dynamic>{
        'id': e.id,
        'title': e.title,
        'startTime': e.startTime,
        'venue': e.venue,
        'city': e.city,
        'category': e.category,
        'price': e.price,
        'approvedAttendees': e.approvedAttendees,
        'imageUrl': e.imageUrl,
      }).toList(),
    };
  }

  ChatbotMessage _messageFromJson(Map<String, dynamic> json) {
    List<ChatbotEvent>? events;
    if (json['events'] is List) {
      events = (json['events'] as List)
          .map((e) => ChatbotEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ChatbotMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      intent: json['intent'] as String?,
      dataPointsUsed: json['dataPointsUsed'] as int?,
      events: events,
    );
  }

  /// Build conversation history for AI context
  List<Map<String, String>> _buildHistory(List<ChatbotMessage> messages) {
    // Take last 10 messages (5 pairs) for context
    final recent = messages.length > 10 ? messages.sublist(messages.length - 10) : messages;
    return recent
        .where((m) => !m.isLoading && m.content.isNotEmpty)
        .map((m) {
          return <String, String>{
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.content,
          };
        })
        .toList();
  }

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    // Add user message
    final userMessage = ChatbotMessage.user(content: message);
    var messages = <ChatbotMessage>[
      ...?state.maybeWhen(data: (m) => m, orElse: () => null) ?? [],
      userMessage
    ];
    state = AsyncValue.data(messages);

    // Add loading message
    final loadingMessage = ChatbotMessage.loading();
    messages = [...messages, loadingMessage];
    state = AsyncValue.data(messages);

    // Build conversation history from previous messages (excluding current user msg and loading)
    final history = _buildHistory(messages.where((m) => !m.isLoading).toList());

    // Call API
    try {
      final response = await _api.askChatbot(message, history: history);

      // Extract events from response data
      List<ChatbotEvent> events = [];
      if (response['data'] is Map<String, dynamic>) {
        final data = response['data'] as Map<String, dynamic>;
        if (data['events'] is List) {
          events = (data['events'] as List)
              .map((e) => ChatbotEvent.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      final assistantMessage = ChatbotMessage.assistant(
        content: response['response'] as String? ?? 'No response',
        intent: response['intent'] as String? ?? 'GENERAL_QUERY',
        data: response['data'] as Map<String, dynamic>? ?? {},
        dataPointsUsed: response['dataPointsUsed'] as int? ?? 0,
        events: events.isNotEmpty ? events : null,
      );

      // Replace loading message with actual response
      messages = messages.where((m) => !m.isLoading).toList();
      messages = [...messages, assistantMessage];
      state = AsyncValue.data(messages);

      await _saveHistory(messages);
    } catch (e, st) {
      messages = messages.where((m) => !m.isLoading).toList();

      // Create user-friendly error message
      String errorContent;
      if (e.toString().contains('500')) {
        errorContent = 'The AI service is temporarily unavailable. Please try again in a moment.';
      } else if (e.toString().contains('timeout') || e.toString().contains('SocketException')) {
        errorContent = 'Connection timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('401') || e.toString().contains('403')) {
        errorContent = 'Please log in to use the AI assistant.';
      } else {
        errorContent = 'Something went wrong. Please try again.';
      }

      final errorMessage = ChatbotMessage.assistant(
        content: errorContent,
        intent: 'ERROR',
        data: {},
        dataPointsUsed: 0,
      );
      messages = [...messages, errorMessage];
      state = AsyncValue.data(messages);
    }
  }

  void clearMessages() {
    state = const AsyncValue.data([]);
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('chatbot_history');
    });
  }
}

final chatbotProvider =
    StateNotifierProvider.autoDispose<ChatbotNotifier, AsyncValue<List<ChatbotMessage>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ChatbotNotifier(api);
});
