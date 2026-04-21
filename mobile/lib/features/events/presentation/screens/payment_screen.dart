import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/coupon.dart';
import '../../../../shared/widgets/app_components.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({
    super.key,
    required this.registrationId,
    required this.eventTitle,
    required this.amount,
    this.tierName,
    this.unitPrice,
    this.quantity = 1,
  });

  final String registrationId;
  final String eventTitle;
  final double amount;
  final String? tierName;
  final double? unitPrice;
  final int quantity;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  bool _isLoading = false;
  bool _isPaymentReady = false;
  String? _clientSecret;
  String? _checkoutUrl;
  String? _errorMessage;
  final TextEditingController _couponController = TextEditingController();
  Map<String, dynamic>? _appliedCoupon;
  bool _validatingCoupon = false;

  // Coupons that the backend says the current user can use for this
  // registration (global + event-specific, sorted by discount).
  List<Coupon> _availableCoupons = [];
  bool _loadingAvailableCoupons = false;

  double get _effectiveAmount => _appliedCoupon != null
      ? ((_appliedCoupon!['finalAmount'] as num?)?.toDouble() ?? widget.amount)
      : widget.amount;

  double get _discountAmount =>
      (_appliedCoupon?['discountAmount'] as num?)?.toDouble() ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiatePayment();
      _loadAvailableCoupons();
    });
  }

  Future<void> _loadAvailableCoupons() async {
    if (!mounted) return;
    setState(() => _loadingAvailableCoupons = true);
    try {
      final api = ref.read(apiServiceProvider);
      final coupons = await api.getUserCoupons(
        registrationId: widget.registrationId,
      );
      if (!mounted) return;
      setState(() {
        _availableCoupons = coupons.where((c) => c.isValid).toList()
          ..sort((a, b) {
            // Put higher-value discounts first. Percentage vs fixed amounts
            // are roughly comparable enough for this UX hint.
            final byValue = b.discountValue.compareTo(a.discountValue);
            return byValue;
          });
        _loadingAvailableCoupons = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableCoupons = [];
        _loadingAvailableCoupons = false;
      });
    }
  }

  Future<void> _applyCouponFromChip(Coupon coupon) async {
    if (_appliedCoupon != null || _validatingCoupon) return;
    _couponController.text = coupon.code;
    await _applyCoupon();
  }

  Widget _buildAvailableCouponsSection() {
    if (_loadingAvailableCoupons) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: SizedBox(
          height: 16,
          child: LinearProgressIndicator(minHeight: 2),
        ),
      );
    }
    if (_availableCoupons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Coupons available for you (${_availableCoupons.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: _availableCoupons
                .map((c) => _CouponSuggestionTile(
                      coupon: c,
                      disabled: _appliedCoupon != null || _validatingCoupon,
                      onApply: () => _applyCouponFromChip(c),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _validatingCoupon = true);
    try {
      final api = ref.read(apiServiceProvider);
      final result =
          await api.validateCoupon(code, widget.amount, widget.registrationId);
      if (result['valid'] == true) {
        setState(() {
          _appliedCoupon = result;
          _validatingCoupon = false;
        });
        await _initiatePayment();
      } else {
        setState(() => _validatingCoupon = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(result['message'] ?? 'Invalid coupon'),
                backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _validatingCoupon = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to validate: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
    });
    _initiatePayment();
  }

  Future<void> _initiatePayment() async {
    debugPrint('=== INITIATE PAYMENT START ===');
    debugPrint('Registration ID: ${widget.registrationId}');
    debugPrint('Amount: ${widget.amount}');
    debugPrint('Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiServiceProvider);

      if (kIsWeb) {
        debugPrint('Calling API createCheckoutSession for web...');
        final couponCode =
            _appliedCoupon != null ? _appliedCoupon!['code'] as String? : null;
        final result = await api.createCheckoutSession(widget.registrationId,
            couponCode: couponCode);
        debugPrint('API Response: $result');

        setState(() {
          _checkoutUrl = result['checkoutUrl'];
          debugPrint(
              'Checkout URL received: ${_checkoutUrl != null ? 'YES' : 'NULL'}');
          _isLoading = false;
          _isPaymentReady = _checkoutUrl != null;
        });
      } else {
        debugPrint('Calling API initiatePayment for mobile...');
        final couponCode =
            _appliedCoupon != null ? _appliedCoupon!['code'] as String? : null;
        final result = await api.initiatePayment(widget.registrationId,
            couponCode: couponCode);
        debugPrint('API Response: $result');

        setState(() {
          _clientSecret = result['clientSecret'];
          debugPrint(
              'Client Secret received: ${_clientSecret != null ? '${_clientSecret!.substring(0, 20)}...' : 'NULL'}');
          _isLoading = false;
          _isPaymentReady = _clientSecret != null;
        });
      }
      debugPrint('=== INITIATE PAYMENT SUCCESS ===');
    } catch (e, stackTrace) {
      debugPrint('=== INITIATE PAYMENT ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
        _errorMessage = ErrorUtils.extractMessage(e,
            fallback: 'Failed to initiate payment');
      });
    }
  }

  Future<void> _processPayment() async {
    debugPrint('=== PROCESS PAYMENT START ===');
    debugPrint('Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}');

    if (kIsWeb) {
      await _processWebPayment();
    } else {
      await _processMobilePayment();
    }
  }

  Future<void> _processWebPayment() async {
    debugPrint('Processing web payment with Stripe Checkout...');

    if (_checkoutUrl == null) {
      debugPrint('ERROR: Checkout URL is null!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.paymentNotReady),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(_checkoutUrl!);
      debugPrint('Opening Stripe Checkout: $_checkoutUrl');

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (mounted) {
          setState(() => _isLoading = false);

          await showDialog(
            context: context,
            builder: (dialogContext) {
              final l10n = AppLocalizations.of(dialogContext)!;
              return AlertDialog(
                title: Text(l10n.completePayment),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.newWindowOpened),
                    const SizedBox(height: 12),
                    Text(l10n.afterCompletingPayment),
                    const SizedBox(height: 8),
                    Text(l10n.youWillBeRedirected),
                    Text(l10n.yourRegistrationConfirmed),
                    const SizedBox(height: 12),
                    Text(
                      l10n.checkPopupBlocker,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.ok),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _checkPaymentStatus();
                    },
                    child: Text(l10n.iveCompletedPayment),
                  ),
                ],
              );
            },
          );
        }
      } else {
        throw Exception('Could not launch payment URL');
      }
    } catch (e, stackTrace) {
      debugPrint('=== WEB PAYMENT ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              ErrorUtils.extractMessage(e, fallback: 'Failed to open payment')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _checkPaymentStatus() async {
    debugPrint('Checking payment status...');
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.checkPaymentStatus(widget.registrationId);
      debugPrint('Payment status: $result');

      final status = result['status'];
      if (status == 'PAID' || status == 'CONFIRMED') {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              final l10n = AppLocalizations.of(dialogContext)!;
              return AlertDialog(
                icon: const Icon(Icons.check_circle,
                    color: AppColors.success, size: 64),
                title: Text(l10n.paymentSuccessful),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.yourRegistrationHasBeenConfirmed),
                    const SizedBox(height: 8),
                    Text(
                      'Event: ${widget.eventTitle}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.pop(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: Text(l10n.viewMyTicket),
                  ),
                ],
              );
            },
          );
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.paymentNotYetConfirmed),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error checking payment status: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.extractMessage(e,
              fallback: 'Failed to check payment status')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _processMobilePayment() async {
    debugPrint('Processing mobile payment with Payment Sheet...');
    debugPrint(
        'Client Secret: ${_clientSecret != null ? '${_clientSecret!.substring(0, 20)}...' : 'NULL'}');

    if (_clientSecret == null) {
      debugPrint('ERROR: Client secret is null!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.paymentNotReady),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('Step 1: Initializing payment sheet...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: _clientSecret!,
          merchantDisplayName: 'LUMA Events',
          style: ThemeMode.system,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: AppColors.primary,
            ),
          ),
        ),
      );
      debugPrint('Step 1: Payment sheet initialized successfully');

      debugPrint('Step 2: Presenting payment sheet...');
      await Stripe.instance.presentPaymentSheet();
      debugPrint('Step 2: Payment sheet completed successfully');

      debugPrint('Step 3: Confirming payment with backend...');
      await _confirmPaymentWithBackend();
      debugPrint('=== PROCESS PAYMENT SUCCESS ===');
    } on StripeException catch (e, stackTrace) {
      debugPrint('=== STRIPE EXCEPTION ===');
      debugPrint('Error code: ${e.error.code}');
      debugPrint('Error message: ${e.error.message}');
      debugPrint('Stack trace: $stackTrace');

      setState(() => _isLoading = false);

      if (e.error.code == FailureCode.Canceled) {
        debugPrint('User cancelled payment');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.paymentCancelledByUser),
            backgroundColor: AppColors.warning,
          ),
        );
      } else {
        final errorMsg =
            e.error.localizedMessage ?? e.error.message ?? 'Payment failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stripe [${e.error.code}]: $errorMsg'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== GENERAL EXCEPTION ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.extractMessage(e, fallback: e.toString())),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _confirmPaymentWithBackend() async {
    debugPrint('=== CONFIRM PAYMENT WITH BACKEND START ===');
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.confirmPayment(widget.registrationId);
      debugPrint('Confirm payment response: $result');
      debugPrint('=== CONFIRM PAYMENT WITH BACKEND SUCCESS ===');

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final l10n = AppLocalizations.of(dialogContext)!;
            return AlertDialog(
              icon: const Icon(Icons.check_circle,
                  color: AppColors.success, size: 64),
              title: Text(l10n.paymentSuccessful),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.yourRegistrationHasBeenConfirmed),
                  const SizedBox(height: 8),
                  Text(
                    'Event: ${widget.eventTitle}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  child: Text(l10n.viewMyTicket),
                ),
              ],
            );
          },
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== CONFIRM PAYMENT ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.extractMessage(e,
              fallback: 'Failed to confirm payment')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.payment),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: _isLoading
          ? const LoadingState(message: 'Preparing your payment session...')
          : ListView(
              padding: AppSpacing.screenPadding,
              children: [
                _buildOrderSummaryCard(context, l10n),
                const SizedBox(height: AppSpacing.lg),
                _buildCouponCard(),
                const SizedBox(height: AppSpacing.lg),
                if (_errorMessage != null) ...[
                  _buildFeedbackCard(
                    icon: Icons.error_outline_rounded,
                    title: 'Payment setup failed',
                    message: _errorMessage!,
                    color: AppColors.error,
                    action: AppButton(
                      label: l10n.retry,
                      icon: Icons.refresh_rounded,
                      variant: AppButtonVariant.secondary,
                      expanded: true,
                      onPressed: _initiatePayment,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else ...[
                  _buildFeedbackCard(
                    icon: _isPaymentReady
                        ? Icons.check_circle_outline_rounded
                        : Icons.hourglass_top_rounded,
                    title: _isPaymentReady
                        ? 'Ready to pay'
                        : 'Preparing secure checkout',
                    message: _isPaymentReady
                        ? (kIsWeb ? l10n.paymentReadyWeb : l10n.paymentReady)
                        : l10n.processingPayment,
                    color:
                        _isPaymentReady ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (kIsWeb) ...[
                  _buildFeedbackCard(
                    icon: Icons.open_in_new_rounded,
                    title: 'External checkout',
                    message: l10n.paymentWillOpenInNewWindow,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l10n.securePaymentByStripe,
                            style: AppTypography.h4.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Card data stays inside Stripe. Your registration is preserved while checkout is being prepared.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  background: AppColors.primarySoft,
                  borderColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            l10n.testMode,
                            style: AppTypography.h4.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.useTestCard,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.testCardExpiry,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 140),
              ],
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total due',
                                  style: AppTypography.label.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  '\$${_effectiveAmount.toStringAsFixed(2)}',
                                  style: AppTypography.h2.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_appliedCoupon != null)
                            StatusChip(
                              label: _appliedCoupon!['code'] as String? ??
                                  'Coupon',
                              variant: StatusChipVariant.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label:
                            '${l10n.pay} \$${_effectiveAmount.toStringAsFixed(2)}',
                        icon: kIsWeb
                            ? Icons.open_in_new_rounded
                            : Icons.lock_open_rounded,
                        size: AppButtonSize.lg,
                        expanded: true,
                        onPressed: _isPaymentReady ? _processPayment : null,
                      ),
                      if (kIsWeb && _isPaymentReady) ...[
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: l10n.checkPaymentStatus,
                          icon: Icons.refresh_rounded,
                          variant: AppButtonVariant.secondary,
                          expanded: true,
                          onPressed: _checkPaymentStatus,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: l10n.cancel,
                        variant: AppButtonVariant.ghost,
                        expanded: true,
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildOrderSummaryCard(BuildContext context, AppLocalizations l10n) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.eventTitle,
            style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusChip(
                label: kIsWeb ? 'Web checkout' : 'Mobile sheet',
                variant: StatusChipVariant.info,
              ),
              if (widget.tierName != null)
                StatusChip(
                  label: widget.tierName!,
                  variant: StatusChipVariant.neutral,
                ),
              if (widget.quantity > 1)
                StatusChip(
                  label: '${widget.quantity} tickets',
                  variant: StatusChipVariant.primary,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (widget.tierName != null)
            _buildSummaryRow('Ticket', widget.tierName!),
          if (widget.tierName != null)
            _buildSummaryRow(
              'Unit price × Qty',
              '\$${(widget.unitPrice ?? widget.amount).toStringAsFixed(2)} × ${widget.quantity}',
            ),
          _buildSummaryRow(
            l10n.registrationFee,
            '\$${widget.amount.toStringAsFixed(2)}',
            muted: _appliedCoupon != null,
            strike: _appliedCoupon != null,
          ),
          if (_appliedCoupon != null)
            _buildSummaryRow(
              'Discount (${_appliedCoupon!['code']})',
              '-\$${_discountAmount.toStringAsFixed(2)}',
              valueColor: AppColors.success,
              labelColor: AppColors.success,
            ),
          const Divider(height: AppSpacing.xl),
          _buildSummaryRow(
            'Total',
            '\$${_effectiveAmount.toStringAsFixed(2)}',
            large: true,
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool large = false,
    bool muted = false,
    bool strike = false,
    Color? valueColor,
    Color? labelColor,
  }) {
    final labelStyle = (large ? AppTypography.h4 : AppTypography.body).copyWith(
      color: labelColor ?? AppColors.textSecondary,
      fontWeight: large ? FontWeight.w700 : FontWeight.w500,
    );
    final valueStyle =
        (large ? AppTypography.h2 : AppTypography.bodyLg).copyWith(
      color:
          valueColor ?? (muted ? AppColors.textMuted : AppColors.textPrimary),
      fontWeight: large ? FontWeight.w800 : FontWeight.w600,
      decoration: strike ? TextDecoration.lineThrough : null,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }

  Widget _buildCouponCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Coupon code',
            style: AppTypography.h4.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Apply a discount before checkout to reduce the amount due.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _couponController,
                  hint: 'Enter code',
                  enabled: _appliedCoupon == null,
                  onChanged: (value) {
                    _couponController.value = _couponController.value.copyWith(
                      text: value.toUpperCase(),
                      selection: TextSelection.collapsed(
                        offset: value.length,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 108,
                child: AppButton(
                  label: _appliedCoupon == null ? 'Apply' : 'Remove',
                  loading: _validatingCoupon,
                  variant: _appliedCoupon == null
                      ? AppButtonVariant.primary
                      : AppButtonVariant.secondary,
                  expanded: true,
                  onPressed: _validatingCoupon
                      ? null
                      : (_appliedCoupon == null ? _applyCoupon : _removeCoupon),
                ),
              ),
            ],
          ),
          _buildAvailableCouponsSection(),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    Widget? action,
  }) {
    return AppCard(
      background: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.h4
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action,
          ],
        ],
      ),
    );
  }
}

class _CouponSuggestionTile extends StatelessWidget {
  const _CouponSuggestionTile({
    required this.coupon,
    required this.onApply,
    required this.disabled,
  });

  final Coupon coupon;
  final VoidCallback onApply;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final discount = coupon.discountDisplay;
    final description = coupon.description?.trim().isNotEmpty == true
        ? coupon.description!.trim()
        : (coupon.discountType == 'PERCENTAGE'
            ? 'Save $discount on this order'
            : 'Save $discount off');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onApply,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        discount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'OFF',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        coupon.code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          letterSpacing: 0.6,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      if (coupon.minOrderAmount != null &&
                          coupon.minOrderAmount! > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Min order \$${coupon.minOrderAmount!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        coupon.formattedValidity,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textLight,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: disabled ? AppColors.neutral200 : AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    disabled ? 'Applied' : 'Apply',
                    style: TextStyle(
                      color: disabled ? AppColors.textMuted : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
