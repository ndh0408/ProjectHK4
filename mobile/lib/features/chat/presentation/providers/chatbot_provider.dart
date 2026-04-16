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
      final jsonList = messages.map((m) => _messageToJson(m)).toList();
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
      'events': m.events?.map((e) => {'id': e.id, 'title': e.title}).toList(),
    };
  }

  ChatbotMessage _messageFromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      intent: json['intent'] as String?,
      dataPointsUsed: json['dataPointsUsed'] as int?,
    );
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

    // Call API
    try {
      final response = await _api.askChatbot(message);

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
      state = AsyncValue.data(messages);
      
      final errorMessage = ChatbotMessage.assistant(
        content: 'Sorry, I encountered an error: ${e.toString()}',
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
