import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/city.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../home/providers/events_provider.dart';

class EventsListState {
  const EventsListState({
    this.events = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.page = 0,
    this.error,
  });

  final List<Event> events;
  final bool isLoading;
  final bool hasMore;
  final int page;
  final String? error;

  EventsListState copyWith({
    List<Event>? events,
    bool? isLoading,
    bool? hasMore,
    int? page,
    String? error,
  }) {
    return EventsListState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      error: error,
    );
  }
}

class EventsListNotifier extends StateNotifier<EventsListState> {
  EventsListNotifier(this._api, this.categoryId, this.cityId)
      : super(const EventsListState());

  final ApiService _api;
  final int? categoryId;
  final int? cityId;

  Future<void> loadEvents({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 0 : state.page;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.getEvents(
        page: page,
        size: 20,
        categoryId: categoryId?.toString(),
        cityId: cityId?.toString(),
        upcoming: true,
      );

      final newEvents =
          refresh ? response.content : [...state.events, ...response.content];

      state = state.copyWith(
        events: newEvents,
        isLoading: false,
        hasMore: response.hasMore,
        page: page + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final eventsListProvider = StateNotifierProvider.autoDispose.family<
    EventsListNotifier, EventsListState, ({int? categoryId, int? cityId})>(
  (ref, params) {
    final api = ref.watch(apiServiceProvider);
    final notifier = EventsListNotifier(api, params.categoryId, params.cityId);
    unawaited(notifier.loadEvents());
    return notifier;
  },
);

final categoryNameProvider =
    FutureProvider.family<String?, int>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  final categories = await api.getCategories();
  final category = categories.where((c) => c.id == id).firstOrNull;
  return category?.name;
});

final cityDetailProvider = FutureProvider.family<City?, int>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  final cities = await api.getCities();
  return cities.where((c) => c.id == id).firstOrNull;
});

String _getCityImageUrl(String cityName) {
  final lower = cityName.toLowerCase();
  if (lower.contains('ho chi minh') ||
      lower.contains('hcm') ||
      lower.contains('saigon')) {
    return 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800&h=400&fit=crop';
  }
  if (lower.contains('ha noi') || lower.contains('hanoi')) {
    return 'https://images.unsplash.com/photo-1509030450996-dd1a26dda07a?w=800&h=400&fit=crop';
  }
  if (lower.contains('da nang') || lower.contains('danang')) {
    return 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&h=400&fit=crop';
  }
  if (lower.contains('bangkok')) {
    return 'https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=800&h=400&fit=crop';
  }
  if (lower.contains('singapore')) {
    return 'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=800&h=400&fit=crop';
  }
  if (lower.contains('tokyo')) {
    return 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&h=400&fit=crop';
  }
  if (lower.contains('seoul')) {
    return 'https://images.unsplash.com/photo-1546874177-9e664107314e?w=800&h=400&fit=crop';
  }
  if (lower.contains('new york')) {
    return 'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=800&h=400&fit=crop';
  }
  if (lower.contains('london')) {
    return 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=800&h=400&fit=crop';
  }
  if (lower.contains('paris')) {
    return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&h=400&fit=crop';
  }
  if (lower.contains('bogota') || lower.contains('bogotá')) {
    return 'https://images.unsplash.com/photo-1536702918858-0ee3c8e70222?w=800&h=400&fit=crop';
  }
  return 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&h=400&fit=crop';
}

