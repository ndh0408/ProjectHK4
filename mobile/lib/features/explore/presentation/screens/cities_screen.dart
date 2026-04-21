import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/city.dart';
import '../../../../shared/widgets/app_components.dart';

final citiesByContinentProvider = FutureProvider<Map<String, List<City>>>(
  (ref) async {
    final api = ref.watch(apiServiceProvider);
    return api.getCitiesByContinent();
  },
);

const _regionOrder = [
  'Asia',
  'Europe',
  'North America',
  'South America',
  'Africa',
  'Oceania',
];

_CityStyle _getCityStyle(String cityName) {
  final lower = cityName.toLowerCase();

  if (lower.contains('bangkok')) {
    return const _CityStyle(
      Icons.temple_buddhist_rounded,
      Color(0xFFFF9800),
    );
  }
  if (lower.contains('tokyo') || lower.contains('osaka')) {
    return const _CityStyle(
      Icons.temple_buddhist_rounded,
      Color(0xFFE91E63),
    );
  }
  if (lower.contains('singapore')) {
    return const _CityStyle(Icons.location_city_rounded, Color(0xFF9C27B0));
  }
  if (lower.contains('hong kong')) {
    return const _CityStyle(Icons.apartment_rounded, Color(0xFF673AB7));
  }
  if (lower.contains('ho chi minh') ||
      lower.contains('hanoi') ||
      lower.contains('da nang')) {
    return const _CityStyle(
      Icons.temple_buddhist_rounded,
      Color(0xFFFF5722),
    );
  }
  if (lower.contains('seoul')) {
    return const _CityStyle(Icons.location_city_rounded, Color(0xFF3F51B5));
  }
  if (lower.contains('mumbai') ||
      lower.contains('delhi') ||
      lower.contains('bengaluru')) {
    return const _CityStyle(
      Icons.account_balance_rounded,
      Color(0xFF009688),
    );
  }
  if (lower.contains('dubai')) {
    return const _CityStyle(Icons.business_rounded, Color(0xFFFACC15));
  }
  if (lower.contains('jakarta')) {
    return const _CityStyle(Icons.location_city_rounded, Color(0xFF795548));
  }
  if (lower.contains('kuala lumpur')) {
    return const _CityStyle(Icons.business_rounded, Color(0xFF607D8B));
  }
  if (lower.contains('manila')) {
    return const _CityStyle(Icons.location_city_rounded, Color(0xFF8BC34A));
  }
  if (lower.contains('sydney') ||
      lower.contains('melbourne') ||
      lower.contains('brisbane')) {
    return const _CityStyle(Icons.beach_access_rounded, Color(0xFF00BCD4));
  }
  if (lower.contains('honolulu')) {
    return const _CityStyle(Icons.beach_access_rounded, Color(0xFF4CAF50));
  }
  if (lower.contains('london')) {
    return const _CityStyle(
      Icons.account_balance_rounded,
      Color(0xFF2196F3),
    );
  }
  if (lower.contains('paris')) {
    return const _CityStyle(Icons.castle_rounded, Color(0xFFE91E63));
  }
  if (lower.contains('berlin') || lower.contains('munich')) {
    return const _CityStyle(
      Icons.account_balance_rounded,
      Color(0xFF9E9E9E),
    );
  }
  if (lower.contains('amsterdam')) {
    return const _CityStyle(
      Icons.directions_bike_rounded,
      Color(0xFFFF9800),
    );
  }
  if (lower.contains('barcelona') || lower.contains('madrid')) {
    return const _CityStyle(Icons.stadium_rounded, Color(0xFFF44336));
  }
  if (lower.contains('rome') || lower.contains('milan')) {
    return const _CityStyle(
      Icons.account_balance_rounded,
      Color(0xFF4CAF50),
    );
  }
  if (lower.contains('new york')) {
    return const _CityStyle(Icons.location_city_rounded, Color(0xFF2196F3));
  }
  if (lower.contains('los angeles') || lower.contains('san francisco')) {
    return const _CityStyle(Icons.wb_sunny_rounded, Color(0xFFFF9800));
  }
  if (lower.contains('chicago')) {
    return const _CityStyle(Icons.location_city_rounded, Color(0xFF607D8B));
  }
  if (lower.contains('toronto') || lower.contains('vancouver')) {
    return const _CityStyle(Icons.park_rounded, Color(0xFFF44336));
  }
  if (lower.contains('sao paulo') || lower.contains('rio')) {
    return const _CityStyle(Icons.beach_access_rounded, Color(0xFF4CAF50));
  }
  if (lower.contains('mexico')) {
    return const _CityStyle(
      Icons.account_balance_rounded,
      Color(0xFF009688),
    );
  }

  return const _CityStyle(Icons.location_city_rounded, AppColors.primary);
}

