import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/error_utils.dart';
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
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.myEvents),
        ),
        body: EmptyState(
          icon: Icons.login,
          title: 'Login Required',
          subtitle: 'Please login to view your events',
          actionLabel: 'Login',
          onAction: () => context.push('/login'),
        ),
      );
    }

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
            padding: const EdgeInsets.all(16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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

  Future<void> _sendCertificateToEmail(BuildContext context, WidgetRef ref) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.sendCertificateByEmail(registration.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certificate sent to your email!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send certificate: ${ErrorUtils.extractMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
    final canGetCertificate = !isUpcoming && registration.eligibleForCertificate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          ref.read(selectedEventProvider.notifier).state = event;
          unawaited(context.push('/event/${event.id}'));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(registration.status)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusText(registration.status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(registration.status),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (canViewTicket)
                    TextButton.icon(
                      onPressed: () => _viewTicket(context, ref),
                      icon: const Icon(Icons.qr_code, size: 18),
                      label: const Text('View Ticket'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${dateFormat.format(event.startDate)} • ${timeFormat.format(event.startDate)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.location,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (canCancel) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelRegistration(context, ref),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Registration'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
              if (canGetCertificate) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _sendCertificateToEmail(context, ref),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Send Certificate to Email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

void unawaited(Future<void>? future) {}
