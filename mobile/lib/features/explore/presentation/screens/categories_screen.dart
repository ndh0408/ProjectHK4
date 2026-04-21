import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/category.dart';
import '../../../../shared/widgets/app_components.dart';
import 'explore_screen.dart';

IconData _getCategoryIcon(String name) {
  final lowerName = name.toLowerCase();
  if (lowerName.contains('music')) return Icons.music_note_rounded;
  if (lowerName.contains('tech')) return Icons.computer_rounded;
  if (lowerName.contains('food') || lowerName.contains('drink')) {
    return Icons.restaurant_rounded;
  }
  if (lowerName.contains('sport')) return Icons.sports_basketball_rounded;
  if (lowerName.contains('art') || lowerName.contains('culture')) {
    return Icons.palette_rounded;
  }
  if (lowerName.contains('business')) return Icons.business_center_rounded;
  if (lowerName.contains('health') || lowerName.contains('wellness')) {
    return Icons.favorite_rounded;
  }
  if (lowerName.contains('education')) return Icons.school_rounded;
  if (lowerName.contains('film') || lowerName.contains('movie')) {
    return Icons.movie_creation_outlined;
  }
  if (lowerName.contains('charity')) return Icons.volunteer_activism_rounded;
  return Icons.category_rounded;
}

Color _getCategoryColor(int index) {
  final colors = [
    const Color(0xFF3B82F6),
    const Color(0xFFF97316),
    const Color(0xFF10B981),
    const Color(0xFFEC4899),
    const Color(0xFF8B5CF6),
    const Color(0xFF14B8A6),
    const Color(0xFFEAB308),
    const Color(0xFFEF4444),
  ];
  return colors[index % colors.length];
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.categories),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              tooltip: l10n.refreshTooltip,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () => ref.invalidate(categoriesProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: categories.when(
        data: (data) {
          if (data.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              iconColor: AppColors.primary,
              title: l10n.noCategoriesAvailable,
              subtitle:
                  'New event themes will appear here as organisers publish more experiences.',
              actionLabel: l10n.refresh,
              onAction: () => ref.invalidate(categoriesProvider),
            );
          }

          final totalEvents = data.fold<int>(
            0,
            (sum, category) => sum + (category.eventsCount ?? 0),
          );

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(categoriesProvider),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageX,
                      AppSpacing.xl,
                      AppSpacing.pageX,
                      0,
                    ),
                    child: AppCard(
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
                              Icons.grid_view_rounded,
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
                                  '${data.length} categories, $totalEvents events',
                                  style: AppTypography.h3.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Category hubs help users scan by intent first, then narrow to individual events.',
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
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
                    child: SectionHeader(
                      title: 'Browse by interest',
                      subtitle:
                          'Each card surfaces the theme first, then the event volume to support quick decisions.',
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.lg),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageX,
                    0,
                    AppSpacing.pageX,
                    AppSpacing.massive,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: AppSpacing.lg,
                      crossAxisSpacing: AppSpacing.lg,
                      childAspectRatio: 0.84,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final category = data[index];
                        return _CategoryCard(
                          category: category,
                          color: _getCategoryColor(index),
                          onTap: () =>
                              context.push('/events?categoryId=${category.id}'),
                        );
                      },
                      childCount: data.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => LoadingState(message: l10n.loadingCategories),
        error: (_, __) => ErrorState(
          message: l10n.failedToLoadCategories,
          onRetry: () => ref.invalidate(categoriesProvider),
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
    final eventsCount = category.eventsCount ?? 0;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 104,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color,
                    color.withValues(alpha: 0.82),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.lg),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: AppRadius.allMd,
                    ),
                    alignment: Alignment.center,
                    child: category.iconUrl != null
                        ? ClipRRect(
                            borderRadius: AppRadius.allMd,
                            child: CachedNetworkImage(
                              imageUrl: category.iconUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Icon(
                                _getCategoryIcon(category.name),
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          )
                        : Icon(
                            _getCategoryIcon(category.name),
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: AppRadius.allPill,
                    ),
                    child: Text(
                      '$eventsCount events',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      category.description?.trim().isNotEmpty == true
                          ? category.description!
                          : 'Open a focused event feed with this theme pre-selected.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          'Open collection',
                          style: AppTypography.label.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
