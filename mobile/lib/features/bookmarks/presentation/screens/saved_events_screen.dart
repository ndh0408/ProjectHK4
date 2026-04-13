import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../home/providers/events_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';

class SavedEventsScreen extends ConsumerWidget {
  const SavedEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bookmarkedEvents = ref.watch(bookmarkedEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.savedEvents),
      ),
      body: bookmarkedEvents.when(
        data: (events) {
          if (events.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_border,
              title: l10n.noSavedEvents,
              subtitle: l10n.noSavedEventsSubtitle,
              actionLabel: l10n.explore,
              onAction: () => context.go('/explore'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bookmarkedEventsProvider);
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _SavedEventItem(event: event);
              },
            ),
          );
        },
        loading: () => const LoadingState(message: 'Loading saved events...'),
        error: (e, _) => ErrorState(
          message: ErrorUtils.extractMessage(e),
          onRetry: () => ref.invalidate(bookmarkedEventsProvider),
        ),
      ),
    );
  }
}

class _SavedEventItem extends ConsumerWidget {
  const _SavedEventItem({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () {
        ref.read(selectedEventProvider.notifier).state = event;
        context.push('/event/${event.id}');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: event.imageUrl != null
                  ? Image.network(
                      event.imageUrl!,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.divider,
                        backgroundImage: event.organiser?.avatarUrl != null
                            ? NetworkImage(event.organiser!.avatarUrl!)
                            : null,
                        child: event.organiser?.avatarUrl == null
                            ? Text(
                                (event.organiser?.fullName ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10, color: AppColors.textOnPrimary),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.organiser?.fullName ?? 'Unknown Organiser',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          await ref.read(bookmarkNotifierProvider.notifier).toggle(event.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.removedFromSaved),
                                backgroundColor: AppColors.textSecondary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Icon(
                          Icons.bookmark,
                          size: 20,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('EEE, MMM d').format(event.startTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(event.startTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.warningLight, AppColors.warning],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.event, color: AppColors.warning, size: 32),
    );
  }
}
