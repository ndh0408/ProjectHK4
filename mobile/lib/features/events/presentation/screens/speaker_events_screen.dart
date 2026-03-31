import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../home/providers/events_provider.dart';

final speakerEventsProvider = FutureProvider.family
    .autoDispose<List<Event>, String>((ref, speakerName) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getEventsBySpeaker(speakerName: speakerName);
  return response.content;
});

class SpeakerEventsScreen extends ConsumerWidget {
  const SpeakerEventsScreen({
    super.key,
    required this.speakerName,
    this.speakerTitle,
    this.speakerImageUrl,
    this.speakerBio,
  });

  final String speakerName;
  final String? speakerTitle;
  final String? speakerImageUrl;
  final String? speakerBio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(speakerEventsProvider(speakerName));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black),
            onPressed: () {
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black),
            onPressed: () {
            },
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) => _buildContent(context, ref, events),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorState(
          message: ErrorUtils.extractMessage(error),
          onRetry: () => ref.invalidate(speakerEventsProvider(speakerName)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, List<Event> events) {
    final now = DateTime.now();
    final upcomingEvents = events.where((e) => e.startTime.isAfter(now)).toList();
    final pastEvents = events.where((e) => e.startTime.isBefore(now)).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: speakerImageUrl != null
                      ? CachedNetworkImageProvider(speakerImageUrl!)
                      : null,
                  child: speakerImageUrl == null
                      ? Text(
                          speakerName.isNotEmpty
                              ? speakerName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),

                Text(
                  speakerName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                if (speakerTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    speakerTitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                Row(
                  children: [
                    _buildStatItem(
                      '${upcomingEvents.length}',
                      'Hosting',
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      '${pastEvents.length}',
                      'Attended',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    _buildSocialIcon(Icons.language),
                    const SizedBox(width: 12),
                    _buildSocialIcon(Icons.link),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),

          if (upcomingEvents.isNotEmpty) ...[
            _buildSectionHeader(context, 'Hosting', upcomingEvents.length),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: upcomingEvents.length > 3 ? 3 : upcomingEvents.length,
              itemBuilder: (context, index) {
                final event = upcomingEvents[index];
                return _EventListItem(
                  event: event,
                  onTap: () {
                    ref.read(selectedEventProvider.notifier).state = event;
                    context.push('/event/${event.id}');
                  },
                );
              },
            ),
          ],

          if (pastEvents.isNotEmpty) ...[
            _buildSectionHeader(context, 'Past Events', pastEvents.length),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: pastEvents.length > 5 ? 5 : pastEvents.length,
              itemBuilder: (context, index) {
                final event = pastEvents[index];
                return _EventListItem(
                  event: event,
                  isPast: true,
                  onTap: () {
                    ref.read(selectedEventProvider.notifier).state = event;
                    context.push('/event/${event.id}');
                  },
                );
              },
            ),
          ],

          if (events.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: EmptyState(
                icon: Icons.event_busy,
                title: 'No Events',
                subtitle: '$speakerName has not participated in any events yet.',
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Row(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 18,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          if (count > 3)
            TextButton(
              onPressed: () {
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventListItem extends StatelessWidget {
  const _EventListItem({
    required this.event,
    required this.onTap,
    this.isPast = false,
  });

  final Event event;
  final VoidCallback onTap;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: event.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildImagePlaceholder(),
                      )
                    : _buildImagePlaceholder(),
              ),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPast ? AppColors.textSecondary : Colors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: isPast ? AppColors.textLight : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${dateFormat.format(event.startTime)}, ${timeFormat.format(event.startTime)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isPast ? AppColors.textLight : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: isPast ? AppColors.textLight : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: isPast ? AppColors.textLight : AppColors.textSecondary,
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

            if (isPast)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Past',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          Icons.event,
          color: AppColors.primary,
          size: 24,
        ),
      ),
    );
  }
}
