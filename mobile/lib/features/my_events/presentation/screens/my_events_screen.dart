import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/certificate.dart';
import '../../../../shared/models/registration.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../home/providers/events_provider.dart';

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
        appBar: AppBar(title: Text(l10n.myEvents)),
        backgroundColor: AppColors.background,
        body: Padding(
          padding: AppSpacing.screenPadding,
          child: EmptyState(
            icon: Icons.login_rounded,
            title: 'Login required',
            subtitle:
                'Sign in to access your tickets, registration status and event history.',
            actionLabel: 'Login',
            onAction: () => context.push('/login'),
          ),
        ),
      );
    }

    final registrations = _subTabIndex == 0
        ? ref.watch(myFutureRegistrationsProvider)
        : ref.watch(myPastRegistrationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.myEvents),
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              children: [
                AppCard(
                  background: AppColors.primarySoft,
                  borderColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your registrations',
                              style: AppTypography.h3.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Track upcoming tickets, completed events and registration outcomes in one place.',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppSegmentedControl<int>(
                  value: _subTabIndex,
                  items: [
                    AppSegmentItem<int>(
                      value: 0,
                      label: l10n.upcomingEvents,
                    ),
                    AppSegmentItem<int>(
                      value: 1,
                      label: l10n.pastEvents,
                    ),
                  ],
                  onChanged: (value) => setState(() => _subTabIndex = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: registrations.when(
              data: (regs) {
                final filtered = regs.where((r) => r.event != null).toList();
                if (filtered.isEmpty) {
                  return Padding(
                    padding: AppSpacing.screenPadding,
                    child: EmptyState(
                      icon: _subTabIndex == 0
                          ? Icons.event_available_rounded
                          : Icons.history_rounded,
                      title: _subTabIndex == 0
                          ? l10n.noUpcomingEvents
                          : 'No past events yet',
                      subtitle: _subTabIndex == 0
                          ? l10n.noUpcomingEventsSubtitle
                          : 'Completed events and certificates will appear here after you attend.',
                      actionLabel: _subTabIndex == 0 ? l10n.explore : null,
                      onAction: _subTabIndex == 0
                          ? () => context.push('/explore')
                          : null,
                    ),
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
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageX,
                      0,
                      AppSpacing.pageX,
                      AppSpacing.xxxl,
                    ),
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
              loading: () => const LoadingState(
                message: 'Loading your registrations...',
              ),
              error: (e, _) => Padding(
                padding: AppSpacing.screenPadding,
                child: ErrorState(
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

  (String, StatusChipVariant) _statusPresentation() {
    if (registration.hasAttended) {
      return ('Checked-in', StatusChipVariant.success);
    }

    switch (registration.status) {
      case RegistrationStatusEnum.approved:
        if (registration.requiresPayment &&
            (registration.ticketPrice ?? registration.ticketTypePrice ?? 0) >
                0 &&
            registration.ticketCode == null) {
          return ('Paid pending', StatusChipVariant.info);
        }
        return ('Approved', StatusChipVariant.success);
      case RegistrationStatusEnum.pending:
        return ('Pending', StatusChipVariant.warning);
      case RegistrationStatusEnum.waitingList:
        return ('Waitlist', StatusChipVariant.info);
      case RegistrationStatusEnum.rejected:
        return ('Rejected', StatusChipVariant.danger);
      case RegistrationStatusEnum.cancelled:
        return ('Cancelled', StatusChipVariant.neutral);
      case RegistrationStatusEnum.confirmed:
        return ('Confirmed', StatusChipVariant.success);
      case RegistrationStatusEnum.checkedIn:
        return ('Checked-in', StatusChipVariant.success);
      case RegistrationStatusEnum.noShow:
        return ('No-show', StatusChipVariant.danger);
    }
  }

  void _viewTicket(BuildContext context, WidgetRef ref) {
    final event = registration.event!;
    final user = ref.read(currentUserProvider);
    final dateFormat = DateFormat('EEE, MMM d, yyyy • h:mm a');
    final effectivePrice =
        registration.ticketTypePrice ?? registration.ticketPrice ?? 0;

    unawaited(
      context.push(
        '/ticket',
        extra: {
          'eventName': event.title,
          'ticketId': registration.ticketCode ?? registration.id,
          'userName': user?.fullName ?? 'Attendee',
          'eventTime': dateFormat.format(event.startDate),
          'eventLocation': event.location,
          'registrationId': registration.id,
          'checkedInAt': registration.checkedInAt,
          'isTransferable': effectivePrice > 0,
        },
      ),
    );
  }

  Future<void> _viewCertificate(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _CertificateViewerScreen(
          registrationId: registration.id,
          eventTitle: registration.event?.title ?? registration.eventTitle,
          initialCertificate: registration.certificate,
        ),
      ),
    );
  }

  Future<void> _cancelRegistration(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Cancel registration',
      message:
          'Are you sure you want to cancel your registration for "${registration.event?.title}"?',
      primaryLabel: 'Cancel registration',
      secondaryLabel: 'Keep ticket',
      destructive: true,
      icon: Icons.event_busy_rounded,
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

    final canViewTicket = registration.hasValidTicket && isUpcoming;
    final canCancel = isUpcoming &&
        !registration.hasAttended &&
        registration.status != RegistrationStatusEnum.cancelled;
    final canViewCertificate = !isUpcoming &&
        (registration.eligibleForCertificate || registration.certificate != null);
    final (statusText, statusVariant) = _statusPresentation();

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EventListTile(
            event: event,
            compact: true,
            margin: EdgeInsets.zero,
            status: statusText,
            statusVariant: statusVariant,
            onTap: () {
              ref.read(selectedEventProvider.notifier).state = event;
              unawaited(context.push('/event/${event.id}'));
            },
          ),
          if (registration.ticketTypeName != null ||
              registration.quantity > 1 ||
              registration.totalAmount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (registration.ticketTypeName != null)
                  StatusChip(
                    label: registration.ticketTypeName!,
                    variant: StatusChipVariant.neutral,
                  ),
                if (registration.quantity > 1)
                  StatusChip(
                    label: '${registration.quantity} seats',
                    variant: StatusChipVariant.info,
                  ),
                if (registration.totalAmount > 0)
                  StatusChip(
                    label: '\$${registration.totalAmount.toStringAsFixed(2)}',
                    variant: StatusChipVariant.primary,
                  ),
              ],
            ),
          ],
          if (canViewTicket || canCancel || canViewCertificate) ...[
            const SizedBox(height: AppSpacing.lg),
            if (canViewTicket)
              AppButton(
                label: 'View ticket',
                icon: Icons.qr_code_rounded,
                expanded: true,
                onPressed: () => _viewTicket(context, ref),
              ),
            if (canCancel) ...[
              if (canViewTicket) const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Cancel registration',
                icon: Icons.cancel_outlined,
                variant: AppButtonVariant.secondary,
                expanded: true,
                onPressed: () => _cancelRegistration(context, ref),
              ),
            ],
            if (canViewCertificate) ...[
              if (canViewTicket || canCancel)
                const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'View certificate',
                icon: Icons.workspace_premium_outlined,
                variant: AppButtonVariant.tonal,
                expanded: true,
                onPressed: () => _viewCertificate(context, ref),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CertificateViewerScreen extends ConsumerStatefulWidget {
  const _CertificateViewerScreen({
    required this.registrationId,
    this.eventTitle,
    this.initialCertificate,
  });

  final String registrationId;
  final String? eventTitle;
  final Certificate? initialCertificate;

  @override
  ConsumerState<_CertificateViewerScreen> createState() =>
      _CertificateViewerScreenState();
}

class _CertificateViewerScreenState
    extends ConsumerState<_CertificateViewerScreen> {
  String? _filePath;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCertificate();
  }

  Future<void> _loadCertificate() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final certificate = widget.initialCertificate ??
          await api.getCertificateByRegistration(widget.registrationId);
      final pdfBytes = await api.downloadCertificate(certificate.id);

      if (pdfBytes.isEmpty) {
        throw Exception('Certificate PDF is empty');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}${Platform.pathSeparator}certificate_${certificate.id}.pdf',
      );
      await file.writeAsBytes(pdfBytes, flush: true);

      if (!mounted) return;
      setState(() {
        _filePath = file.path;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorUtils.extractMessage(
          e,
          fallback: 'Could not open your certificate.',
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Certificate'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingState(message: 'Opening your certificate...');
    }

    if (_error != null) {
      return Padding(
        padding: AppSpacing.screenPadding,
        child: ErrorState(
          message: _error!,
          onRetry: _loadCertificate,
        ),
      );
    }

    if (_filePath == null) {
      return Padding(
        padding: AppSpacing.screenPadding,
        child: ErrorState(
          message: 'Could not open your certificate.',
          onRetry: _loadCertificate,
        ),
      );
    }

    return PDFView(
      filePath: _filePath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      backgroundColor: AppColors.background,
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _error = error;
        });
      },
      onPageError: (_, error) {
        if (!mounted) return;
        setState(() {
          _error = error;
        });
      },
    );
  }
}

void unawaited(Future<void>? future) {}
