import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/responsive.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth * 0.19;
    final hPadding = Responsive.horizontalPadding(context);

    return GestureDetector(
      onTap: () {
        ref.read(selectedEventProvider.notifier).state = event;
        context.push('/event/${event.id}');
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: Responsive.spacing(context, base: 12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: event.imageUrl != null
                  ? Image.network(
                      event.imageUrl!,
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(imageSize),
                    )
                  : _buildPlaceholder(imageSize),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: Responsive.iconSize(context, base: 10),
                        backgroundColor: theme.disabledColor,
                        backgroundImage: event.organiser?.avatarUrl != null
                            ? NetworkImage(event.organiser!.avatarUrl!)
                            : null,
                        child: event.organiser?.avatarUrl == null
                            ? Text(
                                (event.organiser?.fullName ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10, color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.organiser?.fullName ?? 'Unknown Organiser',
                          style: theme.textTheme.bodySmall,
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
                                backgroundColor: theme.textTheme.bodyMedium?.color,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Icon(
                          Icons.bookmark,
                          size: Responsive.iconSize(context, base: 20),
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  Text(
                    event.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: Responsive.iconSize(context, base: 14), color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('EEE, MMM d').format(event.startTime),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time, size: Responsive.iconSize(context, base: 14), color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(event.startTime),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: Responsive.iconSize(context, base: 14), color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: theme.textTheme.bodySmall,
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

  Widget _buildPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.orange[200]!, Colors.orange[400]!],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.event, color: Colors.orange[700], size: size * 0.44),
    );
  }
}
