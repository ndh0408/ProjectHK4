import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../domain/auth_state.dart';
import '../../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _resendTimer;
  int _resendCooldownSeconds = 60;
  bool _submitting = false;

  /// Cache the email locally so that if an OTP verify error transitions
  /// state through AuthError → Unauthenticated (via clearError), the screen
  /// still knows which address to verify/resend against.
  String _email = '';

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      final s = ref.read(authProvider);
      if (s is PendingEmailVerification) {
        final initialEmail = s.email;
        setState(() => _email = initialEmail);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldownSeconds = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  Future<void> _handleVerify(String email) async {
    if (_controller.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(authProvider.notifier).verifyOtp(
            email: email,
            otp: _controller.text,
          );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleResend(String email) async {
    if (_resendCooldownSeconds > 0) return;
    await ref.read(authProvider.notifier).resendOtp(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('A new verification code has been sent')),
    );
    _startResendCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Keep the cached email in sync if a fresh pending-verification handshake
    // arrives (e.g. login with an unverified account from a different email).
    if (authState is PendingEmailVerification) {
      final incomingEmail = authState.email;
      if (incomingEmail != _email) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _email = incomingEmail);
        });
      }
    }

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    final email = _email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => ref.read(authProvider.notifier).logout(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageX),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Icon(Icons.mark_email_read_rounded,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: AppSpacing.xl),
              Text('Verify your email',
                  textAlign: TextAlign.center,
                  style: AppTypography.h1
                      .copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.md),
              Text(
                'We sent a 6-digit code to\n$email',
                textAlign: TextAlign.center,
                style: AppTypography.body
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppCard(
                child: Column(
                  children: [
                    AppTextField(
                      controller: _controller,
                      label: 'Verification code',
                      hint: '000000',
                      keyboardType: TextInputType.number,
                      enabled: !_submitting,
                      autofocus: true,
                      maxLength: 6,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onSubmitted: (_) => _handleVerify(email),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Verify',
                      onPressed: _submitting ? null : () => _handleVerify(email),
                      loading: _submitting,
                      size: AppButtonSize.lg,
                      expanded: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: _resendCooldownSeconds > 0
                          ? null
                          : () => _handleResend(email),
                      child: Text(
                        _resendCooldownSeconds > 0
                            ? 'Resend code in ${_resendCooldownSeconds}s'
                            : 'Resend code',
                        style: AppTypography.label.copyWith(
                          color: _resendCooldownSeconds > 0
                              ? AppColors.textSecondary
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'The code expires in 10 minutes. If you didn\'t receive it, check your spam folder before resending.',
                textAlign: TextAlign.center,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
