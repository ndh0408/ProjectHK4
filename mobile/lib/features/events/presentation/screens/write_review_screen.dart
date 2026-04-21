import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_components.dart';

class WriteReviewScreen extends ConsumerStatefulWidget {
  const WriteReviewScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  ConsumerState<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends ConsumerState<WriteReviewScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final l10n = AppLocalizations.of(context)!;

    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseSelectRating),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.createReview(
        widget.eventId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.reviewSubmitted),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.extractMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.writeReview),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.section),
            borderColor: AppColors.borderLight,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadius.allLg,
                  ),
                  child: const Icon(Icons.rate_review_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eventTitle,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Reviews help future attendees trust the event and decide faster.',
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
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.section),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.rating,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _getRatingLabel(l10n),
                  style: AppTypography.body.copyWith(
                    color: _rating == 0
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    fontWeight:
                        _rating == 0 ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _RatingStars(
                  rating: _rating,
                  onRatingChanged: (value) => setState(() => _rating = value),
                ),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.comment,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _commentController,
                  hint: l10n.writeYourReview,
                  maxLines: 7,
                  maxLength: 1000,
                  helper:
                      'Mention the venue, agenda quality, check-in flow or anything future attendees should know.',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.md,
            AppSpacing.pageX,
            AppSpacing.md,
          ),
          child: AppButton(
            label: l10n.submitReview,
            icon: Icons.publish_rounded,
            expanded: true,
            loading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submitReview,
          ),
        ),
      ),
    );
  }

  String _getRatingLabel(AppLocalizations l10n) {
    switch (_rating) {
      case 1:
        return l10n.ratingPoor;
      case 2:
        return l10n.ratingFair;
      case 3:
        return l10n.ratingGood;
      case 4:
        return l10n.ratingVeryGood;
      case 5:
        return l10n.ratingExcellent;
      default:
        return l10n.tapToRate;
    }
  }
}

class _RatingStars extends StatelessWidget {
  const _RatingStars({
    required this.rating,
    required this.onRatingChanged,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final selected = starIndex <= rating;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Material(
            color: selected ? AppColors.warningLight : AppColors.surfaceVariant,
            borderRadius: AppRadius.allPill,
            child: InkWell(
              borderRadius: AppRadius.allPill,
              onTap: () => onRatingChanged(starIndex),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: Icon(
                  selected ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 30,
                  color: selected ? AppColors.warning : AppColors.textLight,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
