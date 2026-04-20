import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/models/city.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/organiser_profile.dart';
import '../../../../shared/models/event_image.dart';
import '../../../home/providers/events_provider.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCategories();
});

final citiesProvider = FutureProvider<List<City>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCities();
});

final galleryPreviewProvider = FutureProvider<List<EventImage>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getGalleryImages(page: 0, size: 6);
  return response.content;
});

final featuredOrganisersProvider =
    FutureProvider<List<OrganiserProfile>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getFeaturedOrganisers();
});

final hcmEventsProvider = FutureProvider<List<Event>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getEvents(cityId: '1', size: 5, upcoming: true);
  return response.content;
});

final searchQueryProvider = StateProvider<String>((ref) => '');

IconData _getCategoryIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tech') || lower.contains('technology')) {
    return Icons.computer;
  }
  if (lower.contains('ai') || lower.contains('artificial')) {
    return Icons.psychology;
  }
  if (lower.contains('climate') || lower.contains('environment')) {
    return Icons.eco;
  }
  if (lower.contains('sport') || lower.contains('fitness')) {
    return Icons.fitness_center;
  }
  if (lower.contains('food') || lower.contains('beverage') || lower.contains('drink')) {
    return Icons.restaurant;
  }
  if (lower.contains('art') || lower.contains('culture')) {
    return Icons.palette;
  }
  if (lower.contains('health') || lower.contains('wellness')) {
    return Icons.favorite;
  }
  if (lower.contains('music')) return Icons.music_note;
  if (lower.contains('crypto') || lower.contains('blockchain')) {
    return Icons.currency_bitcoin;
  }
  if (lower.contains('business') || lower.contains('startup')) {
    return Icons.business;
  }
  if (lower.contains('education') || lower.contains('learning')) {
    return Icons.school;
  }
  if (lower.contains('web') || lower.contains('internet')) {
    return Icons.language;
  }
  return Icons.category;
}

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider);
    final cities = ref.watch(citiesProvider);
    final organisers = ref.watch(featuredOrganisersProvider);
    final hcmEvents = ref.watch(hcmEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        title: Text(l10n.explore),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Compare Events',
            onPressed: () => context.push('/compare-events'),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(citiesProvider);
          ref.invalidate(featuredOrganisersProvider);
          ref.invalidate(hcmEventsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              _SectionHeader(
                title: 'Ho Chi Minh City',
                subtitle: l10n.popularEvents,
                onViewAll: () => context.push('/events?cityId=1'),
              ),
              const SizedBox(height: 4),
              hcmEvents.when(
                data: (events) => events.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          l10n.noUpcomingEventsShort,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return _PopularEventCard(
                            event: event,
                            onTap: () {
                              ref
                                  .read(selectedEventProvider.notifier)
                                  .state = event;
                              context.push('/event/${event.id}');
                            },
                          );
                        },
                      ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _ErrorMessage(
                  message: ErrorUtils.extractMessage(e),
                  onRetry: () => ref.invalidate(hcmEventsProvider),
                ),
              ),

              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.browseByCategory,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
                child: categories.when(
                  data: (data) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final category = data[index];
                      return _CategoryChip(
                        category: category,
                        onTap: () => context
                            .push('/events?categoryId=${category.id}'),
                      );
                    },
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorMessage(
                    message: ErrorUtils.extractMessage(e),
                    onRetry: () => ref.invalidate(categoriesProvider),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _SectionHeader(
                title: l10n.cities,
                onViewAll: () => context.push('/cities'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: cities.when(
                  data: (data) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: data.length,
                    itemBuilder: (context, index) {
                      final city = data[index];
                      return _CityCard(
                        city: city,
                        onTap: () => context.push('/events?cityId=${city.id}'),
                      );
                    },
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorMessage(
                    message: ErrorUtils.extractMessage(e),
                    onRetry: () => ref.invalidate(citiesProvider),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              _SectionHeader(
                title: 'Gallery',
                subtitle: 'Photos from events',
                onViewAll: () => context.push('/gallery'),
              ),
              const SizedBox(height: 12),
              _GalleryPreview(),

              const SizedBox(height: 28),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.featuredCalendars,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              organisers.when(
                data: (data) => ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.length > 6 ? 6 : data.length,
                  itemBuilder: (context, index) {
                    final organiser = data[index];
                    return _FeaturedCalendarCard(
                      organiser: organiser,
                      onTap: () =>
                          context.push('/organiser/${organiser.id}'),
                    );
                  },
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: _ErrorMessage(
                    message: ErrorUtils.extractMessage(e),
                    onRetry: () =>
                        ref.invalidate(featuredOrganisersProvider),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.onViewAll,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onViewAll != null)
            GestureDetector(
              onTap: onViewAll,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.viewAll,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PopularEventCard extends StatelessWidget {
  const _PopularEventCard({required this.event, required this.onTap});

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('EEE h:mm a');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 88,
                    height: 88,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: event.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: event.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.event,
                              color: AppColors.primary,
                              size: 28,
                            ),
                          )
                        : const Icon(
                            Icons.event,
                            color: AppColors.primary,
                            size: 28,
                          ),
                  ),
                ),
                if (event.isFull)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.soldOut,
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                        child: event.organiser?.avatarUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: event.organiser!.avatarUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                size: 12,
                                color: AppColors.primary,
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.organiserName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (event.isFull)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark,
                                  size: 12, color: AppColors.warning),
                              const SizedBox(width: 2),
                              Text(
                                l10n.soldOut,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dateFormat.format(event.startDate),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: event.isFree ? AppColors.successLight : AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          event.isFree ? l10n.free.toUpperCase() : '\$${event.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: event.isFree ? AppColors.success : AppColors.primary,
                          ),
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
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(category.name),
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({
    required this.city,
    required this.onTap,
  });

  final City city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getCityImageUrl(city.name);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        child: const Icon(
                          Icons.location_city,
                          color: AppColors.primary,
                          size: 40,
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.7),
                            AppColors.primaryDark,
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.location_city,
                        color: AppColors.textOnPrimary.withValues(alpha: 0.7),
                        size: 40,
                      ),
                    ),

              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.textPrimary.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: 12,
                bottom: 12,
                right: 12,
                child: Text(
                  city.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 4,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _stripMarkdown(String text) {
  String _first(Match m) => m.group(1) ?? '';
  return text
      .replaceAll(RegExp(r'#{1,6}\s*'), '')
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), _first)
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), _first)
      .replaceAllMapped(RegExp(r'__(.+?)__'), _first)
      .replaceAllMapped(RegExp(r'_(.+?)_'), _first)
      .replaceAllMapped(RegExp(r'~~(.+?)~~'), _first)
      .replaceAllMapped(RegExp(r'\[(.+?)\]\(.+?\)'), _first)
      .replaceAllMapped(RegExp(r'`(.+?)`'), _first)
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

