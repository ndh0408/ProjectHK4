import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/chat_message.dart';

typedef PollVoted = void Function(PollSnapshot updated);

/// Inline poll card rendered inside an event group chat bubble.
/// Lets attendees vote directly without leaving the conversation.
class PollMessageCard extends ConsumerStatefulWidget {
  const PollMessageCard({
    super.key,
    required this.poll,
    required this.onVoted,
  });

  final PollSnapshot poll;
  final PollVoted onVoted;

  @override
  ConsumerState<PollMessageCard> createState() => _PollMessageCardState();
}

class _PollMessageCardState extends ConsumerState<PollMessageCard> {
  final Set<String> _selectedOptions = {};
  int _selectedRating = 0;
  bool _submitting = false;

  bool get _isRating => widget.poll.type == 'RATING';
  bool get _isMultiple => widget.poll.type == 'MULTIPLE_CHOICE';
  bool get _isActive => widget.poll.isActive && widget.poll.status == 'ACTIVE';
  bool get _showResults {
    if (widget.poll.resultsHidden) return false;
    return widget.poll.hasVoted || !_isActive;
  }

  bool get _hasSelection =>
      _isRating ? _selectedRating > 0 : _selectedOptions.isNotEmpty;

  Future<void> _submitVote() async {
    if (_submitting || !_hasSelection) return;
    setState(() => _submitting = true);

    final api = ref.read(apiServiceProvider);
    try {
      if (_isRating) {
        await api.votePoll(widget.poll.id, ratingValue: _selectedRating);
      } else {
        await api.votePoll(widget.poll.id,
            optionIds: _selectedOptions.toList());
      }
      // Optimistic: mark as voted. The poll WS broadcast will refresh the
      // vote counts shortly.
      widget.onVoted(widget.poll.copyWith(hasVoted: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote submitted'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit vote'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.allLg,
        border: Border.all(
          color: _isActive ? AppColors.primary.withValues(alpha: 0.35) : AppColors.divider,
          width: 1,
        ),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(poll),
          const SizedBox(height: AppSpacing.sm),
          _buildBadges(poll),
          const SizedBox(height: AppSpacing.md),
          if (_isRating)
            _buildRatingBody(poll)
          else
            _buildChoiceBody(poll),
          if (_isActive && !poll.hasVoted) ...[
            const SizedBox(height: AppSpacing.md),
            _buildVoteButton(),
          ],
          if (poll.hasVoted) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildVotedHint(),
          ],
          if (poll.resultsHidden && !poll.hasVoted) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildHiddenResultsHint(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(PollSnapshot poll) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: AppRadius.allSm,
          ),
          child: Icon(Icons.bar_chart_rounded,
              size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            poll.question,
            style: AppTypography.h4.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadges(PollSnapshot poll) {
    final Color badgeColor = _isActive
        ? AppColors.success
        : (poll.status == 'CLOSED' ? AppColors.textMuted : AppColors.warning);
    final String label = _isActive
        ? 'ACTIVE'
        : (poll.status == 'CLOSED' ? 'CLOSED' : poll.status);

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PollBadge(label: label, color: badgeColor),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_vote, size: 13, color: AppColors.textMuted),
            const SizedBox(width: 3),
            Text(
              '${poll.totalVotes} votes',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        if (_isMultiple)
          _PollBadge(label: 'MULTI', color: AppColors.primary),
      ],
    );
  }

  Widget _buildChoiceBody(PollSnapshot poll) {
    final options = [...poll.options]
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    // Voted + organiser chose to hide results until close: render the
    // options as read-only placeholders so the user can't re-pick. The
    // backend doesn't tell us which option the viewer picked, so all rows
    // look uniformly locked.
    if (poll.hasVoted && poll.resultsHidden) {
      return Column(children: options.map(_buildLockedOption).toList());
    }

    return Column(
      children: options
          .map((opt) => _showResults
              ? _buildResultOption(opt, poll.totalVotes)
              : _buildVotableOption(opt))
          .toList(),
    );
  }

  Widget _buildLockedOption(PollSnapshotOption option) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.allMd,
          color: AppColors.surface,
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                option.text,
                style: AppTypography.body.copyWith(
                  fontSize: 13.5,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotableOption(PollSnapshotOption option) {
    final isSelected = _selectedOptions.contains(option.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: AppRadius.allMd,
        onTap: _submitting
            ? null
            : () {
                setState(() {
                  if (_isMultiple) {
                    if (isSelected) {
                      _selectedOptions.remove(option.id);
                    } else {
                      _selectedOptions.add(option.id);
                    }
                  } else {
                    _selectedOptions
                      ..clear()
                      ..add(option.id);
                  }
                });
              },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: AppRadius.allMd,
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.06)
                : null,
          ),
          child: Row(
            children: [
              Icon(
                _isMultiple
                    ? (isSelected
                        ? Icons.check_box
                        : Icons.check_box_outline_blank)
                    : (isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                size: 18,
                color:
                    isSelected ? AppColors.primary : AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  option.text,
                  style: AppTypography.body.copyWith(
                    fontSize: 13.5,
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
  }

  Widget _buildResultOption(PollSnapshotOption option, int totalVotes) {
    final pct = totalVotes > 0 ? option.percentage : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.text,
                  style: AppTypography.body.copyWith(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${option.voteCount} (${pct.toStringAsFixed(0)}%)',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: AppRadius.allXs,
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 6,
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

  Widget _buildRatingBody(PollSnapshot poll) {
    final max = poll.maxRating ?? 5;
    if (_showResults) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(max, (_) {
              return const Icon(Icons.star, color: Colors.amber, size: 22);
            }),
          ),
          const SizedBox(height: 4),
          Text(
            '${poll.totalVotes} responses',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(max, (i) {
        final value = i + 1;
        return IconButton(
          onPressed: _submitting
              ? null
              : () => setState(() => _selectedRating = value),
          icon: Icon(
            value <= _selectedRating ? Icons.star : Icons.star_border,
            color: value <= _selectedRating
                ? Colors.amber
                : AppColors.textLight,
            size: 28,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(),
        );
      }),
    );
  }

  Widget _buildVoteButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_hasSelection && !_submitting) ? _submitVote : null,
        icon: _submitting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.how_to_vote, size: 16),
        label: Text(_submitting ? 'Submitting...' : 'Submit vote'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10),
          textStyle: AppTypography.button.copyWith(fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildVotedHint() {
    return Row(
      children: [
        Icon(Icons.check_circle, size: 14, color: AppColors.success),
        const SizedBox(width: 4),
        Text(
          'You voted',
          style: AppTypography.caption.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildHiddenResultsHint() {
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 13, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'Results hidden until poll closes',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
          fontSize: 9.5,
        ),
      ),
    );
  }
}
