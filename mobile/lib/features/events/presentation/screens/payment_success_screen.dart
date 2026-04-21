import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../my_events/presentation/screens/my_events_screen.dart';

class PaymentSuccessScreen extends ConsumerStatefulWidget {
  const PaymentSuccessScreen({
    super.key,
    this.registrationId,
  });

  final String? registrationId;

  @override
  ConsumerState<PaymentSuccessScreen> createState() =>
      _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends ConsumerState<PaymentSuccessScreen> {
  bool _isConfirming = true;
  bool _isSuccess = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _confirmPayment();
  }

  Future<void> _confirmPayment() async {
    final l10n = AppLocalizations.of(context)!;

    if (widget.registrationId == null) {
      setState(() {
        _isConfirming = false;
        _isSuccess = false;
        _errorMessage = 'Missing registration ID';
      });
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.confirmPayment(widget.registrationId!);

      if (!mounted) return;
      ref.invalidate(myFutureRegistrationsProvider);
      ref.invalidate(myPastRegistrationsProvider);

      setState(() {
        _isConfirming = false;
        _isSuccess = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConfirming = false;
        _isSuccess = false;
        _errorMessage = '$error';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.paymentNotYetConfirmed),
          backgroundColor: AppColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: _isConfirming
                  ? LoadingState(message: l10n.processingPayment)
                  : _isSuccess
                      ? _OutcomeCard(
                          icon: Icons.verified_rounded,
                          iconColor: AppColors.success,
                          background: AppColors.successLight,
                          title: l10n.paymentSuccessful,
                          subtitle:
                              'Your booking is confirmed and your ticket is now available inside My Events.',
                          badges: const [
                            _OutcomeBadge(
                              icon: Icons.lock_outline_rounded,
                              label: 'Secure payment confirmed',
                            ),
                            _OutcomeBadge(
                              icon: Icons.confirmation_number_outlined,
                              label: 'Ticket ready for check-in',
                            ),
                          ],
                          primaryButton: AppButton(
                            label: 'View My Events',
                            icon: Icons.confirmation_number_outlined,
                            expanded: true,
                            onPressed: () => context.go('/my-events'),
                          ),
                          secondaryButton: AppButton(
                            label: 'Back to Home',
                            variant: AppButtonVariant.secondary,
                            expanded: true,
                            onPressed: () => context.go('/home'),
                          ),
                        )
                      : _OutcomeCard(
                          icon: Icons.error_outline_rounded,
                          iconColor: AppColors.error,
                          background: AppColors.errorLight,
                          title: 'Payment verification failed',
                          subtitle: _errorMessage ??
                              'We could not verify the transaction yet. You can retry confirmation or return to the app safely.',
                          badges: const [
                            _OutcomeBadge(
                              icon: Icons.receipt_long_outlined,
                              label: 'No ticket was issued',
                            ),
                            _OutcomeBadge(
                              icon: Icons.support_agent_outlined,
                              label: 'Retry if payment already completed',
                            ),
                          ],
                          primaryButton: AppButton(
                            label: 'Try Again',
                            icon: Icons.refresh_rounded,
                            expanded: true,
                            onPressed: () {
                              setState(() {
                                _isConfirming = true;
                                _errorMessage = null;
                              });
                              _confirmPayment();
                            },
                          ),
                          secondaryButton: AppButton(
                            label: 'Back to Home',
                            variant: AppButtonVariant.secondary,
                            expanded: true,
                            onPressed: () => context.go('/home'),
                          ),
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.badges,
    required this.primaryButton,
    required this.secondaryButton,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String title;
  final String subtitle;
  final List<Widget> badges;
  final Widget primaryButton;
  final Widget secondaryButton;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: iconColor),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.h1.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyLg.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ...badges,
          const SizedBox(height: AppSpacing.xxl),
          primaryButton,
          const SizedBox(height: AppSpacing.md),
          secondaryButton,
        ],
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({
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
            Icon(icon, size: 18, color: AppColors.primary),
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
