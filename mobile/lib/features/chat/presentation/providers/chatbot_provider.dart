import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../services/api_service.dart';
import '../models/chatbot_message.dart';

/// State notifier that talks to the LUMA AI Assistant backend
/// (`POST /user/assistant/chat`). The backend itself is a real OpenAI
/// ChatGPT-powered LLM with RAG over the events DB and a hard scope limiter —
/// this provider only manages local message state, history persistence, and cancellation.
class ChatbotNotifier extends StateNotifier<AsyncValue<List<ChatbotMessage>>> {
  ChatbotNotifier(this._api) : super(const AsyncValue.data([])) {
    _loadHistory();
  }

  final ApiService _api;
  CancelToken? _activeRequest;

  static const _historyKey = 'chatbot_history';
  static const _maxStored = 50;
  static const _historyContextWindow = 10;

  /// Lightweight context the backend uses to resolve pronouns like
  /// "this event", "cái này". Mobile updates this as the user navigates.
  String? _activeEventId;
  String? _activeRegistrationId;
  final List<String> _lastEventIds = [];

  /// Called by screens (event detail, my-tickets) so the bot can answer
  /// "là gì", "bao nhiêu" without the user retyping the name.
  void setActiveEvent(String? eventId) {
    _activeEventId = eventId;
  }

  void setActiveRegistration(String? registrationId) {
    _activeRegistrationId = registrationId;
  }

  Map<String, dynamic> _buildSessionContext() {
    final ctx = <String, dynamic>{};
    if (_activeEventId != null) ctx['activeEventId'] = _activeEventId;
    if (_activeRegistrationId != null) {
      ctx['activeRegistrationId'] = _activeRegistrationId;
    }
    if (_lastEventIds.isNotEmpty) ctx['lastEventIds'] = _lastEventIds;
    return ctx;
  }

  /// True while the backend is processing a message. UI should block
  /// the send button to prevent duplicate requests.
  bool get isThinking {
    final list = state.valueOrNull;
    if (list == null || list.isEmpty) return false;
    return list.last.isLoading;
  }

  List<ChatbotMessage> get _messages =>
      state.valueOrNull ?? const <ChatbotMessage>[];

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as List<dynamic>;
      final messages = decoded
          .map((m) => _messageFromJson(m as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(messages);
    } catch (_) {
      // Corrupt cache — ignore and start fresh.
    }
  }

