import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme.dart';
import '../../../../shared/models/event.dart';
import '../../providers/recommendations_provider.dart';
import '../../providers/events_provider.dart';

class SimilarEventsSection extends ConsumerWidget {
  const SimilarEventsSection({
    super.key,
    required this.eventId,
  });

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similarEvents = ref.watch(similarEventsProvider(eventId));

    return similarEvents.when(
      data: (events) {
        if (events.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Similar Events',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'AI',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return _SimilarEventCard(
                    event: event,
                    onTap: () {
                      ref.read(selectedEventProvider.notifier).state = event;
                      context.push('/event/${event.id}');
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _SimilarEventCard extends StatelessWidget {
  const _SimilarEventCard({
    required this.event,
    required this.onTap,
  });

  final Event event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                children: [
                  event.imageUrl != null
                      ? Image.network(
                          event.imageUrl!,
                          width: 200,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 200,
                            height: 80,
                            color: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(Icons.event, size: 24),
                          ),
                        )
                      : Container(
                          width: 200,
                          height: 80,
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.event, size: 24),
                        ),
                  if (event.category != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.textPrimary.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.category!.name,
                          style: const TextStyle(
                            color: AppColors.textOnPrimary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 11,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateFormat.format(event.startDate),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          event.isFree ? 'FREE' : '\$${event.ticketPrice?.toStringAsFixed(0) ?? '0'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: event.isFree ? AppColors.success : AppColors.primary,
                          ),
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