class _CityStyle {
  const _CityStyle(this.icon, this.color);

  final IconData icon;
  final Color color;
}

class CitiesScreen extends ConsumerWidget {
  const CitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final citiesByContinent = ref.watch(citiesByContinentProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.cities),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              tooltip: l10n.refreshTooltip,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () => ref.invalidate(citiesByContinentProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: citiesByContinent.when(
        data: (data) {
          if (data.isEmpty) {
            return EmptyState(
              icon: Icons.location_city_outlined,
              iconColor: AppColors.info,
              title: 'No cities with events',
              subtitle:
                  'City hubs will appear here once organisers publish local events.',
              actionLabel: l10n.refresh,
              onAction: () => ref.invalidate(citiesByContinentProvider),
            );
          }

          final sortedRegions = data.keys.toList()
            ..sort((a, b) {
              final indexA = _regionOrder.indexOf(a);
              final indexB = _regionOrder.indexOf(b);
              if (indexA == -1 && indexB == -1) return a.compareTo(b);
              if (indexA == -1) return 1;
              if (indexB == -1) return -1;
              return indexA.compareTo(indexB);
            });

          final totalCities = data.values.fold<int>(
            0,
            (sum, cities) => sum + cities.length,
          );
          final totalEvents = data.values.fold<int>(
            0,
            (sum, cities) =>
                sum +
                cities.fold<int>(
                    0, (citySum, city) => citySum + city.eventCount),
          );

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(citiesByContinentProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageX,
                AppSpacing.xl,
                AppSpacing.pageX,
                AppSpacing.massive,
              ),
              children: [
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.section),
                  borderColor: AppColors.borderLight,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: AppRadius.allLg,
                        ),
                        child: const Icon(
                          Icons.travel_explore_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$totalCities cities across ${sortedRegions.length} regions',
                              style: AppTypography.h3.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '$totalEvents live event listings are grouped geographically for faster discovery.',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SectionHeader(
                  title: 'Explore by region',
                  subtitle:
                      'Users can jump from a world view to a city-specific event feed without extra filter setup.',
                ),
                const SizedBox(height: AppSpacing.lg),
                ...sortedRegions.map((region) {
                  final cities = [...data[region]!]
                    ..sort((a, b) => b.eventCount.compareTo(a.eventCount));

                  return _RegionSection(
                    region: region,
                    cities: cities,
                    onCityTap: (city) =>
                        context.push('/events?cityId=${city.id}'),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => LoadingState(message: l10n.loadingCities),
        error: (error, _) => ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(citiesByContinentProvider),
        ),
      ),
    );
  }
}

class _RegionSection extends StatelessWidget {
  const _RegionSection({
    required this.region,
    required this.cities,
    required this.onCityTap,
  });

  final String region;
  final List<City> cities;
  final void Function(City) onCityTap;

  @override
  Widget build(BuildContext context) {
    final totalEvents =
        cities.fold<int>(0, (sum, city) => sum + city.eventCount);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: region,
            subtitle: '${cities.length} cities • $totalEvents events',
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < cities.length; index++)
                  _CityListItem(
                    city: cities[index],
                    showDivider: index != cities.length - 1,
                    onTap: () => onCityTap(cities[index]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CityListItem extends StatelessWidget {
  const _CityListItem({
    required this.city,
    required this.onTap,
    required this.showDivider,
  });

  final City city;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final style = _getCityStyle(city.name);
    final subtitle = [
      if (city.country?.isNotEmpty == true) city.country!,
      if (city.continent?.isNotEmpty == true) city.continent!,
    ].join(' • ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.12),
                      borderRadius: AppRadius.allMd,
                    ),
                    child: Icon(style.icon, color: style.color, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city.name,
                          style: AppTypography.h4.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            subtitle,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusChip(
                        label:
                            '${city.eventCount} ${city.eventCount == 1 ? 'event' : 'events'}',
                        variant: StatusChipVariant.primary,
                        compact: true,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textLight,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showDivider)
              const Divider(
                height: 1,
                indent: AppSpacing.lg + 48 + AppSpacing.md,
                endIndent: AppSpacing.lg,
              ),
          ],
        ),
      ),
    );
  }
}
