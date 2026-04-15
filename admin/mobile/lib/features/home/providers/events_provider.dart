import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api_service.dart';
import '../../../shared/models/event.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/events_repository.dart';

final eventsProvider =
    StateNotifierProvider.autoDispose<EventsNotifier, EventsState>((ref) {
  ref.watch(currentUserProvider);
  return EventsNotifier(ref.watch(eventsRepositoryProvider));
});

class EventsState {
  const EventsState({
    this.events = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.currentPage = 0,
  });

  final List<Event> events;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int currentPage;

  EventsState copyWith({
    List<Event>? events,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? currentPage,
  }) {
    return EventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class EventsNotifier extends StateNotifier<EventsState> {
  EventsNotifier(this._repository) : super(const EventsState());

  final EventsRepository _repository;

  Future<void> loadEvents({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 0 : state.currentPage;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: page,
    );

    try {
      final response = await _repository.getEvents(page: page);

      final newEvents = refresh ? response.content : [...state.events, ...response.content];

      state = state.copyWith(
        events: newEvents,
        isLoading: false,
        hasMore: response.hasMore,
        currentPage: response.number + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load events',
      );
    }
  }

  Future<void> refresh() async {
    await loadEvents(refresh: true);
  }
}

final selectedEventProvider = StateProvider.autoDispose<Event?>((ref) => null);

final bookmarkedEventIdsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return {};

  final api = ref.watch(apiServiceProvider);
  final ids = await api.getBookmarkedEventIds();
  return ids.toSet();
});

final bookmarkedEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final api = ref.watch(apiServiceProvider);
  final response = await api.getBookmarkedEvents();
  return response.content;
});

class BookmarkNotifier extends StateNotifier<Set<String>> {
  BookmarkNotifier(this._ref) : super({}) {
    _loadBookmarks();
  }

  final Ref _ref;

  Future<void> _loadBookmarks() async {
    try {
      final api = _ref.read(apiServiceProvider);
      final ids = await api.getBookmarkedEventIds();
      state = ids.toSet();
    } catch (_) {
    }
  }

  Future<bool> toggle(String eventId) async {
    final api = _ref.read(apiServiceProvider);
    final isNowBookmarked = await api.toggleBookmark(eventId);

    if (isNowBookmarked) {
      state = {...state, eventId};
    } else {
      state = {...state}..remove(eventId);
    }

    _ref.invalidate(bookmarkedEventsProvider);

    return isNowBookmarked;
  }

  bool isBookmarked(String eventId) => state.contains(eventId);
}

final bookmarkNotifierProvider = StateNotifierProvider.autoDispose<BookmarkNotifier, Set<String>>((ref) {
  ref.watch(currentUserProvider);
  return BookmarkNotifier(ref);
});

final vipBannerEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getHomeBannerEvents();
});

final boostedFeaturedEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getBoostedFeaturedEvents();
});
