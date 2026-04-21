import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/api_service.dart';
import '../../../../shared/models/event_chat_summary.dart';
import '../../../auth/providers/auth_provider.dart';

class EventChatsState {
  const EventChatsState({
    this.chats = const [],
    this.isLoading = false,
    this.joiningEventId,
    this.error,
  });

  final List<EventChatSummary> chats;
  final bool isLoading;
  final String? joiningEventId;
  final String? error;

  EventChatsState copyWith({
    List<EventChatSummary>? chats,
    bool? isLoading,
    String? joiningEventId,
    bool clearJoining = false,
    String? error,
    bool clearError = false,
  }) {
    return EventChatsState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      joiningEventId: clearJoining ? null : (joiningEventId ?? this.joiningEventId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class EventChatsNotifier extends StateNotifier<EventChatsState> {
  EventChatsNotifier(this._api, {required bool isLoggedIn})
      : super(const EventChatsState()) {
    if (isLoggedIn) {
      load();
    }
  }

  final ApiService _api;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final chats = await _api.getEventChats();
      state = state.copyWith(chats: chats, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() => load();

  Future<EventChatSummary?> join(String eventId) async {
    state = state.copyWith(joiningEventId: eventId, clearError: true);
    try {
      final updated = await _api.joinEventChat(eventId);
      final nextChats = [
        for (final c in state.chats) c.eventId == eventId ? updated : c,
      ];
      state = state.copyWith(chats: nextChats, clearJoining: true);
      return updated;
    } catch (e) {
      state = state.copyWith(clearJoining: true, error: e.toString());
      return null;
    }
  }

  Future<bool> leave(String eventId) async {
    try {
      await _api.leaveEventChat(eventId);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final eventChatsProvider =
    StateNotifierProvider.autoDispose<EventChatsNotifier, EventChatsState>((ref) {
  final user = ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  return EventChatsNotifier(api, isLoggedIn: user != null);
});