String? _getCityImageUrl(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('ho chi minh') || lower.contains('hcm') || lower.contains('saigon')) {
    return 'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=400&h=250&fit=crop';
  }
  if (lower.contains('ha noi') || lower.contains('hanoi')) {
    return 'https://images.unsplash.com/photo-1509030450996-dd1a26dda07a?w=400&h=250&fit=crop';
  }
  if (lower.contains('da nang') || lower.contains('danang')) {
    return 'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=400&h=250&fit=crop';
  }
  if (lower.contains('bangkok')) {
    return 'https://images.unsplash.com/photo-1508009603885-50cf7c579365?w=400&h=250&fit=crop';
  }
  if (lower.contains('singapore')) {
    return 'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=400&h=250&fit=crop';
  }
  if (lower.contains('tokyo')) {
    return 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=400&h=250&fit=crop';
  }
  if (lower.contains('seoul')) {
    return 'https://images.unsplash.com/photo-1546874177-9e664107314e?w=400&h=250&fit=crop';
  }
  if (lower.contains('new york')) {
    return 'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=400&h=250&fit=crop';
  }
  if (lower.contains('london')) {
    return 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&h=250&fit=crop';
  }
  if (lower.contains('paris')) {
    return 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&h=250&fit=crop';
  }
  if (lower.contains('los angeles')) {
    return 'https://images.unsplash.com/photo-1534190760961-74e8c1c5c3da?w=400&h=250&fit=crop';
  }
  return null;
}

class _FeaturedCalendarCard extends StatelessWidget {
  const _FeaturedCalendarCard({
    required this.organiser,
    required this.onTap,
  });

  final OrganiserProfile organiser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: (organiser.logoUrl ?? organiser.avatarUrl) != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: organiser.logoUrl ?? organiser.avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Text(
                            organiser.displayName[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        organiser.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          organiser.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (organiser.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${organiser.eventsCount} events • ${organiser.followersCount} followers',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (organiser.bio != null && organiser.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _stripMarkdown(organiser.bio!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryPreview extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(galleryPreviewProvider);

    return galleryAsync.when(
      data: (images) {
        if (images.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return GestureDetector(
                onTap: () => context.push('/gallery'),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: image.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.primarySoft,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        child: const Icon(Icons.broken_image, size: 24, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 32, color: AppColors.error),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