  Future<void> _saveHistory(List<ChatbotMessage> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = messages.length > _maxStored
          ? messages.sublist(messages.length - _maxStored)
          : messages;
      final jsonList = toSave
          .where((m) => !m.isLoading)
          .map(_messageToJson)
          .toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
    } catch (_) {
      // Non-critical — user will simply lose persistence for this turn.
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
      'suggestions': m.suggestions,
      'events': m.events
          ?.map((e) => <String, dynamic>{
                'id': e.id,
                'title': e.title,
                'startTime': e.startTime,
                'venue': e.venue,
                'city': e.city,
                'category': e.category,
                'price': e.price,
                'approvedAttendees': e.approvedAttendees,
                'imageUrl': e.imageUrl,
              })
          .toList(),
    };
  }

  ChatbotMessage _messageFromJson(Map<String, dynamic> json) {
    List<ChatbotEvent>? events;
    final rawEvents = json['events'];
    if (rawEvents is List) {
      events = rawEvents
          .map((e) => ChatbotEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    List<String>? suggestions;
    final rawSug = json['suggestions'];
    if (rawSug is List) {
      suggestions = rawSug.map((s) => s.toString()).toList();
    }
    return ChatbotMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      intent: json['intent'] as String?,
      dataPointsUsed: json['dataPointsUsed'] as int?,
      suggestions: suggestions,
      events: events,
    );
  }

  /// Last 10 non-loading messages formatted for the backend context window.
  List<Map<String, String>> _buildHistory(List<ChatbotMessage> messages) {
    final clean =
        messages.where((m) => !m.isLoading && m.content.isNotEmpty).toList();
    final recent = clean.length > _historyContextWindow
        ? clean.sublist(clean.length - _historyContextWindow)
        : clean;
    return recent
        .map((m) => <String, String>{
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();
  }

  Future<void> sendMessage(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    if (isThinking) return; // Prevent duplicate in-flight requests.

    final userMessage = ChatbotMessage.user(content: trimmed);
    var messages = <ChatbotMessage>[..._messages, userMessage];
    state = AsyncValue.data(messages);

    final history = _buildHistory(messages);

    messages = [...messages, ChatbotMessage.loading()];
    state = AsyncValue.data(messages);

    await _dispatch(trimmed, history, messages);
  }

  /// Remove the last assistant reply (if any) and re-ask the last user turn.
  Future<void> regenerateLast() async {
    if (isThinking) return;
    final list = _messages;
    if (list.isEmpty) return;

    final lastUserIndex = list.lastIndexWhere((m) => m.isUser);
    if (lastUserIndex == -1) return;
    final lastUser = list[lastUserIndex];

    final trimmed = list.sublist(0, lastUserIndex + 1);
    final history = _buildHistory(trimmed);
    final withLoading = [...trimmed, ChatbotMessage.loading()];
    state = AsyncValue.data(withLoading);

    await _dispatch(lastUser.content, history, withLoading);
  }

  /// Abort the in-flight request and remove the loading bubble.
  void cancelInFlight() {
    if (!isThinking) return;
    _activeRequest?.cancel('user_cancelled');
    _activeRequest = null;
    if (!mounted) return;
    final cleaned = _messages.where((m) => !m.isLoading).toList();
    state = AsyncValue.data(cleaned);
  }

  @override
  void dispose() {
    // Screen popped while an AI request was mid-flight — cancel the token
    // so Dio doesn't call back into a disposed notifier (would throw).
    _activeRequest?.cancel('notifier_disposed');
    _activeRequest = null;
    super.dispose();
  }

  Future<void> _dispatch(
    String prompt,
    List<Map<String, String>> history,
    List<ChatbotMessage> withLoading,
  ) async {
    final token = CancelToken();
    _activeRequest = token;
    try {
      final response = await _api.askChatbot(
        prompt,
        history: history,
        sessionContext: _buildSessionContext(),
        cancelToken: token,
      );

      final events = <ChatbotEvent>[];
      final tickets = <ChatbotTicket>[];
      final ticketTypes = <ChatbotTicketType>[];
      String? supportRequestId;

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        if (data['events'] is List) {
          for (final e in data['events'] as List) {
            if (e is Map<String, dynamic>) {
              events.add(ChatbotEvent.fromJson(e));
            }
          }
        }
        // EVENT_DETAILS returns a single "event" — render it as a 1-item list.
        if (data['event'] is Map<String, dynamic>) {
          events.add(ChatbotEvent.fromJson(data['event'] as Map<String, dynamic>));
        }
        if (data['tickets'] is List) {
          for (final t in data['tickets'] as List) {
            if (t is Map<String, dynamic>) {
              tickets.add(ChatbotTicket.fromJson(t));
            }
          }
        }
        if (data['registration'] is Map<String, dynamic>) {
          tickets.add(ChatbotTicket.fromJson(data['registration'] as Map<String, dynamic>));
        }
        if (data['ticketTypes'] is List) {
          for (final t in data['ticketTypes'] as List) {
            if (t is Map<String, dynamic>) {
              ticketTypes.add(ChatbotTicketType.fromJson(t));
            }
          }
        }
        if (data['supportRequestId'] != null) {
          supportRequestId = data['supportRequestId'].toString();
        }
      }

      // Remember the last batch of events so follow-up references resolve.
      if (events.isNotEmpty) {
        _lastEventIds
          ..clear()
          ..addAll(events.map((e) => e.id).where((id) => id.isNotEmpty));
      }

      List<String>? suggestions;
      final rawSug = response['suggestions'];
      if (rawSug is List) {
        suggestions = rawSug.map((s) => s.toString()).toList();
      }

      final assistant = ChatbotMessage.assistant(
        content: (response['response'] as String?)?.trim().isNotEmpty == true
            ? response['response'] as String
            : 'No response',
        intent: response['intent'] as String? ?? 'GENERAL_QUERY',
        data: (response['data'] as Map<String, dynamic>?) ?? const {},
        dataPointsUsed: response['dataPointsUsed'] as int? ?? 0,
        events: events.isNotEmpty ? events : null,
        tickets: tickets.isNotEmpty ? tickets : null,
        ticketTypes: ticketTypes.isNotEmpty ? ticketTypes : null,
        supportRequestId: supportRequestId,
        suggestions: suggestions,
      );

      if (!mounted) return;
      final settled = withLoading.where((m) => !m.isLoading).toList()
        ..add(assistant);
      state = AsyncValue.data(settled);
      await _saveHistory(settled);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        // User cancelled OR notifier disposed — nothing to do.
        return;
      }
      if (!mounted) return;
      final settled = withLoading.where((m) => !m.isLoading).toList()
        ..add(_errorMessageFor(e, withLoading));
      state = AsyncValue.data(settled);
    } catch (e) {
      if (!mounted) return;
      final settled = withLoading.where((m) => !m.isLoading).toList()
        ..add(_errorMessageFor(e, withLoading));
      state = AsyncValue.data(settled);
    } finally {
      if (identical(_activeRequest, token)) _activeRequest = null;
    }
  }

  ChatbotMessage _errorMessageFor(Object e, List<ChatbotMessage> context) {
    final raw = e.toString();
    final vi = _lastUserMessageLooksVietnamese(context);

    String content;
    if (raw.contains('500')) {
      content = vi
          ? 'Dịch vụ AI đang tạm thời không khả dụng. Vui lòng thử lại sau ít phút.'
          : 'The AI service is temporarily unavailable. Please try again in a moment.';
    } else if (raw.contains('timeout') || raw.contains('SocketException')) {
      content = vi
          ? 'Kết nối bị quá thời gian. Kiểm tra mạng và thử lại giúp mình.'
          : 'Connection timed out. Please check your internet and try again.';
    } else if (raw.contains('401') || raw.contains('403')) {
      content = vi
          ? 'Bạn cần đăng nhập để dùng trợ lý AI.'
          : 'Please log in to use the AI assistant.';
    } else {
      content = vi
          ? 'Có lỗi xảy ra. Vui lòng thử lại.'
          : 'Something went wrong. Please try again.';
    }
    return ChatbotMessage.assistant(
      content: content,
      intent: 'ERROR',
      data: const {},
      dataPointsUsed: 0,
    );
  }

  /// Heuristic: does the most recent user turn contain Vietnamese diacritics?
  bool _lastUserMessageLooksVietnamese(List<ChatbotMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (!m.isUser) continue;
      const markers = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
      final lower = m.content.toLowerCase();
      for (int c = 0; c < markers.length; c++) {
        if (lower.contains(markers[c])) return true;
      }
      return false;
    }
    return false;
  }

  Future<void> clearMessages() async {
    cancelInFlight();
    state = const AsyncValue.data([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}

/// Kept alive across screens so other features (event detail, my-tickets)
/// can prime the session context ("user is currently viewing event X") and
/// the bot can answer follow-up questions without the user retyping.
final chatbotProvider = StateNotifierProvider<ChatbotNotifier,
    AsyncValue<List<ChatbotMessage>>>((ref) {
  final api = ref.watch(apiServiceProvider);
  return ChatbotNotifier(api);
});
