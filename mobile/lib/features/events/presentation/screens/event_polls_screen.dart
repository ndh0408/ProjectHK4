import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_components.dart';

class EventPollsScreen extends ConsumerStatefulWidget {
  const EventPollsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  ConsumerState<EventPollsScreen> createState() => _EventPollsScreenState();
}

class _EventPollsScreenState extends ConsumerState<EventPollsScreen> {
  List<Map<String, dynamic>> _polls = [];
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  final Map<String, List<String>> _selectedOptions = {};
  final Map<String, int> _selectedRatings = {};

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final polls = await api.getEventPolls(widget.eventId);
      if (!mounted) return;
      setState(() {
        _polls = polls;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '$error';
      });
    }
  }

  List<Map<String, dynamic>> get _pendingPolls {
    return _polls.where((poll) {
      final isActive = poll['active'] == true || poll['isActive'] == true;
      final hasVoted = poll['hasVoted'] == true;
      if (!isActive || hasVoted) return false;
      final pollId = poll['id'] as String;
      final type = poll['type'] as String? ?? 'SINGLE_CHOICE';
      if (type == 'RATING') {
        return (_selectedRatings[pollId] ?? 0) > 0;
      }
      final options = _selectedOptions[pollId];
      return options != null && options.isNotEmpty;
    }).toList();
  }

  Future<void> _submitAllPolls() async {
    final pending = _pendingPolls;
    if (pending.isEmpty) return;

    setState(() => _submitting = true);
    final api = ref.read(apiServiceProvider);
    int success = 0;
    int failed = 0;

    for (final poll in pending) {
      final pollId = poll['id'] as String;
      final type = poll['type'] as String? ?? 'SINGLE_CHOICE';
      try {
        if (type == 'RATING') {
          await api.votePoll(pollId, ratingValue: _selectedRatings[pollId]!);
        } else {
          await api.votePoll(pollId, optionIds: _selectedOptions[pollId]!);
        }
        success += 1;
      } catch (_) {
        failed += 1;
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success > 0) {
      _selectedOptions.clear();
      _selectedRatings.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failed > 0
                ? '$success poll${success > 1 ? 's' : ''} submitted, $failed failed'
                : 'Submitted $success poll${success > 1 ? 's' : ''} successfully',
          ),
          backgroundColor: failed > 0 ? AppColors.warning : AppColors.success,
        ),
      );
      await _loadPolls();
    } else if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit polls. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingPolls.length;
    final activeCount = _polls
        .where(
          (poll) => poll['active'] == true || poll['isActive'] == true,
        )
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Event Polls'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: _loadPolls,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
      body: _loading
          ? const LoadingState(message: 'Loading polls...')
          : _errorMessage != null
              ? ErrorState(message: _errorMessage!, onRetry: _loadPolls)
              : _polls.isEmpty
                  ? EmptyState(
                      icon: Icons.poll_outlined,
                      title: 'No polls available',
                      subtitle:
                          'Live polls and quick feedback requests will appear here during the event.',
                      actionLabel: 'Refresh',
                      onAction: _loadPolls,
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: _loadPolls,
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.pageX,
                          AppSpacing.xl,
                          AppSpacing.pageX,
                          pendingCount > 0
                              ? AppSpacing.massive + 88
                              : AppSpacing.massive,
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
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: AppRadius.allLg,
                                  ),
                                  child: const Icon(
                                    Icons.poll_rounded,
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
                                        widget.eventTitle,
                                        style: AppTypography.h3.copyWith(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        '$activeCount active poll${activeCount == 1 ? '' : 's'} • $pendingCount ready to submit',
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
                          ..._polls.map(_buildPollCard),
                        ],
                      ),
                    ),
      bottomSheet: _buildSubmitBar(pendingCount),
    );
  }

  Widget? _buildSubmitBar(int pendingCount) {
    if (_polls.isEmpty || pendingCount == 0) return null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageX,
          AppSpacing.md,
          AppSpacing.pageX,
          AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.divider),
          ),
          boxShadow: AppShadows.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$pendingCount poll${pendingCount > 1 ? 's' : ''} ready',
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Submit all queued answers in one action.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: _submitting ? 'Submitting...' : 'Submit All',
              icon: Icons.how_to_vote_rounded,
              loading: _submitting,
              onPressed: _submitting ? null : _submitAllPolls,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final isActive = poll['active'] == true || poll['isActive'] == true;
    final hasVoted = poll['hasVoted'] == true;
    final type = poll['type'] as String? ?? 'SINGLE_CHOICE';
    final totalVotes = poll['totalVotes'] as int? ?? 0;
    final options = (poll['options'] as List<dynamic>?) ?? [];
    final pollId = poll['id'] as String;
    final status = poll['status'] as String? ?? '';
    final hasSelection = type == 'RATING'
        ? (_selectedRatings[pollId] ?? 0) > 0
        : (_selectedOptions[pollId]?.isNotEmpty ?? false);

    final borderColor = hasVoted
        ? AppColors.success.withValues(alpha: 0.24)
        : hasSelection && isActive
            ? AppColors.primary.withValues(alpha: 0.24)
            : AppColors.border;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      borderColor: borderColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.ballot_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  poll['question']?.toString() ?? '',
                  style: AppTypography.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(
                label: isActive ? 'Active' : status,
                variant: isActive
                    ? StatusChipVariant.success
                    : StatusChipVariant.neutral,
                compact: true,
              ),
              StatusChip(
                label: '$totalVotes votes',
                variant: StatusChipVariant.primary,
                compact: true,
              ),
              if (hasSelection && isActive && !hasVoted)
                const StatusChip(
                  label: 'Ready',
                  variant: StatusChipVariant.info,
                  compact: true,
                ),
              if (hasVoted)
                const StatusChip(
                  label: 'Submitted',
                  variant: StatusChipVariant.success,
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (type == 'RATING')
            _buildRatingPoll(poll, pollId, hasVoted, isActive)
          else
            _buildChoicePoll(pollId, options, hasVoted, isActive, type),
        ],
      ),
    );
  }

  Widget _buildChoicePoll(
    String pollId,
    List<dynamic> options,
    bool hasVoted,
    bool isActive,
    String type,
  ) {
    final showResults = hasVoted || !isActive;

    return Column(
      children: options.map<Widget>((option) {
        final optionId = option['id'] as String;
        final text = option['text'] as String? ?? '';
        final voteCount = option['voteCount'] as int? ?? 0;
        final percentage = (option['percentage'] as num? ?? 0).toDouble();
        final isSelected =
            _selectedOptions[pollId]?.contains(optionId) ?? false;

        if (showResults) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$voteCount • ${percentage.toStringAsFixed(1)}%',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: AppRadius.allXs,
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: AppColors.neutral100,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InkWell(
            borderRadius: AppRadius.allMd,
            onTap: () {
              setState(() {
                if (type == 'MULTIPLE_CHOICE') {
                  final current =
                      List<String>.from(_selectedOptions[pollId] ?? []);
                  if (current.contains(optionId)) {
                    current.remove(optionId);
                  } else {
                    current.add(optionId);
                  }
                  _selectedOptions[pollId] = current;
                } else {
                  _selectedOptions[pollId] = [optionId];
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primarySoft
                    : AppColors.surfaceVariant,
                borderRadius: AppRadius.allMd,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    type == 'MULTIPLE_CHOICE'
                        ? (isSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded)
                        : (isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded),
                    color: isSelected ? AppColors.primary : AppColors.textLight,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRatingPoll(
    Map<String, dynamic> poll,
    String pollId,
    bool hasVoted,
    bool isActive,
  ) {
    final maxRating = poll['maxRating'] as int? ?? 5;
    final selected = _selectedRatings[pollId] ?? 0;

    if (hasVoted || !isActive) {
      final totalVotes = poll['totalVotes'] as int? ?? 0;
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              maxRating,
              (_) =>
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$totalVotes responses',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxRating, (index) {
        final value = index + 1;
        return IconButton(
          onPressed: () => setState(() => _selectedRatings[pollId] = value),
          icon: Icon(
            value <= selected ? Icons.star_rounded : Icons.star_border_rounded,
            color: value <= selected ? Colors.amber : AppColors.textLight,
            size: 34,
          ),
        );
      }),
    );
  }
}
