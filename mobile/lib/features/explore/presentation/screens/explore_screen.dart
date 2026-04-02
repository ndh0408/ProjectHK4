import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/models/city.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/organiser_profile.dart';
import '../../../home/providers/events_provider.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCategories();
});

final citiesProvider = FutureProvider<List<City>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCities();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(l10n.explore),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: RefreshIndicator(
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
              const SizedBox(height: 8),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: GestureDetector(
                  onTap: () => context.push('/search'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: hPadding, vertical: Responsive.spacing(context, base: 12)),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search,
                            color: theme.textTheme.bodySmall?.color, size: Responsive.iconSize(context, base: 22)),
                        SizedBox(width: Responsive.spacing(context, base: 12)),
                        Text(
                          l10n.searchEvents,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

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
                            EdgeInsets.symmetric(horizontal: hPadding, vertical: Responsive.spacing(context, base: 12)),
                        child: Text(
                          l10n.noUpcomingEventsShort,
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: hPadding),
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
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: Text(
                  l10n.browseByCategory,
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: screenWidth * 0.112,
                child: categories.when(
                  data: (data) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: hPadding),
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
                height: screenWidth * 0.37,
                child: cities.when(
                  data: (data) => ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: hPadding),
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

              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPadding),
                child: Text(
                  l10n.featuredCalendars,
                  style: theme.textTheme.titleLarge?.copyWith(
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hPadding = Responsive.horizontalPadding(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium,
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      color: colorScheme.primary,
                      size: Responsive.iconSize(context, base: 20),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth * 0.23;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: Responsive.spacing(context, base: 10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: imageSize,
                    height: imageSize,
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
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        l10n.soldOut,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onError,
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
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (event.isFull)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.bookmark,
                                  size: 12, color: Color(0xFFE65100)),
                              const SizedBox(width: 2),
                              Text(
                                l10n.soldOut,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFE65100),
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(Icons.schedule,
                          size: Responsive.iconSize(context, base: 14), color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dateFormat.format(event.startDate),
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: event.isFree ? Colors.green[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          event.isFree ? l10n.free.toUpperCase() : '\$${event.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: event.isFree ? Colors.green[700] : Colors.orange[700],
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(right: Responsive.spacing(context, base: 10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.spacing(context, base: 16),
            vertical: Responsive.spacing(context, base: 8),
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(category.name),
                size: Responsive.iconSize(context, base: 18),
                color: colorScheme.primary,
              ),
              SizedBox(width: Responsive.spacing(context)),
              Text(
                category.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.textTheme.bodyLarge?.color,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: screenWidth * 0.4,
        margin: EdgeInsets.only(right: Responsive.spacing(context, base: 12)),
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
                      child: const Icon(
                        Icons.location_city,
                        color: Colors.white54,
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
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),

              Positioned(
                left: Responsive.spacing(context, base: 12),
                bottom: Responsive.spacing(context, base: 12),
                right: Responsive.spacing(context, base: 12),
                child: Text(
                  city.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 4,
                        color: AppColors.textSecondary,
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
  return text
      .replaceAll(RegExp(r'#{1,6}\s*'), '')
      .replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1')
      .replaceAll(RegExp(r'\*(.+?)\*'), r'$1')
      .replaceAll(RegExp(r'__(.+?)__'), r'$1')
      .replaceAll(RegExp(r'_(.+?)_'), r'$1')
      .replaceAll(RegExp(r'~~(.+?)~~'), r'$1')
      .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)'), r'$1')
      .replaceAll(RegExp(r'`(.+?)`'), r'$1')
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hPadding = Responsive.horizontalPadding(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final avatarSize = screenWidth * 0.117;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: Responsive.spacing(context, base: 10)),
        child: Row(
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
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
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
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
                    style: theme.textTheme.bodySmall,
                  ),
                  if (organiser.bio != null && organiser.bio!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _stripMarkdown(organiser.bio!),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),

            Icon(
              Icons.chevron_right,
              color: theme.textTheme.bodySmall?.color,
              size: Responsive.iconSize(context, base: 20),
            ),
          ],
        ),
      ),
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
