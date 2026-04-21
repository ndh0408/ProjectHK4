import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/organiser_profile.dart';
import '../../../../shared/widgets/app_components.dart';
import 'explore_screen.dart';

class OrganisersScreen extends ConsumerWidget {
  const OrganisersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final organisers = ref.watch(featuredOrganisersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.organisers),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              tooltip: l10n.refreshTooltip,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () => ref.invalidate(featuredOrganisersProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: organisers.when(
        data: (data) {
          if (data.isEmpty) {
            return EmptyState(
              icon: Icons.groups_outlined,
              title: l10n.noOrganisersAvailable,
              subtitle:
                  'Featured organisers will appear here as their event pages gain traction.',
              actionLabel: l10n.refresh,
              onAction: () => ref.invalidate(featuredOrganisersProvider),
            );
          }

          final verifiedCount =
              data.where((organiser) => organiser.verified).length;
          final totalFollowers = data.fold<int>(
            0,
            (sum, organiser) => sum + organiser.followersCount,
          );

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(featuredOrganisersProvider),
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
                              Icons.groups_rounded,
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
                                  '${data.length} organisers • $verifiedCount verified',
                                  style: AppTypography.h3.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '${_formatNumber(totalFollowers)} combined followers create stronger trust and conversion cues.',
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
                      title: 'Featured organisers',
                      subtitle:
                          'Profiles surface reputation first so users can judge credibility before tapping into the full detail view.',
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
                      crossAxisSpacing: AppSpacing.lg,
                      mainAxisSpacing: AppSpacing.lg,
                      childAspectRatio: 0.73,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final organiser = data[index];
                        return _OrganiserCard(
                          organiser: organiser,
                          onTap: () =>
                              context.push('/organiser/${organiser.id}'),
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
        loading: () => const LoadingState(message: 'Loading organisers...'),
        error: (error, _) => ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(featuredOrganisersProvider),
        ),
      ),
    );
  }

  static String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _OrganiserCard extends StatelessWidget {
  const _OrganiserCard({
    required this.organiser,
    required this.onTap,
  });

  final OrganiserProfile organiser;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: SizedBox.expand(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: StatusChip(
                label: organiser.verified ? 'Verified' : 'Active',
                variant: organiser.verified
                    ? StatusChipVariant.success
                    : StatusChipVariant.primary,
                compact: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      gradient: organiser.verified
                          ? const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.secondary,
                              ],
                            )
                          : LinearGradient(
                              colors: [
                                AppColors.primary.withValues(alpha: 0.18),
                                AppColors.info.withValues(alpha: 0.18),
                              ],
                            ),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.surfaceVariant,
                      backgroundImage: organiser.avatarUrl != null
                          ? CachedNetworkImageProvider(organiser.avatarUrl!)
                          : null,
                      child: organiser.avatarUrl == null
                          ? Text(
                              organiser.displayName
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: AppTypography.h2.copyWith(
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (organiser.verified)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              organiser.displayName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.h4.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              organiser.verified
                  ? 'High-trust organiser with a verified identity and an active event footprint.'
                  : 'Active organiser with a growing event portfolio and audience.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Followers',
                    value: OrganisersScreen._formatNumber(
                      organiser.followersCount,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MiniStat(
                    label: 'Events',
                    value: organiser.eventsCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Text(
                  'View profile',
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
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.allMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTypography.h4.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
