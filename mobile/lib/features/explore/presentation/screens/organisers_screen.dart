import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/organiser_profile.dart';
import '../../../../shared/widgets/app_components.dart';

final organisersDirectoryProvider =
    FutureProvider<List<OrganiserProfile>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getOrganisers();
});

class OrganisersScreen extends ConsumerWidget {
  const OrganisersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final organisers = ref.watch(organisersDirectoryProvider);

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
              onPressed: () => ref.invalidate(organisersDirectoryProvider),
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
                  'Public organiser profiles will appear here once organisers publish their calendars.',
              actionLabel: l10n.refresh,
              onAction: () => ref.invalidate(organisersDirectoryProvider),
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
            onRefresh: () async => ref.invalidate(organisersDirectoryProvider),
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
                                  '${_formatNumber(totalFollowers)} followers across organiser calendars.',
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
                      title: 'All organisers',
                      subtitle:
                          'Public organiser profiles and active event calendars.',
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
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final organiser = data[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index == data.length - 1
                                ? 0
                                : AppSpacing.lg,
                          ),
                          child: _OrganiserCard(
                            organiser: organiser,
                            onTap: () =>
                                context.push('/organiser/${organiser.id}'),
                          ),
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
          onRetry: () => ref.invalidate(organisersDirectoryProvider),
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
    final imageUrl = organiser.profileImageUrl;
    final summary = _buildSummary(organiser);
    final statusLabel = organiser.verified ? 'Verified' : 'Active';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      borderColor: AppColors.borderLight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OrganiserArtwork(
            name: organiser.displayName,
            imageUrl: imageUrl,
            verified: organiser.verified,
            logoMode: organiser.logoUrl?.trim().isNotEmpty == true,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        organiser.displayName,
                        maxLines: 2,
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
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$statusLabel • ${organiser.eventsCount} events • ${OrganisersScreen._formatNumber(organiser.followersCount)} followers',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open profile',
                      style: AppTypography.label.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
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
        ],
      ),
    );
  }
}

class _OrganiserArtwork extends StatelessWidget {
  const _OrganiserArtwork({
    required this.name,
    required this.imageUrl,
    required this.verified,
    required this.logoMode,
  });

  final String name;
  final String? imageUrl;
  final bool verified;
  final bool logoMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      padding: EdgeInsets.all(logoMode ? AppSpacing.sm : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.allLg,
        border: Border.all(color: AppColors.borderLight),
        boxShadow: verified ? AppShadows.xs : null,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.allMd,
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: logoMode ? BoxFit.contain : BoxFit.cover,
                errorWidget: (_, __, ___) => _OrganiserFallback(name: name),
              )
            : _OrganiserFallback(name: name),
      ),
    );
  }
}

class _OrganiserFallback extends StatelessWidget {
  const _OrganiserFallback({
    required this.name,
  });

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.primarySoft,
            AppColors.secondarySoft,
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.substring(0, 1).toUpperCase(),
        style: AppTypography.h2.copyWith(
          color: AppColors.primary,
        ),
      ),
    );
  }
}

String _buildSummary(OrganiserProfile organiser) {
  final bio = organiser.bio;
  if (bio != null && bio.trim().isNotEmpty) {
    return _stripMarkdown(bio);
  }

  return organiser.verified
      ? 'Verified organiser with active public events.'
      : 'Active organiser with a public event calendar.';
}

String _stripMarkdown(String text) {
  String firstMatch(Match match) => match.group(1) ?? '';

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
