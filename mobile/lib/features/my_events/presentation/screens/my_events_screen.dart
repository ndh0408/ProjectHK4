import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/registration.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/providers/events_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';

final myPastRegistrationsProvider =
    FutureProvider.autoDispose<List<Registration>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return [];
  }

  final api = ref.watch(apiServiceProvider);
  final response = await api.getMyRegistrations(upcoming: false);
  return response.content;
});

class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  int _subTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final registrations = _subTabIndex == 0
        ? ref.watch(myFutureRegistrationsProvider)
        : ref.watch(myPastRegistrationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myEvents),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
            child: Row(
              children: [
                _SubTabButton(
                  label: l10n.upcomingEvents,
                  isSelected: _subTabIndex == 0,
                  onTap: () => setState(() => _subTabIndex = 0),
                ),
                const SizedBox(width: 8),
                _SubTabButton(
                  label: l10n.pastEvents,
                  isSelected: _subTabIndex == 1,
                  onTap: () => setState(() => _subTabIndex = 1),
                ),
              ],
            ),
          ),
          Expanded(
            child: registrations.when(
              data: (regs) {
                final filtered = regs.where((r) => r.event != null).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    icon: _subTabIndex == 0
                        ? Icons.event_available
                        : Icons.history,
                    title: _subTabIndex == 0
                        ? l10n.noUpcomingEvents
                        : l10n.pastEvents,
                    subtitle: _subTabIndex == 0
                        ? l10n.noUpcomingEventsSubtitle
                        : l10n.noUpcomingEventsSubtitle,
                    actionLabel: _subTabIndex == 0 ? l10n.explore : null,
                    onAction:
                        _subTabIndex == 0 ? () => context.push('/explore') : null,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    if (_subTabIndex == 0) {
                      ref.invalidate(myFutureRegistrationsProvider);
                    } else {
                      ref.invalidate(myPastRegistrationsProvider);
                    }
                  },
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.horizontalPadding(context)),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final reg = filtered[index];
                      return _RegistrationCard(
                        registration: reg,
                        isUpcoming: _subTabIndex == 0,
                      );
                    },
                  ),
                );
              },
              loading: () => const LoadingState(message: 'Loading your events...'),
              error: (e, _) => ErrorState(
                message: ErrorUtils.extractMessage(e),
                onRetry: () {
                  if (_subTabIndex == 0) {
                    ref.invalidate(myFutureRegistrationsProvider);
                  } else {
                    ref.invalidate(myPastRegistrationsProvider);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationCard extends ConsumerWidget {
  const _RegistrationCard({
    required this.registration,
    required this.isUpcoming,
  });

  final Registration registration;
  final bool isUpcoming;

  Color _getStatusColor(RegistrationStatusEnum status) {
    switch (status) {
      case RegistrationStatusEnum.approved:
        return AppColors.success;
      case RegistrationStatusEnum.pending:
        return AppColors.warning;
      case RegistrationStatusEnum.waitingList:
        return AppColors.primary;
      case RegistrationStatusEnum.rejected:
      case RegistrationStatusEnum.cancelled:
        return AppColors.error;
    }
  }

  String _getStatusText(RegistrationStatusEnum status) {
    switch (status) {
      case RegistrationStatusEnum.approved:
        return 'Approved';
      case RegistrationStatusEnum.pending:
        return 'Pending';
      case RegistrationStatusEnum.waitingList:
        return 'Waitlist';
      case RegistrationStatusEnum.rejected:
        return 'Rejected';
      case RegistrationStatusEnum.cancelled:
        return 'Cancelled';
    }
  }

  void _viewTicket(BuildContext context, WidgetRef ref) {
    final event = registration.event!;
    final user = ref.read(currentUserProvider);
    final dateFormat = DateFormat('EEE, MMM d, yyyy • h:mm a');

    unawaited(context.push(
      '/ticket',
      extra: {
        'eventName': event.title,
        'ticketId': registration.id,
        'userName': user?.fullName ?? 'Attendee',
        'eventTime': dateFormat.format(event.startDate),
        'eventLocation': event.location,
        'registrationId': registration.id,
        'checkedInAt': registration.checkedInAt,
      },
    ),);
  }

  Future<void> _cancelRegistration(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Registration'),
        content: Text(
          'Are you sure you want to cancel your registration for "${registration.event?.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.cancelRegistration(registration.id);

      ref.invalidate(myFutureRegistrationsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration cancelled successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: ${ErrorUtils.extractMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = registration.event;
    if (event == null) {
      return const SizedBox.shrink();
    }

    final dateFormat = DateFormat('EEE, MMM d');
    final timeFormat = DateFormat('h:mm a');
    final canViewTicket =
        registration.status == RegistrationStatusEnum.approved && isUpcoming;
    final canCancel = isUpcoming &&
        registration.status != RegistrationStatusEnum.cancelled;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardMargin = Responsive.spacing(context, base: 12);
    final cardPad = Responsive.spacing(context, base: 12);
    final badgePadH = Responsive.spacing(context, base: 8);
    final badgePadV = Responsive.spacing(context, base: 4);
    final smallIconSize = Responsive.iconSize(context, base: 14);
    final buttonIconSize = Responsive.iconSize(context, base: 18);

    return Card(
      margin: EdgeInsets.only(bottom: cardMargin),
      child: InkWell(
        onTap: () {
          ref.read(selectedEventProvider.notifier).state = event;
          unawaited(context.push('/event/${event.id}'));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(cardPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: badgePadH,
                      vertical: badgePadV,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(registration.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(registration.status),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(registration.status),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (canViewTicket)
                    TextButton.icon(
                      onPressed: () => _viewTicket(context, ref),
                      icon: Icon(Icons.qr_code, size: buttonIconSize),
                      label: Text('View Ticket', style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      )),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: badgePadH),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              SizedBox(height: Responsive.spacing(context)),
              Text(
                event.title,
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: Responsive.spacing(context)),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: smallIconSize,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${dateFormat.format(event.startDate)} • ${timeFormat.format(event.startDate)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: smallIconSize,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 6),
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
              if (canCancel) ...[
                SizedBox(height: Responsive.spacing(context, base: 12)),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelRegistration(context, ref),
                    icon: Icon(Icons.cancel_outlined, size: buttonIconSize),
                    label: const Text('Cancel Registration'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubTabButton extends StatelessWidget {
  const _SubTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.spacing(context, base: 16),
          vertical: Responsive.spacing(context, base: 8),
        ),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colorScheme.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? Colors.white : theme.textTheme.bodySmall?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

void unawaited(Future<void>? future) {}
