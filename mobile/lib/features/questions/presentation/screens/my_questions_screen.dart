import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/question.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../auth/providers/auth_provider.dart';

final myQuestionsProvider =
    FutureProvider.autoDispose<List<Question>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final api = ref.watch(apiServiceProvider);
  final response = await api.getMyQuestions();
  return response.content;
});

class MyQuestionsScreen extends ConsumerWidget {
  const MyQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final questionsAsync = ref.watch(myQuestionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.myQuestions),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              tooltip: l10n.refreshTooltip,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () => ref.invalidate(myQuestionsProvider),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: questionsAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return EmptyState(
              icon: Icons.question_answer_outlined,
              title: l10n.noQuestions,
              subtitle: l10n.noQuestionsSubtitle,
              actionLabel: l10n.explore,
              onAction: () => context.go('/explore'),
            );
          }

          final answeredCount =
              questions.where((question) => question.isAnswered).length;
          final pendingCount = questions.length - answeredCount;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(myQuestionsProvider),
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
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.info,
                            ],
                          ),
                          borderRadius: AppRadius.allLg,
                        ),
                        child: const Icon(
                          Icons.forum_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$answeredCount answered, $pendingCount pending',
                              style: AppTypography.h3.copyWith(
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Track organiser replies without hunting through each event page.',
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
                  title: 'Recent questions',
                  subtitle:
                      'Questions with answers are surfaced first so follow-ups are easier to review.',
                ),
                const SizedBox(height: AppSpacing.lg),
                ...questions
                    .map((question) => _QuestionCard(question: question)),
              ],
            ),
          );
        },
        loading: () => const LoadingState(message: 'Loading your questions...'),
        error: (error, _) => ErrorState(
          message: ErrorUtils.extractMessage(error),
          onRetry: () => ref.invalidate(myQuestionsProvider),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final l10n = AppLocalizations.of(context)!;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      onTap: () => context.push('/event/${question.eventId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question.eventTitle ?? 'Event',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h4.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tap to open the event and continue the conversation.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              StatusChip(
                label: question.isAnswered ? l10n.answered : l10n.pending,
                variant: question.isAnswered
                    ? StatusChipVariant.success
                    : StatusChipVariant.warning,
                icon: question.isAnswered
                    ? Icons.mark_email_read_rounded
                    : Icons.schedule_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.allMd,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadius.allMd,
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    question.question,
                    style: AppTypography.bodyLg.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (question.isAnswered && question.answer != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: AppRadius.allMd,
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        l10n.answer,
                        style: AppTypography.label.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    question.answer!,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _QuestionMetaPill(
                icon: Icons.schedule_rounded,
                label: 'Asked ${dateFormat.format(question.createdAt)}',
              ),
              if (question.answeredAt != null)
                _QuestionMetaPill(
                  icon: Icons.reply_rounded,
                  label: 'Answered ${dateFormat.format(question.answeredAt!)}',
                  foreground: AppColors.success,
                  background: AppColors.successLight,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionMetaPill extends StatelessWidget {
  const _QuestionMetaPill({
    required this.icon,
    required this.label,
    this.foreground = AppColors.textSecondary,
    this.background = AppColors.surfaceVariant,
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
