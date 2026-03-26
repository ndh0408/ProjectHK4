import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_service.dart';

// State class for Google Calendar
class GoogleCalendarState {
  final bool isLoading;
  final bool isConnecting;
  final GoogleCalendarStatus? status;
  final List<CalendarSyncResult> syncedEvents;
  final String? error;

  const GoogleCalendarState({
    this.isLoading = false,
    this.isConnecting = false,
    this.status,
    this.syncedEvents = const [],
    this.error,
  });

  GoogleCalendarState copyWith({
    bool? isLoading,
    bool? isConnecting,
    GoogleCalendarStatus? status,
    List<CalendarSyncResult>? syncedEvents,
    String? error,
  }) {
    return GoogleCalendarState(
      isLoading: isLoading ?? this.isLoading,
      isConnecting: isConnecting ?? this.isConnecting,
      status: status ?? this.status,
      syncedEvents: syncedEvents ?? this.syncedEvents,
      error: error,
    );
  }

  bool get isConnected => status?.connected ?? false;
}

// Provider
final googleCalendarProvider =
    StateNotifierProvider<GoogleCalendarNotifier, GoogleCalendarState>((ref) {
  return GoogleCalendarNotifier(ref.watch(apiServiceProvider));
});

class GoogleCalendarNotifier extends StateNotifier<GoogleCalendarState> {
  final ApiService _apiService;

  GoogleCalendarNotifier(this._apiService) : super(const GoogleCalendarState()) {
    // Load status on init
    loadStatus();
  }

  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final status = await _apiService.getGoogleCalendarStatus();
      final syncedEvents = status.connected
          ? await _apiService.getSyncedEvents()
          : <CalendarSyncResult>[];
      state = state.copyWith(
        isLoading: false,
        status: status,
        syncedEvents: syncedEvents,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<String> getAuthUrl({String? redirectUri}) async {
    return _apiService.getGoogleCalendarAuthUrl(redirectUri: redirectUri);
  }

  Future<void> connect({required String code, String? redirectUri}) async {
    state = state.copyWith(isConnecting: true, error: null);
    try {
      await _apiService.connectGoogleCalendar(code: code, redirectUri: redirectUri);
      await loadStatus();
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  Future<void> disconnect() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiService.disconnectGoogleCalendar();
      state = state.copyWith(
        isLoading: false,
        status: GoogleCalendarStatus(connected: false, syncedEventsCount: 0),
        syncedEvents: [],
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<CalendarSyncResult?> syncEvent(String registrationId, {String? calendarId}) async {
    try {
      final result = await _apiService.syncEventToCalendar(registrationId, calendarId: calendarId);
      state = state.copyWith(
        syncedEvents: [...state.syncedEvents, result],
      );
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> unsyncEvent(String registrationId) async {
    try {
      await _apiService.unsyncEventFromCalendar(registrationId);
      state = state.copyWith(
        syncedEvents: state.syncedEvents
            .where((e) => e.registrationId != registrationId)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<int> syncAllEvents() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final syncedCount = await _apiService.syncAllEventsToCalendar();
      await loadStatus();
      return syncedCount;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return 0;
    }
  }

  bool isEventSynced(String registrationId) {
    return state.syncedEvents.any((e) => e.registrationId == registrationId);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Convenience provider to check if a specific event is synced
final isEventSyncedProvider = Provider.family<bool, String>((ref, registrationId) {
  final calendarState = ref.watch(googleCalendarProvider);
  return calendarState.syncedEvents.any((e) => e.registrationId == registrationId);
});
