import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/city.dart';
import '../../../../shared/models/event.dart';
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

      final newEvents = refresh ? response.content : [...state.events, ...response.content];

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

final eventsListProvider = StateNotifierProvider.autoDispose
    .family<EventsListNotifier, EventsListState, ({int? categoryId, int? cityId})>(
  (ref, params) {
    final api = ref.watch(apiServiceProvider);
    final notifier = EventsListNotifier(api, params.categoryId, params.cityId);
    unawaited(notifier.loadEvents());
    return notifier;
  },
);

final categoryNameProvider = FutureProvider.family<String?, int>((ref, id) async {
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
  if (lower.contains('ho chi minh') || lower.contains('hcm') || lower.contains('saigon')) {
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
  if (lower.contains('ho chi minh') || lower.contains('hcm') || lower.contains('saigon')) {
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
    final screenHeight = MediaQuery.of(context).size.height;
    final theme = Theme.of(context);
    final hPadding = Responsive.horizontalPadding(context);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: screenHeight * 0.35,
          pinned: true,
          backgroundColor: AppColors.primary,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 20),
              ),
              onPressed: () => context.push('/search'),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.share, color: Colors.white, size: 20),
              ),
              onPressed: () {
              },
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
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.3, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  left: hPadding,
                  right: hPadding,
                  bottom: hPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "What's Happening in",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cityName,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
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
          child: Container(
            color: theme.colorScheme.surface,
            padding: EdgeInsets.all(hPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subscribed to city updates!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9500),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Subscribe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
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
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),

        if (widget.categoryId != null || widget.cityId != null)
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context), vertical: Responsive.spacing(context, base: 12)),
              child: Row(
                children: [
                  if (widget.categoryId != null)
                    categoryName?.when(
                      data: (name) => name != null
                          ? Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Chip(
                                label: Text(name),
                                avatar: const Icon(Icons.category, size: 16),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  context.go('/events${widget.cityId != null ? '?cityId=${widget.cityId}' : ''}');
                                },
                              ),
                            )
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ) ?? const SizedBox.shrink(),
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
            unawaited(ref.read(eventsListProvider(params).notifier).loadEvents(refresh: true));
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
        dateKey = '${DateFormat('MMMM d').format(eventDate)} / ${DateFormat('EEEE').format(eventDate)}';
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
    final theme = Theme.of(context);
    final hPadding = Responsive.horizontalPadding(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: theme.scaffoldBackgroundColor,
          padding: EdgeInsets.fromLTRB(hPadding, Responsive.spacing(context, base: 20), hPadding, Responsive.spacing(context)),
          child: Text(
            dateKey,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.textTheme.bodyMedium?.color,
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
    final timeFormat = DateFormat('h:mm a');
    final startTime = timeFormat.format(event.startDate);
    final endTime = timeFormat.format(event.endDate);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth * 0.21;
    final hPadding = Responsive.horizontalPadding(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: Responsive.spacing(context, base: 10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: imageSize,
                height: imageSize,
                color: AppColors.primary.withValues(alpha: 0.1),
                child: event.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.event,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      )
                    : const Icon(
                        Icons.event,
                        color: AppColors.primary,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: Responsive.iconSize(context, base: 20),
                        height: Responsive.iconSize(context, base: 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: event.organiser?.avatarUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: event.organiser!.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                                ),
                              )
                            : _buildAvatarPlaceholder(),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.organiserName,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text(
                    event.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: Responsive.iconSize(context, base: 14),
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$startTime - $endTime',
                        style: theme.textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: event.isFree ? Colors.green[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          event.isFree ? 'FREE' : '\$${event.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: event.isFree ? Colors.green[700] : Colors.orange[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: Responsive.iconSize(context, base: 14),
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Center(
      child: Text(
        event.organiserName.isNotEmpty ? event.organiserName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: Responsive.iconSize(context, base: 64),
            color: theme.disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No events match your filter' : 'No events available',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasFilter
                ? 'Try removing some filters'
                : 'Check back later for new events',
            style: theme.textTheme.bodyMedium,
          ),
          if (hasFilter) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.go('/events'),
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: Responsive.padding(context),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: Responsive.iconSize(context, base: 64),
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
