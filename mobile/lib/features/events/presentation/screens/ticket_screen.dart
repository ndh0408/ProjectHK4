import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_components.dart';

class TicketScreen extends ConsumerWidget {
  const TicketScreen({
    super.key,
    required this.eventName,
    required this.ticketId,
    required this.userName,
    required this.eventTime,
    required this.eventLocation,
    this.registrationId,
    this.checkedInAt,
  });

  final String eventName;
  final String ticketId;
  final String userName;
  final String eventTime;
  final String eventLocation;
  final String? registrationId;
  final DateTime? checkedInAt;

  bool get isCheckedIn => checkedInAt != null;

  Future<void> _showTransferDialog(BuildContext context, WidgetRef ref) async {
    if (registrationId == null || isCheckedIn) return;

    final controller = TextEditingController();

    await AppBottomSheet.show<void>(
      context: context,
      title: 'Transfer ticket',
      subtitle: 'Send this ticket to another attendee by email.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: controller,
            label: 'Recipient email',
            hint: 'recipient@example.com',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Transfer ticket',
            icon: Icons.swap_horiz_rounded,
            expanded: true,
            onPressed: () async {
              final recipient = controller.text.trim();
              if (recipient.isEmpty) return;

              try {
                final api = ref.read(apiServiceProvider);
                await api.transferTicket(registrationId!, recipient);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transfer initiated successfully'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to transfer ticket: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final qrData = registrationId ?? ticketId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.ticket),
        actions: [
          if (registrationId != null && !isCheckedIn)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Transfer ticket',
              onPressed: () => _showTransferDialog(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          AppCard(
            background:
                isCheckedIn ? AppColors.successLight : AppColors.primarySoft,
            borderColor: isCheckedIn
                ? AppColors.success.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusChip(
                      label: isCheckedIn ? l10n.checkedIn : 'Active ticket',
                      variant: isCheckedIn
                          ? StatusChipVariant.success
                          : StatusChipVariant.primary,
                      icon: isCheckedIn
                          ? Icons.check_circle_rounded
                          : Icons.qr_code_2_rounded,
                    ),
                    const Spacer(),
                    StatusChip(
                      label:
                          'Ref ${ticketId.length >= 8 ? ticketId.substring(0, 8).toUpperCase() : ticketId.toUpperCase()}',
                      variant: StatusChipVariant.neutral,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  eventName,
                  style:
                      AppTypography.h2.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  userName,
                  style: AppTypography.bodyLg.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (isCheckedIn) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${l10n.checkedInAt} ${DateFormat('MMM d, yyyy h:mm a').format(checkedInAt!)}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: AppRadius.allMd,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: isCheckedIn ? 0.32 : 1,
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      if (isCheckedIn)
                        Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  isCheckedIn ? l10n.youHaveCheckedIn : l10n.showQrAtEntrance,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLg.copyWith(
                    color:
                        isCheckedIn ? AppColors.success : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                _TicketMetaRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date & time',
                  value: eventTime,
                ),
                const Divider(height: AppSpacing.xl),
                _TicketMetaRow(
                  icon: Icons.location_on_outlined,
                  label: 'Venue',
                  value: eventLocation,
                ),
                const Divider(height: AppSpacing.xl),
                _TicketMetaRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Attendee',
                  value: userName,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: registrationId != null && !isCheckedIn
          ? SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageX,
                  AppSpacing.md,
                  AppSpacing.pageX,
                  AppSpacing.pageY,
                ),
                child: AppCard(
                  shadow: AppShadows.md,
                  child: AppButton(
                    label: 'Transfer ticket',
                    icon: Icons.swap_horiz_rounded,
                    size: AppButtonSize.lg,
                    expanded: true,
                    onPressed: () => _showTransferDialog(context, ref),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _TicketMetaRow extends StatelessWidget {
  const _TicketMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: AppRadius.allMd,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                value,
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
