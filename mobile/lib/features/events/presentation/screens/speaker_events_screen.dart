import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../home/providers/events_provider.dart';

final speakerEventsProvider =
    FutureProvider.family.autoDispose<List<Event>, String>((
  ref,
  speakerName,
) async {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Speaker profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () =>
                  ref.invalidate(speakerEventsProvider(speakerName)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: eventsAsync.when(
        data: (events) => _buildContent(context, ref, events),
        loading: () => const LoadingState(message: 'Loading speaker events...'),
        error: (error, _) => ErrorState(
          message: ErrorUtils.extractMessage(error),
          onRetry: () => ref.invalidate(speakerEventsProvider(speakerName)),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, List<Event> events) {
    final now = DateTime.now();
    final upcomingEvents =
        events.where((event) => event.startTime.isAfter(now)).toList();
    final pastEvents =
        events.where((event) => !event.startTime.isAfter(now)).toList();

    if (events.isEmpty) {
      return EmptyState(
        icon: Icons.mic_external_off_outlined,
        title: 'No events yet',
        subtitle: '$speakerName has not been linked to any event sessions yet.',
      );
    }

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.section),
          borderColor: AppColors.borderLight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: speakerImageUrl != null
                    ? CachedNetworkImageProvider(speakerImageUrl!)
                    : null,
                child: speakerImageUrl == null
                    ? Text(
                        speakerName.isNotEmpty
                            ? speakerName.substring(0, 1).toUpperCase()
                            : 'S',
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
                    Text(
                      speakerName,
                      style: AppTypography.h2.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (speakerTitle?.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        speakerTitle!,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        StatusChip(
                          label: '${upcomingEvents.length} upcoming',
                          variant: StatusChipVariant.success,
                          compact: true,
                        ),
                        StatusChip(
                          label: '${pastEvents.length} past',
                          variant: StatusChipVariant.neutral,
                          compact: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (speakerBio?.trim().isNotEmpty == true) ...[
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About the speaker',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  speakerBio!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (upcomingEvents.isNotEmpty) ...[
          SectionHeader(
            title: 'Upcoming sessions',
            subtitle: '${upcomingEvents.length} event appearances coming up',
          ),
          const SizedBox(height: AppSpacing.lg),
          ...upcomingEvents.map(
            (event) => EventListTile(
              event: event,
              compact: true,
              status: 'Upcoming',
              statusVariant: StatusChipVariant.success,
              onTap: () {
                ref.read(selectedEventProvider.notifier).state = event;
                context.push('/event/${event.id}');
              },
            ),
          ),
        ],
        if (pastEvents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.section),
          SectionHeader(
            title: 'Past appearances',
            subtitle: '${pastEvents.length} previous sessions or events',
          ),
          const SizedBox(height: AppSpacing.lg),
          ...pastEvents.map(
            (event) => EventListTile(
              event: event,
              compact: true,
              status: 'Past',
              statusVariant: StatusChipVariant.neutral,
              onTap: () {
                ref.read(selectedEventProvider.notifier).state = event;
                context.push('/event/${event.id}');
              },
            ),
          ),
        ],
      ],
    );
  }
}
