import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/coupon.dart';

final userCouponsProvider = FutureProvider.autoDispose.family<List<Coupon>, String?>((ref, eventId) async {
  final api = ref.read(apiServiceProvider);
  return await api.getUserCoupons(eventId: eventId);
});

class MyCouponsScreen extends ConsumerStatefulWidget {
  const MyCouponsScreen({
    super.key,
    this.eventId,
    this.onCouponSelected,
  });

  final String? eventId;
  final Function(Coupon)? onCouponSelected;

  @override
  ConsumerState<MyCouponsScreen> createState() => _MyCouponsScreenState();
}

class _MyCouponsScreenState extends ConsumerState<MyCouponsScreen> {
  String? _copiedCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final couponsAsync = ref.watch(userCouponsProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myCoupons),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(userCouponsProvider(widget.eventId)),
          ),
        ],
      ),
      body: couponsAsync.when(
        data: (coupons) => _buildCouponsList(coupons, l10n),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorWidget(error, l10n),
      ),
    );
  }

  Widget _buildCouponsList(List<Coupon> coupons, AppLocalizations l10n) {
    if (coupons.isEmpty) {
      return _buildEmptyState(l10n);
    }

    // Sort: valid first, then by expiry date
    final sortedCoupons = coupons.toList()
      ..sort((a, b) {
        if (a.isValid && !b.isValid) return -1;
        if (!a.isValid && b.isValid) return 1;
        if (a.validUntil != null && b.validUntil != null) {
          return a.validUntil!.compareTo(b.validUntil!);
        }
        return 0;
      });

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(userCouponsProvider(widget.eventId)),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sortedCoupons.length,
        itemBuilder: (context, index) {
          final coupon = sortedCoupons[index];
          return _CouponCard(
            coupon: coupon,
            isCopied: _copiedCode == coupon.code,
            onCopy: () => _copyCode(coupon.code),
            onSelect: widget.onCouponSelected != null
                ? () => widget.onCouponSelected!(coupon)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 80,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCouponsAvailable,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.checkBackLaterForOffers,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(userCouponsProvider(widget.eventId)),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(Object error, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.failedToLoadCoupons,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.refresh(userCouponsProvider(widget.eventId)),
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code)).then((_) {
      setState(() => _copiedCode = code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Coupon code copied: $code'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _copiedCode = null);
        }
      });
    });
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    this.isCopied = false,
    required this.onCopy,
    this.onSelect,
  });

  final Coupon coupon;
  final bool isCopied;
  final VoidCallback onCopy;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final isExpired = !coupon.isValid;

    return Card(
      elevation: isExpired ? 0 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpired ? AppColors.divider : AppColors.primary.withValues(alpha: 0.3),
          width: isExpired ? 1 : 2,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isExpired
                          ? AppColors.textLight
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      coupon.discountDisplay,
                      style: TextStyle(
                        color: isExpired ? AppColors.textSecondary : AppColors.textOnPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isExpired)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EXPIRED',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isExpired ? AppColors.divider : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        coupon.code,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isExpired ? AppColors.textLight : AppColors.textPrimary,
                          letterSpacing: 1,
                          decoration: isExpired ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: isExpired ? null : onCopy,
                      icon: Icon(
                        isCopied ? Icons.check : Icons.copy,
                        size: 20,
                        color: isCopied
                            ? AppColors.success
                            : (isExpired ? AppColors.textLight : AppColors.primary),
                      ),
                      tooltip: isCopied ? 'Copied!' : 'Copy code',
                    ),
                  ],
                ),
              ),
              if (coupon.description != null && coupon.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  coupon.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: isExpired ? AppColors.textLight : AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: isExpired ? AppColors.error : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      coupon.formattedValidity,
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpired ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (coupon.minOrderAmount != null && coupon.minOrderAmount! > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 14,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Min order: \$${coupon.minOrderAmount!.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
              if (onSelect != null && !isExpired) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSelect,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Use this coupon'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
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
