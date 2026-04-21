import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event_buddy.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart'
    show eventBuddiesProvider;

class EventBuddiesScreen extends ConsumerStatefulWidget {
  const EventBuddiesScreen({super.key});

  @override
  ConsumerState<EventBuddiesScreen> createState() => _EventBuddiesScreenState();
}

class _EventBuddiesScreenState extends ConsumerState<EventBuddiesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(eventBuddiesProvider.notifier).loadBuddies();
    });
  }

  Future<void> _startDirectChat(EventBuddy buddy) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final api = ref.read(apiServiceProvider);
      final conversation = await api.getDirectChat(buddy.userId);

      if (!mounted) return;
      Navigator.pop(context);
      context.push('/chat/${conversation.id}', extra: conversation);
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start chat: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventBuddiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Event Buddies'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: Row(
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.read(eventBuddiesProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                  tooltip: 'Discover matches',
                  onPressed: () => context.push('/networking'),
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
      body: state.isLoading && state.buddies.isEmpty
          ? const LoadingState(message: 'Finding event buddies...')
          : state.error != null && state.buddies.isEmpty
              ? ErrorState(
                  message: state.error!,
                  onRetry: () =>
                      ref.read(eventBuddiesProvider.notifier).refresh(),
                )
              : state.buddies.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'No event buddies yet',
                      subtitle:
                          'Register for events to match with attendees who share the same interests or schedule.',
                      actionLabel: 'Explore Events',
                      onAction: () => context.go('/explore'),
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () =>
                          ref.read(eventBuddiesProvider.notifier).refresh(),
                      child: ListView(
                        padding: AppSpacing.screenPadding,
                        children: [
                          AppCard(
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.section,
                            ),
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
                                    Icons.diversity_3_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${state.buddies.length} possible connections',
                                        style: AppTypography.h3.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Event buddies turn shared attendance into direct chat opportunities without extra searching.',
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
                          ...state.buddies.map(
                            (buddy) => _BuddyCard(
                              buddy: buddy,
                              onTap: () => _startDirectChat(buddy),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _BuddyCard extends StatelessWidget {
  const _BuddyCard({
    required this.buddy,
    required this.onTap,
  });

  final EventBuddy buddy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: buddy.avatarUrl != null
                    ? NetworkImage(buddy.avatarUrl!)
                    : null,
                child: buddy.avatarUrl == null
                    ? Text(
                        buddy.fullName.isNotEmpty
                            ? buddy.fullName.substring(0, 1).toUpperCase()
                            : '?',
                        style: AppTypography.h3.copyWith(
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 3,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.allPill,
                  ),
                  child: Text(
                    '${buddy.sharedEventsCount}',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buddy.fullName,
                  style: AppTypography.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${buddy.sharedEventsCount} shared event${buddy.sharedEventsCount > 1 ? 's' : ''}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (buddy.sharedEvents != null &&
                    buddy.sharedEvents!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    buddy.sharedEvents!
                        .map((event) => event.eventTitle)
                        .take(2)
                        .join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          const Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
