import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/theme.dart';
import '../../../core/design_tokens/design_tokens.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_components.dart';
import '../providers/calendar_provider.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState
    extends ConsumerState<CalendarSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(googleCalendarProvider.notifier).loadStatus();
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.neutral900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _connectGoogleCalendar() async {
    try {
      final authUrl =
          await ref.read(googleCalendarProvider.notifier).getAuthUrl();
      final uri = Uri.parse(authUrl);

      if (!await canLaunchUrl(uri)) {
        _showSnack(
          'Could not open the Google authorization page.',
          isError: true,
        );
        return;
      }

      await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (mounted) {
        _showAuthCodeDialog();
      }
    } catch (e) {
      _showSnack('Failed to start Google Calendar connection: $e',
          isError: true);
    }
  }

  void _showAuthCodeDialog() {
    final codeController = TextEditingController();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AppDialog(
          title: 'Complete Google Calendar setup',
          message:
              'After granting access in your browser, paste the authorization code here to finish syncing.',
          icon: Icons.calendar_month_rounded,
          primaryLabel: 'Connect',
          secondaryLabel: 'Cancel',
          onSecondary: () => Navigator.of(dialogContext).pop(),
          onPrimary: () async {
            final code = codeController.text.trim();
            if (code.isEmpty) {
              _showSnack('Authorization code is required.', isError: true);
              return;
            }

            Navigator.of(dialogContext).pop();
            try {
              await ref
                  .read(googleCalendarProvider.notifier)
                  .connect(code: code);
              _showSnack('Google Calendar connected successfully.');
            } catch (e) {
              _showSnack('Failed to connect Google Calendar: $e',
                  isError: true);
            }
          },
          children: [
            AppTextField(
              controller: codeController,
              label: 'Authorization code',
              hint: 'Paste the code from Google',
              prefixIcon: Icons.key_rounded,
              maxLines: 3,
              autofocus: true,
              required: true,
            ),
          ],
        );
      },
    );
  }

  Future<void> _disconnectGoogleCalendar() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Disconnect Google Calendar?',
      message:
          'This removes future sync access and clears synced events from your Google Calendar.',
      primaryLabel: 'Disconnect',
      secondaryLabel: 'Keep Connected',
      icon: Icons.link_off_rounded,
      destructive: true,
    );

    if (confirmed != true) return;

    await ref.read(googleCalendarProvider.notifier).disconnect();
    _showSnack('Google Calendar disconnected.');
  }

  Future<void> _syncAllEvents() async {
    final syncedCount =
        await ref.read(googleCalendarProvider.notifier).syncAllEvents();
    _showSnack('Synced $syncedCount events to Google Calendar.');
  }

  Future<void> _unsyncEvent(String registrationId) async {
    await ref.read(googleCalendarProvider.notifier).unsyncEvent(registrationId);
    _showSnack('Event removed from Google Calendar.');
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(googleCalendarProvider);
    final status = calendarState.status;
    final syncedEvents = calendarState.syncedEvents;
    final connected = calendarState.isConnected;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calendar Sync'),
      ),
      body: calendarState.isLoading && status == null
          ? const LoadingState(message: 'Checking calendar connection...')
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(googleCalendarProvider.notifier).loadStatus(),
              child: ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.section),
                    background:
                        connected ? AppColors.primarySoft : AppColors.surface,
                    borderColor: connected
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : AppColors.borderLight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: connected
                                    ? AppColors.primaryGradient
                                    : null,
                                color:
                                    connected ? null : AppColors.surfaceVariant,
                                borderRadius: AppRadius.allLg,
                              ),
                              child: Icon(
                                connected
                                    ? Icons.cloud_done_rounded
                                    : Icons.event_busy_rounded,
                                color: connected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: AppSpacing.sm,
                                    runSpacing: AppSpacing.sm,
                                    children: [
                                      StatusChip(
                                        label: connected
                                            ? 'Connected'
                                            : 'Not Connected',
                                        variant: connected
                                            ? StatusChipVariant.success
                                            : StatusChipVariant.neutral,
                                      ),
                                      StatusChip(
                                        label:
                                            '${status?.syncedEventsCount ?? syncedEvents.length} events synced',
                                        variant: StatusChipVariant.primary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    connected
                                        ? 'Keep your event bookings aligned with your daily calendar.'
                                        : 'Connect Google Calendar to sync registrations, reminders, and schedule updates automatically.',
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (status?.email != null) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.alternate_email_rounded,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: Text(
                                            status!.email!,
                                            style: AppTypography.label.copyWith(
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (status?.connectedAt != null) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Connected ${DateFormat('MMM d, yyyy • h:mm a').format(status!.connectedAt!)}',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (connected) ...[
                          Row(
                            children: [
                              Expanded(
                                child: AppButton(
                                  label: calendarState.isLoading
                                      ? 'Syncing...'
                                      : 'Sync All Events',
                                  icon: Icons.sync_rounded,
                                  onPressed: calendarState.isLoading
                                      ? null
                                      : _syncAllEvents,
                                  expanded: true,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: AppButton(
                                  label: 'Disconnect',
                                  icon: Icons.link_off_rounded,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: calendarState.isLoading
                                      ? null
                                      : _disconnectGoogleCalendar,
                                  expanded: true,
                                ),
                              ),
                            ],
                          ),
                        ] else
                          AppButton(
                            label: calendarState.isConnecting
                                ? 'Connecting...'
                                : 'Connect Google Calendar',
                            icon: Icons.add_link_rounded,
                            onPressed: calendarState.isConnecting
                                ? null
                                : _connectGoogleCalendar,
                            expanded: true,
                          ),
                      ],
                    ),
                  ),
                  if (calendarState.error != null)
                    AppCard(
                      margin: const EdgeInsets.only(bottom: AppSpacing.section),
                      background: AppColors.error.withValues(alpha: 0.06),
                      borderColor: AppColors.error.withValues(alpha: 0.18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sync issue detected',
                                  style: AppTypography.h4.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  calendarState.error!,
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
                    title: 'How It Works',
                    subtitle:
                        'Calendar sync should reduce manual effort, not add setup friction.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const AppCard(
                    margin: EdgeInsets.only(bottom: AppSpacing.section),
                    child: Column(
                      children: [
                        _BenefitRow(
                          icon: Icons.notifications_active_rounded,
                          title: 'Reminder coverage',
                          description:
                              'Registered events appear in your Google Calendar so reminders stay in one place.',
                        ),
                        SizedBox(height: AppSpacing.lg),
                        _BenefitRow(
                          icon: Icons.update_rounded,
                          title: 'Automatic updates',
                          description:
                              'When event timing changes, synced calendar entries can stay aligned.',
                        ),
                        SizedBox(height: AppSpacing.lg),
                        _BenefitRow(
                          icon: Icons.cleaning_services_rounded,
                          title: 'Easy cleanup',
                          description:
                              'Unsync a single booking or disconnect the integration without touching your booking history.',
                        ),
                      ],
                    ),
                  ),
                  const SectionHeader(
                    title: 'Synced Events',
                    subtitle:
                        'Review which registrations are currently mirrored into your calendar.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!connected)
                    const EmptyState(
                      icon: Icons.calendar_month_outlined,
                      compact: true,
                      title: 'No calendar connection yet',
                      subtitle:
                          'Connect Google Calendar first to start syncing your booked events.',
                    )
                  else if (syncedEvents.isEmpty)
                    const EmptyState(
                      icon: Icons.event_note_rounded,
                      compact: true,
                      title: 'No synced events yet',
                      subtitle:
                          'Once your event registrations are synced, they will appear here for quick management.',
                    )
                  else
                    ...syncedEvents.map((syncedEvent) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _SyncedEventCard(
                          syncedEvent: syncedEvent,
                          onUnsync: () =>
                              _unsyncEvent(syncedEvent.registrationId),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppRadius.allMd,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.h4.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SyncedEventCard extends StatelessWidget {
  const _SyncedEventCard({
    required this.syncedEvent,
    required this.onUnsync,
  });

  final CalendarSyncResult syncedEvent;
  final VoidCallback onUnsync;

  @override
  Widget build(BuildContext context) {
    final dateRange =
        '${DateFormat('EEE, MMM d').format(syncedEvent.eventStartTime)} • ${DateFormat('h:mm a').format(syncedEvent.eventStartTime)} - ${DateFormat('h:mm a').format(syncedEvent.eventEndTime)}';

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: AppRadius.allMd,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    StatusChip(
                      label: 'Synced',
                      variant: StatusChipVariant.success,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  syncedEvent.eventTitle,
                  style: AppTypography.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        dateRange,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (syncedEvent.lastSyncedAt != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Last synced ${DateFormat('MMM d, h:mm a').format(syncedEvent.lastSyncedAt!)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Remove Sync',
                  icon: Icons.remove_circle_outline_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  onPressed: onUnsync,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
