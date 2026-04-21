import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_components.dart';

class WaitlistOffersScreen extends ConsumerStatefulWidget {
  const WaitlistOffersScreen({super.key});

  @override
  ConsumerState<WaitlistOffersScreen> createState() =>
      _WaitlistOffersScreenState();
}

class _WaitlistOffersScreenState extends ConsumerState<WaitlistOffersScreen> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
  String? _errorMessage;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadOffers();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdowns(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final offers = await api.getWaitlistOffers();
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _updateCountdowns() {
    if (mounted) setState(() {});
  }

  Future<void> _acceptOffer(String offerId) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final api = ref.read(apiServiceProvider);
      await api.acceptWaitlistOffer(offerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.offerAcceptedSnack),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadOffers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToAcceptOffer(error.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _declineOffer(String offerId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialog.confirm(
      context: context,
      title: l10n.declineOfferTitle,
      message:
          'This will remove your priority access for this event and pass the spot to the next person in line.',
      primaryLabel: l10n.decline,
      secondaryLabel: l10n.cancel,
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.declineWaitlistOffer(offerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.offerDeclinedSnack),
          backgroundColor: AppColors.textPrimary,
        ),
      );
      await _loadOffers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decline offer: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Duration _getRemainingTime(String? expiresAt) {
    if (expiresAt == null || expiresAt.isEmpty) return Duration.zero;
    try {
      final expiry = DateTime.parse(expiresAt);
      final diff = expiry.difference(DateTime.now());
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return Duration.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeOffers = _offers
        .where((offer) =>
            _getRemainingTime(offer['expiresAt'] as String?) > Duration.zero)
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.waitlistOffersTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              tooltip: l10n.refreshTooltip,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: _loadOffers,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: _loading
          ? const LoadingState(message: 'Checking your waitlist offers...')
          : _errorMessage != null
              ? ErrorState(
                  message: _errorMessage!,
                  onRetry: _loadOffers,
                )
              : _offers.isEmpty
                  ? EmptyState(
                      icon: Icons.hourglass_empty_rounded,
                      iconColor: AppColors.info,
                      title: 'No pending offers',
                      subtitle:
                          'When seats open up for events you joined from the waitlist, the claim window will appear here.',
                      actionLabel: l10n.refresh,
                      onAction: _loadOffers,
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadOffers,
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
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.section,
                            ),
                            borderColor: AppColors.borderLight,
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.warning,
                                        AppColors.secondary,
                                      ],
                                    ),
                                    borderRadius: AppRadius.allLg,
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$activeOffers offers need action',
                                        style: AppTypography.h3.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Accept quickly to secure the spot before the countdown expires.',
                                        style: AppTypography.body.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SectionHeader(
                            title: 'Seats waiting for confirmation',
                            subtitle:
                                'Each offer has a strict timer, so the primary CTA stays visible and thumb-friendly.',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ..._offers.map(_buildOfferCard),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final remaining = _getRemainingTime(offer['expiresAt'] as String?);
    final isExpired = remaining == Duration.zero;
    final totalMinutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    final eventTitle = (offer['eventTitle'] ?? 'Event').toString();
    final priorityScore = offer['priorityScore'];

    final statusVariant = isExpired
        ? StatusChipVariant.danger
        : totalMinutes <= 5
            ? StatusChipVariant.danger
            : totalMinutes <= 15
                ? StatusChipVariant.warning
                : StatusChipVariant.success;

    final countdownColor = switch (statusVariant) {
      StatusChipVariant.danger => AppColors.error,
      StatusChipVariant.warning => AppColors.warning,
      StatusChipVariant.success => AppColors.success,
      _ => AppColors.primary,
    };

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      borderColor: countdownColor.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: countdownColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.allLg,
                ),
                child: Icon(
                  Icons.confirmation_number_rounded,
                  color: countdownColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isExpired
                          ? 'This claim window has ended.'
                          : 'A spot opened up from the waitlist. Complete the action before time runs out.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: isExpired
                    ? 'Expired'
                    : totalMinutes <= 5
                        ? 'Urgent'
                        : 'Available',
                variant: statusVariant,
                icon: isExpired ? Icons.block_rounded : Icons.timer_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              color: countdownColor.withValues(alpha: 0.08),
              borderRadius: AppRadius.allLg,
            ),
            child: Row(
              children: [
                Icon(Icons.timer_rounded, color: countdownColor, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    isExpired
                        ? 'Offer expired'
                        : '${totalMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} remaining',
                    style: AppTypography.h2.copyWith(
                      color: countdownColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _OfferMetaPill(
                icon: Icons.priority_high_rounded,
                label: priorityScore != null
                    ? 'Priority score $priorityScore'
                    : 'Waitlist upgrade available',
                color: AppColors.textSecondary,
              ),
              _OfferMetaPill(
                icon: Icons.flash_on_rounded,
                label: isExpired ? 'No further action' : 'Claim ticket now',
                color: countdownColor,
                background: countdownColor.withValues(alpha: 0.1),
              ),
            ],
          ),
          if (!isExpired) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: AppLocalizations.of(context)!.decline,
                    variant: AppButtonVariant.secondary,
                    icon: Icons.close_rounded,
                    expanded: true,
                    onPressed: () => _declineOffer(offer['id'].toString()),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: AppLocalizations.of(context)!.accept,
                    variant: AppButtonVariant.primary,
                    icon: Icons.check_circle_outline_rounded,
                    expanded: true,
                    onPressed: () => _acceptOffer(offer['id'].toString()),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OfferMetaPill extends StatelessWidget {
  const _OfferMetaPill({
    required this.icon,
    required this.label,
    required this.color,
    this.background = AppColors.surfaceVariant,
  });

  final IconData icon;
  final String label;
  final Color color;
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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
