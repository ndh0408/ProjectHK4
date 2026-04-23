import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/organiser_profile.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/providers/events_provider.dart';

final organiserProfileProvider = FutureProvider.autoDispose
    .family<OrganiserProfile, String>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  return api.getOrganiserProfile(id);
});

final organiserEventsProvider = FutureProvider.autoDispose
    .family<List<Event>, String>((ref, organiserId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getOrganiserEvents(organiserId);
  return response.content;
});

class FollowState {
  const FollowState(
      {this.isFollowing = false,
      this.isLoading = false,
      this.isInitialized = false});
  final bool isFollowing;
  final bool isLoading;
  final bool isInitialized;
}

class FollowNotifier extends StateNotifier<FollowState> {
  FollowNotifier(this._api, this._organiserId) : super(const FollowState()) {
    _checkFollowStatus();
  }
  final ApiService _api;
  final String _organiserId;

  Future<void> _checkFollowStatus() async {
    try {
      final isFollowing = await _api.isFollowingOrganiser(_organiserId);
      state = FollowState(isFollowing: isFollowing, isInitialized: true);
    } catch (_) {
      state = const FollowState(isInitialized: true);
    }
  }

  Future<void> toggleFollow() async {
    if (state.isLoading) return;

    state = FollowState(
        isFollowing: state.isFollowing, isLoading: true, isInitialized: true);

    try {
      if (state.isFollowing) {
        await _api.unfollowOrganiser(_organiserId);
      } else {
        await _api.followOrganiser(_organiserId);
      }
      state = FollowState(isFollowing: !state.isFollowing, isInitialized: true);
    } catch (e) {
      state = FollowState(isFollowing: state.isFollowing, isInitialized: true);
      rethrow;
    }
  }
}

final followProvider = StateNotifierProvider.autoDispose
    .family<FollowNotifier, FollowState, String>((ref, organiserId) {
  final api = ref.watch(apiServiceProvider);
  return FollowNotifier(api, organiserId);
});

class OrganiserProfileScreen extends ConsumerWidget {
  const OrganiserProfileScreen({super.key, required this.organiserId});

  final String organiserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(organiserProfileProvider(organiserId));
    final events = ref.watch(organiserEventsProvider(organiserId));
    final followState = ref.watch(followProvider(organiserId));
    final currentUser = ref.watch(currentUserProvider);

