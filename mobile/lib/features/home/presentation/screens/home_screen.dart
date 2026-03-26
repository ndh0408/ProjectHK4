import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/registration.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/events_provider.dart';
import '../widgets/vip_banner_carousel.dart';

enum LocationFilter { nearby, allTheWorld }

final locationFilterProvider = StateProvider<LocationFilter>((ref) => LocationFilter.allTheWorld);

final pickedForYouEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  final filter = ref.watch(locationFilterProvider);

  String? country;
  if (filter == LocationFilter.nearby) {
    country = 'Vietnam';
  }

  final response = await api.getPickedForYouEvents(country: country, size: 50);
  return response.content;
});

final upcomingEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  final response = await api.getUpcomingEvents(size: 10);
  return response.content;
});

final myFutureRegistrationsProvider = FutureProvider.autoDispose<List<Registration>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  final api = ref.watch(apiServiceProvider);
  final response = await api.getMyRegistrations(upcoming: true);
  return response.content.where((r) => r.event != null).toList();
});

final myFutureEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final registrations = await ref.watch(myFutureRegistrationsProvider.future);
  return registrations.map((r) => r.event!).toList();
});

final registrationByEventIdProvider = FutureProvider.autoDispose<Map<String, Registration>>((ref) async {
  final registrations = await ref.watch(myFutureRegistrationsProvider.future);
  return {for (var r in registrations) r.eventId: r};
});

final registeredEventIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final myEvents = ref.watch(myFutureEventsProvider);
  return myEvents.whenOrNull(data: (events) => events.map((e) => e.id).toSet()) ?? {};
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(myFutureRegistrationsProvider);
      ref.invalidate(pickedForYouEventsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final myRegistrations = ref.watch(myFutureRegistrationsProvider);
    final pickedEvents = ref.watch(pickedForYouEventsProvider);
    final locationFilter = ref.watch(locationFilterProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Text('🟡 ', style: TextStyle(fontSize: 20)),
            Text(
              'luma',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black54),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myFutureRegistrationsProvider);
          ref.invalidate(pickedForYouEventsProvider);
          ref.invalidate(vipBannerEventsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildYourEventsSection(myRegistrations.whenData(
                (regs) => regs.map((r) => r.event!).toList(),
              )),

              const SizedBox(height: 24),

              // VIP Banner Carousel - shows VIP boosted events
              const VipBannerCarousel(),

              const SizedBox(height: 24),

              _buildPickedForYouSection(pickedEvents, locationFilter),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYourEventsSection(AsyncValue<List<Event>> eventsAsync) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.yourEvents,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/my-events'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.viewAll,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: Colors.grey[600]),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return _buildNoUpcomingEventsCard();
            }
            return SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  return _buildYourEventCard(events[index]);
                },
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Error: ${ErrorUtils.extractMessage(e)}'),
          ),
        ),
      ],
    );
  }

  Widget _buildNoUpcomingEventsCard() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.event_note, color: Colors.orange[700], size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.noUpcomingEvents,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.noUpcomingEventsSubtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYourEventCard(Event event) {
    return GestureDetector(
      onTap: () {
        ref.read(selectedEventProvider.notifier).state = event;
        context.push('/event/${event.id}');
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: event.imageUrl != null
                  ? Image.network(
                      event.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildEventPlaceholder(),
                    )
                  : _buildEventPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatEventDate(event.startTime),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.event, color: Colors.orange[700]),
    );
  }

  Widget _buildPickedForYouSection(
    AsyncValue<List<Event>> eventsAsync,
    LocationFilter locationFilter,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.pickedForYou,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Location Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildLocationFilter(locationFilter),
        ),

        const SizedBox(height: 16),

        // Events grouped by date
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: EmptyState(
                  icon: Icons.event_busy,
                  title: l10n.noEventsFound,
                  subtitle: l10n.tryChangingFilter,
                  compact: true,
                ),
              );
            }
            return _buildGroupedEventsList(events);
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorState(
              message: ErrorUtils.extractMessage(e),
              onRetry: () => ref.invalidate(pickedForYouEventsProvider),
            ),
          ),
        ),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildLocationFilter(LocationFilter currentFilter) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        _buildFilterChip(
          label: l10n.nearby,
          isSelected: currentFilter == LocationFilter.nearby,
          onTap: () {
            ref.read(locationFilterProvider.notifier).state = LocationFilter.nearby;
          },
        ),
        const SizedBox(width: 8),
        _buildFilterChip(
          label: l10n.allTheWorld,
          isSelected: currentFilter == LocationFilter.allTheWorld,
          onTap: () {
            ref.read(locationFilterProvider.notifier).state = LocationFilter.allTheWorld;
          },
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.grey[200] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.grey[400]! : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black87 : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedEventsList(List<Event> events) {
    final l10n = AppLocalizations.of(context)!;
    final registrationMapAsync = ref.watch(registrationByEventIdProvider);
    final registrationMap = registrationMapAsync.valueOrNull ?? {};

    final groupedEvents = <String, List<Event>>{};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    for (final event in events) {
      final eventDate = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );

      String dateKey;
      if (eventDate.isAtSameMomentAs(today)) {
        dateKey = l10n.today;
      } else if (eventDate.isAtSameMomentAs(tomorrow)) {
        dateKey = l10n.tomorrow;
      } else {
        dateKey = DateFormat('MMMM d', l10n.localeName).format(eventDate);
      }

      groupedEvents.putIfAbsent(dateKey, () => []).add(event);
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: groupedEvents.length,
      itemBuilder: (context, index) {
        final dateKey = groupedEvents.keys.elementAt(index);
        final dateEvents = groupedEvents[dateKey]!;

        return _buildDateGroup(dateKey, dateEvents, registrationMap, l10n);
      },
    );
  }

  Widget _buildDateGroup(String dateLabel, List<Event> events, Map<String, Registration> registrationMap, AppLocalizations l10n) {
    String dayOfWeek = '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (dateLabel == l10n.today) {
      dayOfWeek = DateFormat('EEEE', l10n.localeName).format(today);
    } else if (dateLabel == l10n.tomorrow) {
      dayOfWeek = DateFormat('EEEE', l10n.localeName).format(today.add(const Duration(days: 1)));
    } else {
      try {
        final parsedDate = DateFormat('MMMM d', l10n.localeName).parse(dateLabel);
        final fullDate = DateTime(now.year, parsedDate.month, parsedDate.day);
        dayOfWeek = DateFormat('EEEE', l10n.localeName).format(fullDate);
      } catch (_) {
        dayOfWeek = '';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (dayOfWeek.isNotEmpty) ...[
                Text(
                  ' / ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                  ),
                ),
                Text(
                  dayOfWeek,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ],
          ),
        ),

        ...events.map((event) => _buildEventListItem(event, registrationMap, l10n)),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEventListItem(Event event, Map<String, Registration> registrationMap, AppLocalizations l10n) {
    final registration = registrationMap[event.id];

    final isFullyRegistered = registration != null &&
        registration.status == RegistrationStatusEnum.approved &&
        !(registration.requiresPayment);

    return GestureDetector(
      onTap: () {
        ref.read(selectedEventProvider.notifier).state = event;
        context.push('/event/${event.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image with registered indicator
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: event.imageUrl != null
                      ? Image.network(
                          event.imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildListItemPlaceholder(),
                        )
                      : _buildListItemPlaceholder(),
                ),
                // Only show check icon when fully registered (approved + paid if needed)
                if (isFullyRegistered)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Event Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Organiser row with avatar
                  Row(
                    children: [
                      // Organiser avatar
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: event.organiser?.avatarUrl != null
                            ? NetworkImage(event.organiser!.avatarUrl!)
                            : null,
                        child: event.organiser?.avatarUrl == null
                            ? Text(
                                (event.organiser?.fullName ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.organiser?.fullName ?? 'Unknown Organiser',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Only show "Registered" badge when fully registered
                      if (isFullyRegistered)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 10, color: Colors.green),
                              const SizedBox(width: 3),
                              Text(
                                l10n.registered,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Event Title
                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Time and Location
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(event.startTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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

  Widget _buildListItemPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.purple[300]!, Colors.blue[300]!],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.event, color: Colors.white, size: 32),
    );
  }

  String _formatEventDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);

    if (eventDay.isAtSameMomentAs(today)) {
      return 'Today, ${DateFormat('h:mm a').format(date)}';
    } else if (eventDay.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      return 'Tomorrow, ${DateFormat('h:mm a').format(date)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }
}
