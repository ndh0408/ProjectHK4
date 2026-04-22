import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/smart_greeting.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/registration.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../../shared/widgets/luma_logo.dart';
import '../../../auth/providers/auth_provider.dart';
import 'package:mobile/features/chat/providers/chat_providers.dart';
import '../../providers/events_provider.dart';
import '../../providers/recommendations_provider.dart';
import '../widgets/vip_banner_carousel.dart';
import '../widgets/trending_events_section.dart';
import '../widgets/boosted_events_section.dart';
import '../widgets/ai_recommendations_section.dart';
import 'package:mobile/features/explore/presentation/screens/explore_screen.dart'
    show categoriesProvider;
import '../../../../shared/models/category.dart' as cat_model;
import 'package:cached_network_image/cached_network_image.dart';

enum LocationFilter { nearby, allTheWorld }

final locationFilterProvider =
    StateProvider<LocationFilter>((ref) => LocationFilter.allTheWorld);

final pickedForYouEventsProvider =
    FutureProvider.autoDispose<List<Event>>((ref) async {
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

final upcomingEventsProvider =
    FutureProvider.autoDispose<List<Event>>((ref) async {
  ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  final response = await api.getUpcomingEvents(size: 10);
  return response.content;
});

final myFutureRegistrationsProvider =
    FutureProvider.autoDispose<List<Registration>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  final api = ref.watch(apiServiceProvider);
  final response = await api.getMyRegistrations(upcoming: true);
  return response.content.where((r) => r.event != null).toList();
});

final myPastRegistrationsProvider =
    FutureProvider.autoDispose<List<Registration>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  final api = ref.watch(apiServiceProvider);
  final response = await api.getMyRegistrations(upcoming: false);
  return response.content.where((r) => r.event != null).toList();
});

final myFutureEventsProvider =
    FutureProvider.autoDispose<List<Event>>((ref) async {
  final registrations = await ref.watch(myFutureRegistrationsProvider.future);
  return registrations.map((r) => r.event!).toList();
});

final registrationByEventIdProvider =
    FutureProvider.autoDispose<Map<String, Registration>>((ref) async {
  final registrations = await ref.watch(myFutureRegistrationsProvider.future);
  return {for (var r in registrations) r.eventId: r};
});

final registeredEventIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final myEvents = ref.watch(myFutureEventsProvider);
  return myEvents.whenOrNull(
          data: (events) => events.map((e) => e.id).toSet()) ??
      {};
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
    final user = ref.watch(currentUserProvider);
    final myRegistrations = ref.watch(myFutureRegistrationsProvider);
    final pickedEvents = ref.watch(pickedForYouEventsProvider);
    final locationFilter = ref.watch(locationFilterProvider);
    // Unread chat counter already drives the bottom nav Alerts badge. Mirror
    // it here so the home chat entry point gets the same visual signal,
    // including group chats auto-joined when registering for an event.
    final unreadChats = ref.watch(unreadMessageCountProvider).maybeWhen(
          data: (count) => count,
          orElse: () => 0,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: AppSpacing.pageX,
        title: const LumaLogo(size: 28, showWordmark: true),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: _ChatActionButton(
              unreadCount: unreadChats,
              onPressed: () => context.push('/conversations'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(myFutureRegistrationsProvider);
          ref.invalidate(pickedForYouEventsProvider);
          ref.invalidate(vipBannerEventsProvider);
          ref.invalidate(boostedFeaturedEventsProvider);
          ref.invalidate(trendingEventsProvider);
          ref.invalidate(personalizedRecommendationsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: AppSpacing.screenPadding.copyWith(bottom: 0),
                child: _buildWelcomeCard(user),
              ),
              const SizedBox(height: AppSpacing.section),
              if (user != null) ...[
                _buildYourEventsSection(myRegistrations.whenData(
                  (regs) => regs.map((r) => r.event!).toList(),
                )),
                const SizedBox(height: AppSpacing.section),
              ],
              _buildCategoriesStrip(),
              const SizedBox(height: AppSpacing.section),
              const VipBannerCarousel(),
              const SizedBox(height: AppSpacing.section),
              const BoostedEventsSection(),
              const SizedBox(height: AppSpacing.section),
              const TrendingEventsSection(),
              const SizedBox(height: AppSpacing.section),
              const AIRecommendationsSection(),
              const SizedBox(height: AppSpacing.section),
              _buildPickedForYouSection(pickedEvents, locationFilter),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chatbot'),
        icon: const Icon(Icons.smart_toy_rounded),
        label: Text(AppLocalizations.of(context)!.askLuma),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildWelcomeCard(dynamic user) {
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      shadow: AppShadows.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SmartGreeting.getGreetingWithName(user?.fullName),
            style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            SmartGreeting.getHomeSubtitle(),
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: l10n.explore,
                icon: Icons.explore_rounded,
                onPressed: () => context.push('/explore'),
                variant: AppButtonVariant.primary,
              ),
              AppButton(
                label: l10n.myEvents,
                icon: Icons.confirmation_number_outlined,
                onPressed: () => context.push('/my-events'),
                variant: AppButtonVariant.tonal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYourEventsSection(AsyncValue<List<Event>> eventsAsync) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: l10n.yourEvents,
          subtitle: 'Upcoming bookings, tickets and check-in status',
          onTap: () => context.push('/my-events'),
        ),
        const SizedBox(height: AppSpacing.md),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return _buildNoUpcomingEventsCard();
            }
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
              itemCount: events.length > 3 ? 3 : events.length,
              itemBuilder: (context, index) {
                return _buildYourEventCard(events[index]);
              },
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.pageX),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
            child: Text('Error: ${ErrorUtils.extractMessage(e)}'),
          ),
        ),
      ],
    );
  }

  Widget _buildNoUpcomingEventsCard() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
      child: AppCard(
        background: AppColors.primarySoft,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: AppRadius.allMd,
              ),
              child: const Icon(Icons.event_note_rounded,
                  color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.noUpcomingEvents,
                    style:
                        AppTypography.h4.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.noUpcomingEventsSubtitle,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYourEventCard(Event event) {
    return EventListTile(
      event: event,
      compact: true,
      status: 'Your ticket',
      statusVariant: StatusChipVariant.info,
      onTap: () {
        ref.read(selectedEventProvider.notifier).state = event;
        context.push('/event/${event.id}');
      },
    );
  }

  Widget _buildCategoriesStrip() {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Browse Categories',
          subtitle: 'Find events that match your interests',
          onTap: () => context.push('/explore'),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 110,
          child: categoriesAsync.when(
            loading: () => ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
              itemCount: 6,
              itemBuilder: (_, __) => Container(
                width: 84,
                margin: const EdgeInsets.only(right: AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: AppRadius.allMd,
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, index) {
                  final c = categories[index];
                  return _CategoryChip(
                    category: c,
                    onTap: () => context.push('/events?categoryId=${c.id}'),
                  );
                },
              );
            },
          ),
        ),
      ],
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
        SectionHeader(
          title: l10n.pickedForYou,
          subtitle: 'Discover events with the highest booking intent',
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
          child: _buildLocationFilter(locationFilter),
        ),
        const SizedBox(height: AppSpacing.lg),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.xxxl),
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
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
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
    return AppSegmentedControl<LocationFilter>(
      value: currentFilter,
      items: [
        AppSegmentItem(
          value: LocationFilter.nearby,
          label: l10n.nearby,
          icon: Icons.near_me_rounded,
        ),
        AppSegmentItem(
          value: LocationFilter.allTheWorld,
          label: l10n.allTheWorld,
          icon: Icons.public_rounded,
        ),
      ],
      onChanged: (value) {
        ref.read(locationFilterProvider.notifier).state = value;
      },
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

  Widget _buildDateGroup(String dateLabel, List<Event> events,
      Map<String, Registration> registrationMap, AppLocalizations l10n) {
    String dayOfWeek = '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (dateLabel == l10n.today) {
      dayOfWeek = DateFormat('EEEE', l10n.localeName).format(today);
    } else if (dateLabel == l10n.tomorrow) {
      dayOfWeek = DateFormat('EEEE', l10n.localeName)
          .format(today.add(const Duration(days: 1)));
    } else {
      try {
        final parsedDate =
            DateFormat('MMMM d', l10n.localeName).parse(dateLabel);
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
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.md,
            AppSpacing.pageX,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              Text(
                dateLabel,
                style: AppTypography.h4.copyWith(color: AppColors.textPrimary),
              ),
              if (dayOfWeek.isNotEmpty) ...[
                Text(
                  ' / ',
                  style: AppTypography.h4.copyWith(color: AppColors.textLight),
                ),
                Text(
                  dayOfWeek,
                  style:
                      AppTypography.h4.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        ...events
            .map((event) => _buildEventListItem(event, registrationMap, l10n)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEventListItem(Event event,
      Map<String, Registration> registrationMap, AppLocalizations l10n) {
    final registration = registrationMap[event.id];

    final isFullyRegistered = registration != null &&
        registration.hasValidTicket &&
        !(registration.requiresPayment);

    return EventListTile(
      event: event,
      status: isFullyRegistered ? l10n.registered : null,
      statusVariant: StatusChipVariant.success,
      onTap: () {
        ref.read(selectedEventProvider.notifier).state = event;
        context.push('/event/${event.id}');
      },
    );
  }
}

/// Circular icon button for the chat entry point on the home AppBar. Shows
/// a small unread counter bubble (mirroring the bottom-nav alerts badge) so
/// users can see new messages — including event group chats auto-joined
/// after registration — without diving into the notifications tab.
class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.chat_bubble_outline_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceVariant,
          ),
          onPressed: onPressed,
          tooltip: 'Messages',
        ),
        if (hasUnread)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final cat_model.Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMd,
      child: Container(
        width: 92,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: AppRadius.allMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: category.iconUrl != null && category.iconUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: category.iconUrl!,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.category_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.category_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