String _getCityDescription(String cityName) {
  final lower = cityName.toLowerCase();
  if (lower.contains('ho chi minh') ||
      lower.contains('hcm') ||
      lower.contains('saigon')) {
    return 'Ho Chi Minh City is Vietnam\'s bustling economic hub, offering diverse tech meetups, startup events, and cultural experiences. The city blends modern innovation with rich heritage.';
  }
  if (lower.contains('ha noi') || lower.contains('hanoi')) {
    return 'Hanoi, Vietnam\'s capital, hosts a vibrant mix of traditional and modern events. From tech conferences to cultural festivals, the city offers unique experiences.';
  }
  if (lower.contains('singapore')) {
    return 'Singapore thrives as Asia\'s premier tech and business hub. The city-state hosts world-class conferences, startup events, and networking opportunities year-round.';
  }
  if (lower.contains('bangkok')) {
    return 'Bangkok combines traditional charm with modern innovation. The city offers diverse events from tech meetups to cultural experiences in a vibrant setting.';
  }
  if (lower.contains('tokyo')) {
    return 'Tokyo leads in technology and innovation with cutting-edge events, conferences, and meetups. Experience the future in Japan\'s dynamic capital.';
  }
  return 'Discover exciting events happening in $cityName. From tech meetups to cultural experiences, find your next adventure here.';
}

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key, this.categoryId, this.cityId});

  final int? categoryId;
  final int? cityId;

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final params = (categoryId: widget.categoryId, cityId: widget.cityId);
      unawaited(ref.read(eventsListProvider(params).notifier).loadEvents());
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = (categoryId: widget.categoryId, cityId: widget.cityId);
    final state = ref.watch(eventsListProvider(params));

    final cityDetail = widget.cityId != null
        ? ref.watch(cityDetailProvider(widget.cityId!))
        : null;

    final categoryName = widget.categoryId != null
        ? ref.watch(categoryNameProvider(widget.categoryId!))
        : null;

    String title = 'Events';
    String? cityName;
    if (cityDetail != null && cityDetail.hasValue && cityDetail.value != null) {
      cityName = cityDetail.value!.name;
      title = 'Events in $cityName';
    } else if (categoryName != null && categoryName.hasValue) {
      title = categoryName.value ?? 'Events';
    }

    final isCityView = widget.cityId != null && cityName != null;
    final resolvedCityName = cityName;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: isCityView && resolvedCityName != null
          ? _buildCityView(context, resolvedCityName, state, params)
          : _buildCategoryView(context, title, state, params, categoryName),
    );
  }

  Widget _buildCityView(
    BuildContext context,
    String cityName,
    EventsListState state,
    ({int? categoryId, int? cityId}) params,
  ) {
    final imageUrl = _getCityImageUrl(cityName);
    final description = _getCityDescription(cityName);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.textOnPrimary, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search,
                    color: AppColors.textOnPrimary, size: 20),
              ),
              onPressed: () => context.push('/search'),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.textPrimary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share,
                    color: AppColors.textOnPrimary, size: 20),
              ),
              onPressed: () => Share.share(
                'Check out events happening in $cityName on LUMA!\n\n$description',
                subject: 'Events in $cityName',
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.textPrimary.withValues(alpha: 0.7),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's Happening in",
                        style: TextStyle(
                          color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cityName,
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Follow city updates',
                    icon: Icons.notifications_active_outlined,
                    variant: AppButtonVariant.tonal,
                    expanded: true,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subscribed to city updates!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildEventsList(state, params),
      ],
    );
  }

  Widget _buildCategoryView(
    BuildContext context,
    String title,
    EventsListState state,
    ({int? categoryId, int? cityId}) params,
    AsyncValue<String?>? categoryName,
  ) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          pinned: true,
          title: Text(title),
        ),
        if (widget.categoryId != null || widget.cityId != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                AppSpacing.lg,
                AppSpacing.pageX,
                0,
              ),
              child: Row(
                children: [
                  if (widget.categoryId != null)
                    categoryName?.when(
                          data: (name) => name != null
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Chip(
                                    label: Text(name),
                                    avatar:
                                        const Icon(Icons.category, size: 16),
                                    deleteIcon:
                                        const Icon(Icons.close, size: 16),
                                    backgroundColor: AppColors.primarySoft,
                                    side: BorderSide(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.12),
                                    ),
                                    onDeleted: () {
                                      context.go(
                                          '/events${widget.cityId != null ? '?cityId=${widget.cityId}' : ''}');
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ) ??
                        const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        _buildEventsList(state, params),
      ],
    );
  }

  Widget _buildEventsList(
    EventsListState state,
    ({int? categoryId, int? cityId}) params,
  ) {
    if (state.error != null && state.events.isEmpty) {
      return SliverFillRemaining(
        child: _ErrorView(
          error: state.error!,
          onRetry: () {
            unawaited(ref
                .read(eventsListProvider(params).notifier)
                .loadEvents(refresh: true));
          },
        ),
      );
    }

    if (state.events.isEmpty && !state.isLoading) {
      return SliverFillRemaining(
        child: _EmptyView(
          hasFilter: widget.categoryId != null || widget.cityId != null,
        ),
      );
    }

    final groupedEvents = _groupEventsByDate(state.events);
    final dateKeys = groupedEvents.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= dateKeys.length) {
            if (state.hasMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return null;
          }

          final dateKey = dateKeys[index];
          final events = groupedEvents[dateKey]!;

          return _DateSection(
            dateKey: dateKey,
            events: events,
            onEventTap: (event) {
              ref.read(selectedEventProvider.notifier).state = event;
              context.push('/event/${event.id}');
            },
          );
        },
        childCount: dateKeys.length + (state.hasMore ? 1 : 0),
      ),
    );
  }

  Map<String, List<Event>> _groupEventsByDate(List<Event> events) {
    final Map<String, List<Event>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    for (final event in events) {
      final eventDate = DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
      );

      String dateKey;
      if (eventDate == today) {
        dateKey = 'Today / ${DateFormat('EEEE').format(eventDate)}';
      } else if (eventDate == tomorrow) {
        dateKey = 'Tomorrow / ${DateFormat('EEEE').format(eventDate)}';
      } else {
        dateKey =
            '${DateFormat('MMMM d').format(eventDate)} / ${DateFormat('EEEE').format(eventDate)}';
      }

      grouped.putIfAbsent(dateKey, () => []).add(event);
    }

    return grouped;
  }
}

class _DateSection extends StatelessWidget {
  const _DateSection({
    required this.dateKey,
    required this.events,
    required this.onEventTap,
  });

  final String dateKey;
  final List<Event> events;
  final void Function(Event) onEventTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.xl,
            AppSpacing.pageX,
            AppSpacing.sm,
          ),
          child: Text(
            dateKey,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...events.map((event) => _EventListItem(
              event: event,
              onTap: () => onEventTap(event),
            )),
      ],
    );
  }
}

class _EventListItem extends StatelessWidget {
  const _EventListItem({
    required this.event,
    required this.onTap,
  });

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
      child: EventListTile(
        event: event,
        compact: true,
        onTap: onTap,
        status: event.isFull
            ? 'Sold out'
            : event.isAlmostFull
                ? 'Almost full'
                : null,
        statusVariant:
            event.isFull ? StatusChipVariant.warning : StatusChipVariant.info,
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: EmptyState(
        icon: Icons.event_busy_rounded,
        title:
            hasFilter ? 'No events match this filter' : 'No events available',
        subtitle: hasFilter
            ? 'Try removing one of the applied filters to reveal more results.'
            : 'Check back later for newly published events and ticket releases.',
        actionLabel: hasFilter ? 'Clear filters' : null,
        onAction: hasFilter ? () => context.go('/events') : null,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.screenPadding,
      child: ErrorState(
        message: error,
        onRetry: onRetry,
      ),
    );
  }
}
