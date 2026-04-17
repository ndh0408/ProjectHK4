import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';

class EventPollsScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventPollsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  ConsumerState<EventPollsScreen> createState() => _EventPollsScreenState();
}

class _EventPollsScreenState extends ConsumerState<EventPollsScreen> {
  List<Map<String, dynamic>> _polls = [];
  bool _loading = true;
  bool _submitting = false;
  final Map<String, List<String>> _selectedOptions = {};
  final Map<String, int> _selectedRatings = {};

  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final polls = await api.getEventPolls(widget.eventId);
      setState(() {
        _polls = polls;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  // Returns polls the user has filled in but not yet submitted.
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
      final opts = _selectedOptions[pollId];
      return opts != null && opts.isNotEmpty;
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Polls — ${widget.eventTitle}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _polls.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPolls,
                  child: ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      pendingCount > 0 ? 120 : AppSpacing.lg,
                    ),
                    itemCount: _polls.length,
                    itemBuilder: (context, index) => _buildPollCard(_polls[index]),
                  ),
                ),
      bottomSheet: _buildSubmitBar(pendingCount),
    );
  }

  Widget? _buildSubmitBar(int pendingCount) {
    // Only show the bar when at least one vote is queued up, so it does not
    // obscure content when the user hasn't interacted yet.
    if (_polls.isEmpty || pendingCount == 0) return null;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
          boxShadow: AppShadows.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pendingCount poll${pendingCount > 1 ? 's' : ''} ready',
                    style: AppTypography.h4.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap submit to send all your answers',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submitAllPolls,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.how_to_vote, size: 18),
              label: Text(_submitting ? 'Submitting...' : 'Submit All'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
                minimumSize: const Size(0, 48),
                textStyle: AppTypography.button,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.poll_outlined, size: 64, color: AppColors.textLight),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'No polls available',
            style: AppTypography.h3.copyWith(color: AppColors.textMuted),
          ),
        ],
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

    // Has the user queued up an answer for this specific poll?
    final hasSelection = type == 'RATING'
        ? (_selectedRatings[pollId] ?? 0) > 0
        : (_selectedOptions[pollId]?.isNotEmpty ?? false);

    final Color stateColor = hasVoted
        ? AppColors.success
        : (hasSelection && isActive ? AppColors.primary : AppColors.divider);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        border: Border.all(
          color: stateColor,
          width: hasVoted || (hasSelection && isActive) ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.poll,
                  color: isActive ? AppColors.success : AppColors.textLight,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    poll['question'] ?? '',
                    style: AppTypography.h4.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _PollBadge(
                  label: isActive ? 'Active' : status,
                  color: isActive ? AppColors.success : AppColors.textMuted,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.how_to_vote,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '$totalVotes votes',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                if (hasSelection && isActive && !hasVoted)
                  _PollBadge(
                    label: 'Ready',
                    color: AppColors.primary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (type == 'RATING')
              _buildRatingPoll(poll, pollId, hasVoted, isActive)
            else
              _buildChoicePoll(poll, pollId, options, hasVoted, isActive, type),
            if (hasVoted)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'You have voted',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoicePoll(
    Map<String, dynamic> poll,
    String pollId,
    List<dynamic> options,
    bool hasVoted,
    bool isActive,
    String type,
  ) {
    final showResults = hasVoted || !isActive;

    return Column(
      children: options.map<Widget>((opt) {
        final optionId = opt['id'] as String;
        final text = opt['text'] as String? ?? '';
        final voteCount = opt['voteCount'] as int? ?? 0;
        final percentage = (opt['percentage'] as num? ?? 0).toDouble();
        final isSelected =
            _selectedOptions[pollId]?.contains(optionId) ?? false;

        if (showResults) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '$voteCount (${percentage.toStringAsFixed(1)}%)',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
          child: InkWell(
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
            borderRadius: AppRadius.allMd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
                borderRadius: AppRadius.allMd,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    type == 'MULTIPLE_CHOICE'
                        ? (isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank)
                        : (isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textMuted,
                    size: 22,
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
            children: List.generate(maxRating, (_) {
              return const Icon(Icons.star, color: Colors.amber, size: 28);
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$totalVotes responses',
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxRating, (index) {
        final value = index + 1;
        return IconButton(
          onPressed: () =>
              setState(() => _selectedRatings[pollId] = value),
          icon: Icon(
            value <= selected ? Icons.star : Icons.star_border,
            color: value <= selected ? Colors.amber : AppColors.textLight,
            size: 36,
          ),
        );
      }),
    );
  }
}

class _PollBadge extends StatelessWidget {
  const _PollBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.allPill,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