    final isOwnProfile = currentUser?.id == organiserId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: profile.when(
        data: (organiser) => NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 220,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: AppRadius.allPill,
                  ),
                  child: const Icon(Icons.arrow_back,
                      color: AppColors.textOnPrimary, size: 20),
                ),
                onPressed: () => context.pop(),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: AppRadius.allPill,
                    ),
                    child: const Icon(Icons.share_outlined,
                        color: AppColors.textOnPrimary, size: 20),
                  ),
                  onPressed: () => _shareOrganiser(organiser),
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: AppRadius.allPill,
                    ),
                    child: const Icon(Icons.more_vert,
                        color: AppColors.textOnPrimary, size: 20),
                  ),
                  onPressed: () => _showMoreOptions(context, organiser),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (organiser.headerImageUrl != null)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: organiser.headerImageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _buildGradientBackground(),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.6),
                                  AppColors.secondary.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      _buildGradientBackground(),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.textPrimary.withValues(alpha: 0.3),
                            Colors.transparent,
                            AppColors.textPrimary.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          body: ListView(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final profileImageUrl = organiser.profileImageUrl;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor: AppColors.primarySoft,
                              backgroundImage: profileImageUrl != null
                                  ? CachedNetworkImageProvider(profileImageUrl)
                                  : null,
                              child: profileImageUrl == null
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
                                          style: AppTypography.h2.copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      StatusChip(
                                        label: organiser.verified
                                            ? 'Verified'
                                            : 'Public organiser',
                                        variant: organiser.verified
                                            ? StatusChipVariant.success
                                            : StatusChipVariant.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    organiser.website?.isNotEmpty == true
                                        ? organiser.website!
                                        : organiser.contactEmail?.isNotEmpty ==
                                                true
                                            ? organiser.contactEmail!
                                            : organiser.contactPhone
                                                        ?.isNotEmpty ==
                                                    true
                                                ? organiser.contactPhone!
                                            : 'Independent organiser profile',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (!isOwnProfile)
                      SizedBox(
                        width: 160,
                        child: _buildSubscribeButton(ref, context, followState),
                      ),
                    if (!isOwnProfile) const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _StatItem(
                          icon: Icons.people_outline_rounded,
                          value: _formatCount(organiser.followersCount),
                          label: 'Followers',
                        ),
                        _StatItem(
                          icon: Icons.event_outlined,
                          value: _formatCount(organiser.eventsCount),
                          label: 'Events',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: [
                        _ActionButton(
                          icon: Icons.calendar_today_outlined,
                          label: 'Calendar',
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Calendar sync coming soon!'),
                              ),
                            );
                          },
                        ),
                        if (organiser.website != null &&
                            organiser.website!.isNotEmpty)
                          _ActionButton(
                            icon: Icons.language_rounded,
                            label: 'Website',
                            onTap: () =>
                                _openWebsite(context, organiser.website),
                          ),
                        if (organiser.contactEmail != null &&
                            organiser.contactEmail!.isNotEmpty)
                          _ActionButton(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            onTap: () => _openEmail(organiser.contactEmail!),
                          ),
                        if (organiser.contactPhone != null &&
                            organiser.contactPhone!.isNotEmpty)
                          _ActionButton(
                            icon: Icons.call_outlined,
                            label: 'Phone',
                            onTap: () => _openPhone(organiser.contactPhone!),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_buildAboutCopy(organiser) != null)
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.section),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About',
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (organiser.bio?.trim().isNotEmpty ?? false)
                        MarkdownBody(
                          data: organiser.bio!,
                          shrinkWrap: true,
                          softLineBreak: true,
                          styleSheet: MarkdownStyleSheet(
                            p: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            strong: AppTypography.body.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            em: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            a: AppTypography.body.copyWith(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                            listBullet: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            h1: AppTypography.h2.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            h2: AppTypography.h3.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            h3: AppTypography.h4.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onTapLink: (text, href, title) {
                            if (href != null) {
                              launchUrl(Uri.parse(href));
                            }
                          },
                        )
                      else
                        Text(
                          _buildAboutCopy(organiser)!,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              events.when(
                data: (eventList) =>
                    _buildEventsSection(context, ref, eventList),
                loading: () => const LoadingState(
                  message: 'Loading organiser events...',
                ),
                error: (error, _) => ErrorState(
                  message: '$error',
                  onRetry: () =>
                      ref.invalidate(organiserEventsProvider(organiserId)),
                ),
              ),
            ],
          ),
        ),
        loading: () =>
            const LoadingState(message: 'Loading organiser profile...'),
        error: (error, _) => ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(organiserProfileProvider(organiserId)),
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(
      WidgetRef ref, BuildContext context, FollowState followState) {
    if (!followState.isInitialized || followState.isLoading) {
      return const AppButton(
        label: 'Follow',
        expanded: true,
        loading: true,
      );
    }

    return AppButton(
      label: followState.isFollowing ? 'Following' : 'Subscribe',
      variant: followState.isFollowing
          ? AppButtonVariant.secondary
          : AppButtonVariant.primary,
      icon: followState.isFollowing ? Icons.check_rounded : Icons.add_rounded,
      expanded: true,
      onPressed: () => _toggleFollow(ref, context),
    );
  }

  Widget _buildEventsSection(
      BuildContext context, WidgetRef ref, List<Event> events) {
    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_outlined,
        compact: true,
        title: 'No upcoming events',
        subtitle:
            'This organiser does not have any published upcoming events yet.',
      );
    }

    events.sort((a, b) => a.startDate.compareTo(b.startDate));
    final groupedEvents = _groupEventsByDate(events);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Upcoming events',
          subtitle:
              'Published events are grouped by date so users can scan the organiser pipeline quickly.',
        ),
        const SizedBox(height: AppSpacing.lg),
        ...groupedEvents.entries.map((entry) {
          final parts = entry.key.split(' | ');
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: parts.first,
                  subtitle: parts.length > 1 ? parts[1] : '',
                ),
                const SizedBox(height: AppSpacing.md),
                ...entry.value.map(
                  (event) => EventListTile(
                    event: event,
                    compact: true,
                    status: event.isFull
                        ? 'Sold out'
                        : event.isAlmostFull
                            ? 'Almost full'
                            : 'Open',
                    statusVariant: event.isFull
                        ? StatusChipVariant.warning
                        : event.isAlmostFull
                            ? StatusChipVariant.info
                            : StatusChipVariant.success,
                    onTap: () {
                      ref.read(selectedEventProvider.notifier).state = event;
                      context.push('/event/${event.id}');
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Map<String, List<Event>> _groupEventsByDate(List<Event> events) {
    final Map<String, List<Event>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    for (final event in events) {
      final eventDate = DateTime(
        event.startDate.year,
        event.startDate.month,
        event.startDate.day,
      );

      String dateKey;
      if (eventDate == today) {
        dateKey = 'Today | ${DateFormat('EEEE').format(eventDate)}';
      } else if (eventDate == tomorrow) {
        dateKey = 'Tomorrow | ${DateFormat('EEEE').format(eventDate)}';
      } else {
        dateKey =
            '${DateFormat('MMMM d').format(eventDate)} | ${DateFormat('EEEE').format(eventDate)}';
      }

      grouped.putIfAbsent(dateKey, () => []).add(event);
    }

    return grouped;
  }

  void _showMoreOptions(BuildContext context, OrganiserProfile organiser) {
    AppBottomSheet.show(
      context: context,
      title: 'More actions',
      subtitle: 'Share or report this organiser profile.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              _shareOrganiser(organiser);
            },
          ),
          ListTile(
            leading: const Icon(Icons.report_outlined),
            title: const Text('Report'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report submitted')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _shareOrganiser(OrganiserProfile organiser) {
    Share.share(
      'Check out ${organiser.displayName} on LUMA!\nhttps://luma.app/organiser/$organiserId',
    );
  }

  void _openWebsite(BuildContext context, String? website) async {
    if (website == null || website.isEmpty) return;
    String urlString = website;
    if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
      urlString = 'https://$urlString';
    }
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _openEmail(String email) async {
    final url = Uri.parse('mailto:$email');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.secondary,
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String? _buildAboutCopy(OrganiserProfile organiser) {
    if (organiser.bio?.trim().isNotEmpty ?? false) {
      return organiser.bio!.trim();
    }

    if (organiser.eventsCount <= 0) {
      return organiser.verified
          ? 'Verified organiser profile on LUMA.'
          : 'Public organiser profile on LUMA.';
    }

    return organiser.verified
        ? '${organiser.displayName} is a verified organiser with ${_formatCount(organiser.eventsCount)} published events on LUMA.'
        : '${organiser.displayName} is running ${_formatCount(organiser.eventsCount)} published events on LUMA.';
  }

  Future<void> _toggleFollow(WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(followProvider(organiserId).notifier).toggleFollow();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.allMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.h4.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(width: AppSpacing.xs),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.allMd,
            border:
                Border.fromBorderSide(BorderSide(color: AppColors.borderLight)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
