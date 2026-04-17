import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/material.dart' as material show Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/coupon.dart';

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
        _availableCoupons = coupons
            .where((c) => c.isValid)
            .toList()
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
      final result = await api.validateCoupon(code, widget.amount, widget.registrationId);
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
            SnackBar(content: Text(result['message'] ?? 'Invalid coupon'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      setState(() => _validatingCoupon = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to validate: $e'), backgroundColor: Colors.red),
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
        final couponCode = _appliedCoupon != null ? _appliedCoupon!['code'] as String? : null;
        final result = await api.createCheckoutSession(widget.registrationId, couponCode: couponCode);
        debugPrint('API Response: $result');

        setState(() {
          _checkoutUrl = result['checkoutUrl'];
          debugPrint('Checkout URL received: ${_checkoutUrl != null ? 'YES' : 'NULL'}');
          _isLoading = false;
          _isPaymentReady = _checkoutUrl != null;
        });
      } else {
        debugPrint('Calling API initiatePayment for mobile...');
        final couponCode = _appliedCoupon != null ? _appliedCoupon!['code'] as String? : null;
        final result = await api.initiatePayment(widget.registrationId, couponCode: couponCode);
        debugPrint('API Response: $result');

        setState(() {
          _clientSecret = result['clientSecret'];
          debugPrint('Client Secret received: ${_clientSecret != null ? '${_clientSecret!.substring(0, 20)}...' : 'NULL'}');
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
        _errorMessage = ErrorUtils.extractMessage(e, fallback: 'Failed to initiate payment');
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
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight),
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
          content: Text(ErrorUtils.extractMessage(e, fallback: 'Failed to open payment')),
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
                icon: const Icon(Icons.check_circle, color: AppColors.success, size: 64),
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
          content: Text(ErrorUtils.extractMessage(e, fallback: 'Failed to check payment status')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _processMobilePayment() async {
    debugPrint('Processing mobile payment with Payment Sheet...');
    debugPrint('Client Secret: ${_clientSecret != null ? '${_clientSecret!.substring(0, 20)}...' : 'NULL'}');

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
        final errorMsg = e.error.localizedMessage ?? e.error.message ?? 'Payment failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
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
          content: Text(ErrorUtils.extractMessage(e, fallback: 'Payment failed')),
          backgroundColor: AppColors.error,
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
              icon: const Icon(Icons.check_circle, color: AppColors.success, size: 64),
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
          content: Text(ErrorUtils.extractMessage(e, fallback: 'Failed to confirm payment')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.payment),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)!.processingPayment),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  material.Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.eventTitle,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          if (widget.tierName != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Ticket', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                Text(widget.tierName!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Unit price × Qty', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                Text(
                                  '\$${(widget.unitPrice ?? widget.amount).toStringAsFixed(2)} × ${widget.quantity}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.registrationFee,
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                '\$${widget.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  decoration: _appliedCoupon != null
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: _appliedCoupon != null ? Colors.grey : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          if (_appliedCoupon != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Discount (${_appliedCoupon!['code']})',
                                  style: const TextStyle(fontSize: 14, color: Colors.green),
                                ),
                                Text(
                                  '-\$${(_appliedCoupon!['discountAmount'] as num? ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14, color: Colors.green),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(
                                  '\$${(_appliedCoupon!['finalAmount'] as num? ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  material.Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Have a coupon code?', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _couponController,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter code',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                  enabled: _appliedCoupon == null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _validatingCoupon
                                    ? null
                                    : (_appliedCoupon == null ? _applyCoupon : _removeCoupon),
                                child: _validatingCoupon
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Text(_appliedCoupon == null ? 'Apply' : 'Remove'),
                              ),
                            ],
                          ),
                          _buildAvailableCouponsSection(),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _initiatePayment,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ] else if (_isPaymentReady) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              kIsWeb
                                  ? AppLocalizations.of(context)!.paymentReadyWeb
                                  : AppLocalizations.of(context)!.paymentReady,
                              style: const TextStyle(color: AppColors.success),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (kIsWeb) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.open_in_new, size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.paymentWillOpenInNewWindow,
                              style: const TextStyle(fontSize: 13, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.securePaymentByStripe,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isPaymentReady ? _processPayment : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (kIsWeb) ...[
                          const Icon(Icons.open_in_new, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${AppLocalizations.of(context)!.pay} \$${widget.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (kIsWeb && _isPaymentReady) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _checkPaymentStatus,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context)!.checkPaymentStatus),
                    ),
                  ],

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.testMode,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.useTestCard,
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          AppLocalizations.of(context)!.testCardExpiry,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
