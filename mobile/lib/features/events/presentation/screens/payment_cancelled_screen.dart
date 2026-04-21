import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/app_components.dart';

class PaymentCancelledScreen extends StatelessWidget {
  const PaymentCancelledScreen({
    super.key,
    this.registrationId,
  });

  final String? registrationId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Center(
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: AppColors.warningLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 50,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    l10n.paymentCancelled,
                    textAlign: TextAlign.center,
                    style: AppTypography.h1.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'You left the payment flow before completion. No charge was created and your booking has not been finalized.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _CancelInfoRow(
                    icon: Icons.credit_card_off_outlined,
                    label: 'No money was captured',
                  ),
                  const _CancelInfoRow(
                    icon: Icons.confirmation_number_outlined,
                    label: 'Ticket remains unconfirmed until payment succeeds',
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  if (registrationId != null) ...[
                    AppButton(
                      label: 'Go to My Events',
                      icon: Icons.event_note_outlined,
                      expanded: true,
                      onPressed: () => context.go('/my-events'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppButton(
                    label: 'Back to Home',
                    variant: AppButtonVariant.secondary,
                    expanded: true,
                    onPressed: () => context.go('/home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelInfoRow extends StatelessWidget {
  const _CancelInfoRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: AppRadius.allMd,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.warning),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
