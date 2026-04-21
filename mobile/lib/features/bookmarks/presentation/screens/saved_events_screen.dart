import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../home/providers/events_provider.dart';

class SavedEventsScreen extends ConsumerWidget {
  const SavedEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bookmarkedEvents = ref.watch(bookmarkedEventsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.savedEvents),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              tooltip: l10n.refreshTooltip,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () => ref.invalidate(bookmarkedEventsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: bookmarkedEvents.when(
        data: (events) {
          if (events.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_add_outlined,
              iconColor: AppColors.warning,
              title: l10n.noSavedEvents,
              subtitle: l10n.noSavedEventsSubtitle,
              actionLabel: l10n.explore,
              onAction: () => context.go('/explore'),
            );
          }

          final upcomingCount =
              events.where((event) => !event.isEventEnded).length;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(bookmarkedEventsProvider),
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
                  background: AppColors.surface,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.secondary,
                              AppColors.accent,
                            ],
                          ),
                          borderRadius: AppRadius.allLg,
                        ),
                        child: const Icon(
                          Icons.bookmark_added_rounded,
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
                              'Saved for later',
                              style: AppTypography.h3.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '$upcomingCount upcoming events, ${events.length} bookmarked in total.',
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
                  title: 'Your saved events',
                  subtitle:
                      'Keep shortlists here so you can jump back into the booking flow quickly.',
                ),
                const SizedBox(height: AppSpacing.lg),
                ...events.map(
                  (event) => EventListTile(
                    event: event,
                    compact: true,
                    status: _statusLabel(event),
                    statusVariant: _statusVariant(event),
                    onTap: () {
                      ref.read(selectedEventProvider.notifier).state = event;
                      context.push('/event/${event.id}');
                    },
                    trailing: _RemoveBookmarkButton(event: event),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const LoadingState(message: 'Loading saved events...'),
        error: (error, _) => ErrorState(
          message: ErrorUtils.extractMessage(error),
          onRetry: () => ref.invalidate(bookmarkedEventsProvider),
        ),
      ),
    );
  }

  static String _statusLabel(Event event) {
    if (event.status == EventStatus.cancelled) return 'Cancelled';
    if (event.isEventEnded) return 'Ended';
    if (event.isFull) return 'Sold out';
    if (event.isRegistrationClosed) return 'Closed';
    if (event.isAlmostFull) return 'Almost full';
    return 'Open';
  }

  static StatusChipVariant _statusVariant(Event event) {
    if (event.status == EventStatus.cancelled) return StatusChipVariant.danger;
    if (event.isEventEnded) return StatusChipVariant.neutral;
    if (event.isFull) return StatusChipVariant.warning;
    if (event.isRegistrationClosed) return StatusChipVariant.warning;
    if (event.isAlmostFull) return StatusChipVariant.info;
    return StatusChipVariant.success;
  }
}

class _RemoveBookmarkButton extends ConsumerWidget {
  const _RemoveBookmarkButton({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.removedFromSaved,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.warningLight,
        foregroundColor: AppColors.warning,
      ),
      onPressed: () async {
        await ref.read(bookmarkNotifierProvider.notifier).toggle(event.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.removedFromSaved),
            backgroundColor: AppColors.textPrimary,
          ),
        );
      },
      icon: const Icon(Icons.bookmark_remove_rounded, size: 20),
    );
  }
}
