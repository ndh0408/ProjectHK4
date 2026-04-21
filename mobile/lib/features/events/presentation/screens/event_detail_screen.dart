import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/calendar_utils.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/registration.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/models/ticket_type.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/providers/events_provider.dart';
import '../widgets/ticket_tier_picker.dart';
import '../../../home/presentation/widgets/similar_events_section.dart';
import '../../../chat/presentation/providers/chatbot_provider.dart';

final eventDetailProvider =
    FutureProvider.family.autoDispose<Event, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getEventById(eventId);
});

final registrationStatusProvider =
    FutureProvider.family.autoDispose<RegistrationStatus, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getRegistrationStatus(eventId);
});

final eventReviewsProvider =
    FutureProvider.family.autoDispose<List<Review>, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getEventReviews(eventId, size: 3);
  return response.content;
});

final canReviewProvider =
    FutureProvider.family.autoDispose<bool, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  return api.canReview(eventId);
});

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(apiServiceProvider).trackEventView(widget.eventId);
      ref.read(chatbotProvider.notifier).setActiveEvent(widget.eventId);
    });
  }

  void _refreshData() {
    ref.invalidate(eventDetailProvider(widget.eventId));
    ref.invalidate(registrationStatusProvider(widget.eventId));
    ref.invalidate(eventReviewsProvider(widget.eventId));
    ref.invalidate(canReviewProvider(widget.eventId));
  }

  Future<void> _share(Event event) async {
    final eventUrl = 'https://luma.com/event/${event.id}';
    await Share.share('Check out this event: ${event.title}\n$eventUrl');
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    return eventAsync.when(
      data: (event) => _buildScaffold(event),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: ${ErrorUtils.extractMessage(e)}')),
      ),
    );
  }

  Widget _buildScaffold(Event event) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(event),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainInfo(event),
                  const SizedBox(height: 24),
                  _buildRegistrationSection(event),
                  const SizedBox(height: 32),
                  _buildDescription(event),
                  const SizedBox(height: 32),
                  SimilarEventsSection(eventId: event.id),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Event event) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: event.imageUrl != null
            ? CachedNetworkImage(imageUrl: event.imageUrl!, fit: BoxFit.cover)
            : Container(color: AppColors.primarySoft),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () => _share(event),
        ),
      ],
    );
  }

  Widget _buildMainInfo(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(event.title, style: AppTypography.h1),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              DateFormat('EEEE, MMM d · HH:mm').format(event.startTime),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(event.location, style: AppTypography.body)),
          ],
        ),
      ],
    );
  }

  Widget _buildRegistrationSection(Event event) {
    final regStatusAsync = ref.watch(registrationStatusProvider(widget.eventId));

    return regStatusAsync.when(
      data: (regStatus) {
        final l10n = AppLocalizations.of(context)!;
        
        // Not registered yet
        if (!regStatus.isRegistered) {
          return AppButton(
            label: l10n.register,
            variant: AppButtonVariant.primary,
            onPressed: () => context.push('/event/${event.id}/register'),
          );
        }

        // Already registered - show status-specific UI
        final status = regStatus.status;
        
        // PENDING - Waiting for organizer approval
        if (status == RegistrationStatusEnum.pending) {
          return AppCard(
            background: AppColors.warning.withValues(alpha: 0.1),
            borderColor: AppColors.warning.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registration Pending',
                        style: AppTypography.h4.copyWith(color: AppColors.warning),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Waiting for organizer approval',
                        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // APPROVED - Organizer approved, waiting for user confirmation (free events)
        if (status == RegistrationStatusEnum.approved) {
          if (regStatus.requiresPayment) {
            // Paid event - already approved
            return Column(
              children: [
                AppCard(
                  background: AppColors.success.withValues(alpha: 0.1),
                  borderColor: AppColors.success.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.registered,
                              style: AppTypography.h4.copyWith(color: AppColors.success),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Payment completed • Ready to attend',
                              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Join Event Chat',
                  icon: Icons.chat_bubble_outline,
                  onPressed: () async {
                    try {
                      final conversation = await ref.read(apiServiceProvider).joinEventChat(event.id);
                      if (mounted) {
                        context.push('/chat/${conversation.conversationId}', extra: conversation);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to join chat: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          } else {
            // Free event - needs confirmation
            return Column(
              children: [
                AppCard(
                  background: AppColors.info.withValues(alpha: 0.1),
                  borderColor: AppColors.info.withValues(alpha: 0.2),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Approved - Action Required',
                              style: AppTypography.h4.copyWith(color: AppColors.info),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Confirm your attendance within 48h',
                              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Confirm Attendance',
                  icon: Icons.check_circle_outline,
                  onPressed: () async {
                    try {
                      // Get registration ID from regStatus
                      if (regStatus.registrationId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Registration ID not found')),
                        );
                        return;
                      }
                      
                      final api = ref.read(apiServiceProvider);
                      await api.confirmRegistration(regStatus.registrationId!);
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Attendance confirmed! See you at the event.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        // Refresh the registration status
                        ref.invalidate(registrationStatusProvider(widget.eventId));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to confirm: ${e.toString()}'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          }
        }

        // CONFIRMED - User confirmed (free events)
        if (status == RegistrationStatusEnum.confirmed) {
          return Column(
            children: [
              AppCard(
                background: AppColors.success.withValues(alpha: 0.1),
                borderColor: AppColors.success.withValues(alpha: 0.2),
                child: Row(
                  children: [
                    const Icon(Icons.event_available, color: AppColors.success),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confirmed',
                            style: AppTypography.h4.copyWith(color: AppColors.success),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your spot is secured',
                            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Join Event Chat',
                icon: Icons.chat_bubble_outline,
                onPressed: () async {
                  try {
                    final conversation = await ref.read(apiServiceProvider).joinEventChat(event.id);
                    if (mounted) {
                      context.push('/chat/${conversation.conversationId}', extra: conversation);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to join chat: $e')),
                      );
                    }
                  }
                },
              ),
            ],
          );
        }

        // CHECKED_IN - Already attended
        if (status == RegistrationStatusEnum.checkedIn) {
          return AppCard(
            background: AppColors.success.withValues(alpha: 0.1),
            borderColor: AppColors.success.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.done_all, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checked In',
                        style: AppTypography.h4.copyWith(color: AppColors.success),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You attended this event',
                        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // REJECTED - Organizer rejected
        if (status == RegistrationStatusEnum.rejected) {
          return AppCard(
            background: AppColors.error.withValues(alpha: 0.1),
            borderColor: AppColors.error.withValues(alpha: 0.2),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.cancel, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registration Rejected',
                            style: AppTypography.h4.copyWith(color: AppColors.error),
                          ),
                          if (regStatus.statusMessage != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              regStatus.statusMessage!,
                              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        // CANCELLED - User cancelled
        if (status == RegistrationStatusEnum.cancelled) {
          return AppCard(
            background: AppColors.textSecondary.withValues(alpha: 0.1),
            borderColor: AppColors.textSecondary.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.event_busy, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Registration Cancelled',
                        style: AppTypography.h4.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You cancelled this registration',
                        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // WAITING_LIST - On waiting list
        if (status == RegistrationStatusEnum.waitingList) {
          return AppCard(
            background: AppColors.primary.withValues(alpha: 0.1),
            borderColor: AppColors.primary.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.queue, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiting List',
                        style: AppTypography.h4.copyWith(color: AppColors.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        regStatus.waitingListPosition != null
                            ? 'Position #${regStatus.waitingListPosition}'
                            : 'You\'ll be notified if a spot opens up',
                        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Default fallback
        return AppButton(
          label: l10n.register,
          variant: AppButtonVariant.primary,
          onPressed: () => context.push('/event/${event.id}/register'),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDescription(Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        MarkdownBody(data: event.description ?? ''),
      ],
    );
  }
}
