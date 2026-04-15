import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/category.dart';
import 'explore_screen.dart';

IconData _getCategoryIcon(String name) {
  final lowerName = name.toLowerCase();
  if (lowerName.contains('music')) return Icons.music_note;
  if (lowerName.contains('tech')) return Icons.computer;
  if (lowerName.contains('food') || lowerName.contains('drink')) return Icons.restaurant;
  if (lowerName.contains('sport')) return Icons.sports;
  if (lowerName.contains('art') || lowerName.contains('culture')) return Icons.palette;
  if (lowerName.contains('business')) return Icons.business;
  if (lowerName.contains('health') || lowerName.contains('wellness')) return Icons.favorite;
  if (lowerName.contains('education')) return Icons.school;
  if (lowerName.contains('film') || lowerName.contains('movie')) return Icons.movie;
  if (lowerName.contains('charity')) return Icons.volunteer_activism;
  return Icons.category;
}

Color _getCategoryColor(int index) {
  final colors = [
    const Color(0xFF667EEA),
    const Color(0xFFED64A6),
    const Color(0xFF38A169),
    const Color(0xFFED8936),
    const Color(0xFF9F7AEA),
    const Color(0xFF4299E1),
    const Color(0xFFE53E3E),
    const Color(0xFF38B2AC),
  ];
  return colors[index % colors.length];
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.categories),
      ),
      body: categories.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.category_outlined,
                    size: 64,
                    color: AppColors.textLight,
                  ),
                  SizedBox(height: 16),
                  Text('No categories available'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(categoriesProvider);
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final category = data[index];
                return _CategoryCard(
                  category: category,
                  color: _getCategoryColor(index),
                  onTap: () => context.push('/events?categoryId=${category.id}'),
                );
              },
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
              Text('Error: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(categoriesProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.color,
    required this.onTap,
  });

  final Category category;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.textOnPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: category.iconUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: category.iconUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(
                              _getCategoryIcon(category.name),
                              size: 28,
                              color: AppColors.textOnPrimary,
                            ),
                          ),
                        )
                      : Icon(
                          _getCategoryIcon(category.name),
                          size: 28,
                          color: AppColors.textOnPrimary,
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textOnPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${category.eventsCount} events',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
