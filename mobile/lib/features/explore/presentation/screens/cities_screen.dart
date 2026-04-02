import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/city.dart';

final citiesByContinentProvider = FutureProvider<Map<String, List<City>>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getCitiesByContinent();
});

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
    return _CityStyle(Icons.temple_buddhist, const Color(0xFFFF9800));
  }
  if (lower.contains('tokyo') || lower.contains('osaka')) {
    return _CityStyle(Icons.temple_buddhist, const Color(0xFFE91E63));
  }
  if (lower.contains('singapore')) {
    return _CityStyle(Icons.location_city, const Color(0xFF9C27B0));
  }
  if (lower.contains('hong kong')) {
    return _CityStyle(Icons.apartment, const Color(0xFF673AB7));
  }
  if (lower.contains('ho chi minh') || lower.contains('hanoi') || lower.contains('da nang')) {
    return _CityStyle(Icons.temple_buddhist, const Color(0xFFFF5722));
  }
  if (lower.contains('seoul')) {
    return _CityStyle(Icons.location_city, const Color(0xFF3F51B5));
  }
  if (lower.contains('mumbai') || lower.contains('delhi') || lower.contains('bengaluru')) {
    return _CityStyle(Icons.account_balance, const Color(0xFF009688));
  }
  if (lower.contains('dubai')) {
    return _CityStyle(Icons.business, const Color(0xFFFFEB3B));
  }
  if (lower.contains('jakarta')) {
    return _CityStyle(Icons.location_city, const Color(0xFF795548));
  }
  if (lower.contains('kuala lumpur')) {
    return _CityStyle(Icons.business, const Color(0xFF607D8B));
  }
  if (lower.contains('manila')) {
    return _CityStyle(Icons.location_city, const Color(0xFF8BC34A));
  }

  if (lower.contains('sydney') || lower.contains('melbourne') || lower.contains('brisbane')) {
    return _CityStyle(Icons.beach_access, const Color(0xFF00BCD4));
  }
  if (lower.contains('honolulu')) {
    return _CityStyle(Icons.beach_access, const Color(0xFF4CAF50));
  }

  if (lower.contains('london')) {
    return _CityStyle(Icons.account_balance, const Color(0xFF2196F3));
  }
  if (lower.contains('paris')) {
    return _CityStyle(Icons.castle, const Color(0xFFE91E63));
  }
  if (lower.contains('berlin') || lower.contains('munich')) {
    return _CityStyle(Icons.account_balance, const Color(0xFF9E9E9E));
  }
  if (lower.contains('amsterdam')) {
    return _CityStyle(Icons.directions_bike, const Color(0xFFFF9800));
  }
  if (lower.contains('barcelona') || lower.contains('madrid')) {
    return _CityStyle(Icons.stadium, const Color(0xFFF44336));
  }
  if (lower.contains('rome') || lower.contains('milan')) {
    return _CityStyle(Icons.account_balance, const Color(0xFF4CAF50));
  }

  if (lower.contains('new york')) {
    return _CityStyle(Icons.location_city, const Color(0xFF2196F3));
  }
  if (lower.contains('los angeles') || lower.contains('san francisco')) {
    return _CityStyle(Icons.wb_sunny, const Color(0xFFFF9800));
  }
  if (lower.contains('chicago')) {
    return _CityStyle(Icons.location_city, const Color(0xFF607D8B));
  }
  if (lower.contains('toronto') || lower.contains('vancouver')) {
    return _CityStyle(Icons.park, const Color(0xFFF44336));
  }
  if (lower.contains('sao paulo') || lower.contains('rio')) {
    return _CityStyle(Icons.beach_access, const Color(0xFF4CAF50));
  }
  if (lower.contains('mexico')) {
    return _CityStyle(Icons.account_balance, const Color(0xFF009688));
  }

  return _CityStyle(Icons.location_city, AppColors.primary);
}

class _CityStyle {
  final IconData icon;
  final Color color;

  const _CityStyle(this.icon, this.color);
}

class CitiesScreen extends ConsumerWidget {
  const CitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesByContinent = ref.watch(citiesByContinentProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Cities',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: citiesByContinent.when(
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 64,
                    color: AppColors.divider,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No cities with events',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
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

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(citiesByContinentProvider);
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Text(
                    'Discover popular events in cities around the world and subscribe to receive weekly updates.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),

                ...sortedRegions.map((region) {
                  final cities = data[region]!;
                  cities.sort((a, b) => b.eventCount.compareTo(a.eventCount));

                  return _RegionSection(
                    region: region,
                    cities: cities,
                    onCityTap: (city) => context.push('/events?cityId=${city.id}'),
                  );
                }),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load cities',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(citiesByContinentProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            region,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
        ),

        ...cities.map((city) => _CityListItem(
          city: city,
          onTap: () => onCityTap(city),
        )),
      ],
    );
  }
}

class _CityListItem extends StatelessWidget {
  const _CityListItem({
    required this.city,
    required this.onTap,
  });

  final City city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _getCityStyle(city.name);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.divider,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: style.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                style.icon,
                color: style.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Text(
                city.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            Text(
              '${city.eventCount} ${city.eventCount == 1 ? 'Event' : 'Events'}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(width: 8),

            Icon(
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
