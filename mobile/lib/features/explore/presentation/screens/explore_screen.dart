import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/models/city.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/event_image.dart';
import '../../../../shared/models/organiser_profile.dart';
import '../../../../shared/widgets/app_components.dart';
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

IconData _getCategoryIcon(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('tech') || lower.contains('technology')) {
    return Icons.computer_rounded;
  }
  if (lower.contains('ai') || lower.contains('artificial')) {
    return Icons.psychology_rounded;
  }
  if (lower.contains('climate') || lower.contains('environment')) {
    return Icons.eco_rounded;
  }
  if (lower.contains('sport') || lower.contains('fitness')) {
    return Icons.fitness_center_rounded;
  }
  if (lower.contains('food') ||
      lower.contains('beverage') ||
      lower.contains('drink')) {
    return Icons.restaurant_rounded;
  }
  if (lower.contains('art') || lower.contains('culture')) {
    return Icons.palette_rounded;
  }
  if (lower.contains('health') || lower.contains('wellness')) {
    return Icons.favorite_rounded;
  }
  if (lower.contains('music')) return Icons.music_note_rounded;
  if (lower.contains('crypto') || lower.contains('blockchain')) {
    return Icons.currency_bitcoin_rounded;
  }
  if (lower.contains('business') || lower.contains('startup')) {
    return Icons.business_center_rounded;
  }
  if (lower.contains('education') || lower.contains('learning')) {
    return Icons.school_rounded;
  }
  if (lower.contains('web') || lower.contains('internet')) {
    return Icons.language_rounded;
  }
  return Icons.category_rounded;
}

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider);
    final cities = ref.watch(citiesProvider);
    final organisers = ref.watch(featuredOrganisersProvider);
    final hcmEvents = ref.watch(hcmEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.explore),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows_rounded),
            tooltip: 'Compare Events',
            onPressed: () => context.push('/compare-events'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(citiesProvider);
          ref.invalidate(featuredOrganisersProvider);
          ref.invalidate(hcmEventsProvider);
          ref.invalidate(galleryPreviewProvider);
        },
        child: ListView(
          padding: AppSpacing.screenPadding,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _ExploreHero(
              onSearch: () => context.push('/search'),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'City Spotlight',
              subtitle: 'High-intent events happening now in Ho Chi Minh City',
              onTap: () => context.push('/events?cityId=1'),
            ),
            const SizedBox(height: AppSpacing.md),
            _CitySpotlightCard(
              cityName: 'Ho Chi Minh City',
              imageUrl: _getCityImageUrl('Ho Chi Minh City'),
              onOpenCity: () => context.push('/events?cityId=1'),
            ),
            const SizedBox(height: AppSpacing.lg),
            hcmEvents.when(
              data: (events) {
                if (events.isEmpty) {
                  return const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No spotlight events',
                    subtitle:
                        'New city picks will appear here once organisers publish them.',
                  );
                }

                return Column(
                  children: events
                      .map(
                        (event) => EventListTile(
                          event: event,
                          compact: true,
                          onTap: () {
                            ref.read(selectedEventProvider.notifier).state =
                                event;
                            context.push('/event/${event.id}');
                          },
                          status: event.isFull
                              ? 'Sold out'
                              : event.isFree
                                  ? 'Free'
                                  : 'Book now',
                          statusVariant: event.isFull
                              ? StatusChipVariant.warning
                              : event.isFree
                                  ? StatusChipVariant.success
                                  : StatusChipVariant.primary,
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const LoadingState(
                message: 'Loading city spotlight...',
              ),
              error: (e, _) => _SectionError(
                message: ErrorUtils.extractMessage(e),
                onRetry: () => ref.invalidate(hcmEventsProvider),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: l10n.browseByCategory,
              subtitle: 'Jump into the right event type with one tap',
            ),
            const SizedBox(height: AppSpacing.md),
            categories.when(
              data: (data) => Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: data
                    .map(
                      (category) => _CategoryChip(
                        category: category,
                        onTap: () =>
                            context.push('/events?categoryId=${category.id}'),
                      ),
                    )
                    .toList(),
              ),
              loading: () => const LoadingState(
                message: 'Loading categories...',
              ),
              error: (e, _) => _SectionError(
                message: ErrorUtils.extractMessage(e),
                onRetry: () => ref.invalidate(categoriesProvider),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: l10n.cities,
              subtitle: 'Browse event inventory by destination',
              onTap: () => context.push('/cities'),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 184,
              child: cities.when(
                data: (data) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final city = data[index];
                    return _CityCard(
                      city: city,
                      onTap: () => context.push('/events?cityId=${city.id}'),
                    );
                  },
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => _HorizontalErrorCard(
                  message: ErrorUtils.extractMessage(e),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: 'Gallery',
              subtitle: 'Recent moments from live experiences on the platform',
              onTap: () => context.push('/gallery'),
            ),
            const SizedBox(height: AppSpacing.md),
            const _GalleryPreview(),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(
              title: l10n.featuredCalendars,
              subtitle: 'Trusted organisers with active event pipelines',
              onTap: () => context.push('/organisers'),
            ),
            const SizedBox(height: AppSpacing.md),
            organisers.when(
              data: (data) {
                if (data.isEmpty) {
                  return const EmptyState(
                    icon: Icons.groups_rounded,
                    title: 'No featured organisers yet',
                    subtitle:
                        'Featured organiser calendars will appear here soon.',
                  );
                }

                return AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: data
                        .take(6)
                        .map(
                          (organiser) => _FeaturedCalendarRow(
                            organiser: organiser,
                            onTap: () =>
                                context.push('/organiser/${organiser.id}'),
                          ),
                        )
                        .toList(),
                  ),
                );
              },
              loading: () => const LoadingState(
                message: 'Loading organiser calendars...',
              ),
              error: (e, _) => _SectionError(
                message: ErrorUtils.extractMessage(e),
                onRetry: () => ref.invalidate(featuredOrganisersProvider),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _ExploreHero extends StatelessWidget {
  const _ExploreHero({
    required this.onSearch,
  });

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.xxl,
      border: false,
      shadow: AppShadows.md,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F2C70),
              AppColors.primary,
              Color(0xFFFF7A45),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discover the next event worth booking.',
                style: AppTypography.h1.copyWith(
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Search cities, browse categories, compare options and move into ticket checkout with less friction.',
                style: AppTypography.bodyLg.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Material(
                color: Colors.white,
                borderRadius: AppRadius.allPill,
                child: InkWell(
                  borderRadius: AppRadius.allPill,
                  onTap: onSearch,
                  child: Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Search events, venues or organisers',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
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

class _CitySpotlightCard extends StatelessWidget {
  const _CitySpotlightCard({
    required this.cityName,
    required this.imageUrl,
    required this.onOpenCity,
  });

  final String cityName;
  final String? imageUrl;
  final VoidCallback onOpenCity;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Stack(
          children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primary,
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
            ),
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.xl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What’s happening in',
                    style: AppTypography.label.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    cityName,
                    style: AppTypography.h1.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Browse City Events',
                    icon: Icons.arrow_forward_rounded,
                    variant: AppButtonVariant.tonal,
                    onPressed: onOpenCity,
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
  const _CategoryChip({
    required this.category,
    required this.onTap,
  });

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadius.allPill,
      child: InkWell(
        borderRadius: AppRadius.allPill,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.allPill,
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(category.name),
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                category.name,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
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

    return AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.xl,
      onTap: onTap,
      child: SizedBox(
        width: 164,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
              child: SizedBox(
                height: 112,
                width: double.infinity,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.primarySoft,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.location_city_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Open city calendar',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
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
}

String _stripMarkdown(String text) {
  String firstMatch(Match m) => m.group(1) ?? '';
  return text
      .replaceAll(RegExp(r'#{1,6}\s*'), '')
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), firstMatch)
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), firstMatch)
      .replaceAllMapped(RegExp(r'__(.+?)__'), firstMatch)
      .replaceAllMapped(RegExp(r'_(.+?)_'), firstMatch)
      .replaceAllMapped(RegExp(r'~~(.+?)~~'), firstMatch)
      .replaceAllMapped(RegExp(r'\[(.+?)\]\(.+?\)'), firstMatch)
      .replaceAllMapped(RegExp(r'`(.+?)`'), firstMatch)
      .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}

String? _getCityImageUrl(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('ho chi minh') ||
      lower.contains('hcm') ||
      lower.contains('saigon')) {
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

class _FeaturedCalendarRow extends StatelessWidget {
  const _FeaturedCalendarRow({
    required this.organiser,
    required this.onTap,
  });

  final OrganiserProfile organiser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: organiser.profileImageUrl != null
                    ? CachedNetworkImageProvider(
                        organiser.profileImageUrl!,
                      )
                    : null,
                child: organiser.profileImageUrl == null
                    ? Text(
                        organiser.displayName[0].toUpperCase(),
                        style: AppTypography.h4.copyWith(
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            organiser.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.h4.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (organiser.verified) ...[
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${organiser.eventsCount} events • ${organiser.followersCount} followers',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (organiser.bio != null && organiser.bio!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _stripMarkdown(organiser.bio!),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryPreview extends ConsumerWidget {
  const _GalleryPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryAsync = ref.watch(galleryPreviewProvider);

    return galleryAsync.when(
      data: (images) {
        if (images.isEmpty) {
          return const EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No gallery items yet',
            subtitle: 'Event photo highlights will appear here once uploaded.',
          );
        }

        return SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final image = images[index];
              return GestureDetector(
                onTap: () => context.push('/gallery'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: SizedBox(
                    width: 128,
                    child: CachedNetworkImage(
                      imageUrl: image.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.primarySoft,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingState(
        message: 'Loading gallery preview...',
      ),
      error: (e, _) => _SectionError(
        message: ErrorUtils.extractMessage(e),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      message: message,
      onRetry: onRetry,
    );
  }
}

class _HorizontalErrorCard extends StatelessWidget {
  const _HorizontalErrorCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
