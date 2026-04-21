import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/coupon.dart';
import '../../../../shared/widgets/app_components.dart';

final userCouponsProvider =
    FutureProvider.autoDispose.family<List<Coupon>, String?>((
  ref,
  eventId,
) async {
  final api = ref.read(apiServiceProvider);
  return api.getUserCoupons(eventId: eventId);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.myCoupons),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              tooltip: l10n.refreshTooltip,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () => ref.refresh(userCouponsProvider(widget.eventId)),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: couponsAsync.when(
        data: (coupons) => _buildCouponsList(coupons, l10n),
        loading: () => const LoadingState(message: 'Loading your coupons...'),
        error: (error, _) => ErrorState(
          message: '$error',
          onRetry: () => ref.refresh(userCouponsProvider(widget.eventId)),
        ),
      ),
    );
  }

  Widget _buildCouponsList(List<Coupon> coupons, AppLocalizations l10n) {
    if (coupons.isEmpty) {
      return EmptyState(
        icon: Icons.local_offer_outlined,
        iconColor: AppColors.secondary,
        title: l10n.noCouponsAvailable,
        subtitle: l10n.checkBackLaterForOffers,
        actionLabel: l10n.refresh,
        onAction: () => ref.refresh(userCouponsProvider(widget.eventId)),
      );
    }

    final sortedCoupons = coupons.toList()
      ..sort((a, b) {
        if (a.isValid && !b.isValid) return -1;
        if (!a.isValid && b.isValid) return 1;
        if (a.validUntil != null && b.validUntil != null) {
          return a.validUntil!.compareTo(b.validUntil!);
        }
        return 0;
      });

    final activeCoupons =
        sortedCoupons.where((coupon) => coupon.isValid).length;
    final strongestCoupon = sortedCoupons.first;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => ref.refresh(userCouponsProvider(widget.eventId)),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageX,
          AppSpacing.xl,
          AppSpacing.pageX,
          AppSpacing.massive,
        ),
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.section),
            borderColor: AppColors.borderLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.secondary,
                          ],
                        ),
                        borderRadius: AppRadius.allLg,
                      ),
                      child: const Icon(
                        Icons.local_offer_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$activeCoupons ready to use',
                            style: AppTypography.h3.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Best visible offer: ${strongestCoupon.discountDisplay} off.',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'Available coupon codes',
            subtitle:
                'Copy codes quickly or apply them directly during checkout.',
          ),
          const SizedBox(height: AppSpacing.lg),
          ...sortedCoupons.map(
            (coupon) => _CouponCard(
              coupon: coupon,
              isCopied: _copiedCode == coupon.code,
              onCopy: () => _copyCode(coupon.code),
              onSelect: widget.onCouponSelected != null
                  ? () => widget.onCouponSelected!(coupon)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;

    setState(() => _copiedCode = code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon code copied: $code'),
        backgroundColor: AppColors.textPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copiedCode = null);
      }
    });
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.coupon,
    required this.onCopy,
    this.isCopied = false,
    this.onSelect,
  });

  final Coupon coupon;
  final bool isCopied;
  final VoidCallback onCopy;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final isExpired = !coupon.isValid;
    final expiringSoon = coupon.validUntil != null &&
        coupon.validUntil!.difference(DateTime.now()).inDays <= 2 &&
        !isExpired;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      borderColor: isExpired
          ? AppColors.border
          : expiringSoon
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.18),
      background: isExpired
          ? AppColors.neutral50
          : Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatusChip(
                    label: coupon.discountDisplay,
                    variant: StatusChipVariant.primary,
                  ),
                  StatusChip(
                    label: isExpired
                        ? 'Expired'
                        : expiringSoon
                            ? 'Expiring soon'
                            : 'Active',
                    variant: isExpired
                        ? StatusChipVariant.danger
                        : expiringSoon
                            ? StatusChipVariant.warning
                            : StatusChipVariant.success,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isExpired ? AppColors.neutral100 : AppColors.primarySoft,
              borderRadius: AppRadius.allMd,
              border: Border.all(
                color: isExpired
                    ? AppColors.border
                    : AppColors.primary.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.sell_outlined,
                  color: isExpired ? AppColors.textLight : AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    coupon.code,
                    style: AppTypography.h2.copyWith(
                      color: isExpired
                          ? AppColors.textLight
                          : AppColors.textPrimary,
                      letterSpacing: 1.1,
                      decoration: isExpired
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isCopied ? 'Copied' : 'Copy',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor:
                        isCopied ? AppColors.success : AppColors.primary,
                  ),
                  onPressed: isExpired ? null : onCopy,
                  icon: Icon(
                    isCopied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          if (coupon.description != null && coupon.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              coupon.description!,
              style: AppTypography.body.copyWith(
                color:
                    isExpired ? AppColors.textMuted : AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaPill(
                icon: Icons.schedule_rounded,
                label: coupon.formattedValidity,
                foreground:
                    isExpired ? AppColors.error : AppColors.textSecondary,
                background:
                    isExpired ? AppColors.errorLight : AppColors.surfaceVariant,
              ),
              if (coupon.minOrderAmount != null && coupon.minOrderAmount! > 0)
                _MetaPill(
                  icon: Icons.shopping_bag_outlined,
                  label:
                      'Min order \$${coupon.minOrderAmount!.toStringAsFixed(0)}',
                  foreground: AppColors.textSecondary,
                  background: AppColors.surfaceVariant,
                ),
              if (coupon.maxUsageCount != null && coupon.maxUsageCount! > 0)
                _MetaPill(
                  icon: Icons.people_alt_outlined,
                  label:
                      '${coupon.usedCount ?? 0}/${coupon.maxUsageCount} used',
                  foreground: AppColors.textSecondary,
                  background: AppColors.surfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: isCopied ? 'Copied' : 'Copy code',
                  variant: AppButtonVariant.secondary,
                  icon: isCopied ? Icons.check_rounded : Icons.copy_rounded,
                  expanded: true,
                  onPressed: isExpired ? null : onCopy,
                ),
              ),
              if (onSelect != null && !isExpired) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: 'Use coupon',
                    variant: AppButtonVariant.primary,
                    icon: Icons.arrow_forward_rounded,
                    expanded: true,
                    onPressed: onSelect,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
