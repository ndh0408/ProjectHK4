import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _vote(Map<String, dynamic> poll) async {
    final pollId = poll['id'] as String;
    final type = poll['type'] as String;

    try {
      final api = ref.read(apiServiceProvider);

      if (type == 'RATING') {
        final rating = _selectedRatings[pollId];
        if (rating == null) {
          _showError('Please select a rating');
          return;
        }
        await api.votePoll(pollId, ratingValue: rating);
      } else {
        final options = _selectedOptions[pollId];
        if (options == null || options.isEmpty) {
          _showError('Please select an option');
          return;
        }
        await api.votePoll(pollId, optionIds: options);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vote recorded!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPolls();
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Polls - ${widget.eventTitle}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _polls.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPolls,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _polls.length,
                    itemBuilder: (context, index) => _buildPollCard(_polls[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.poll_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No polls available', style: TextStyle(fontSize: 18, color: Colors.grey)),
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

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? Colors.green.withValues(alpha: 0.5) : Colors.grey[300]!,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.poll,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    poll['question'] ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(isActive ? 'ACTIVE' : status),
                  backgroundColor: isActive ? Colors.green[50] : Colors.grey[100],
                  labelStyle: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontSize: 11,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Icon(Icons.how_to_vote, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '$totalVotes votes',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (type == 'RATING')
              _buildRatingPoll(poll, pollId, hasVoted, isActive)
            else
              _buildChoicePoll(poll, pollId, options, hasVoted, isActive, type, totalVotes),

            if (isActive && !hasVoted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _vote(poll),
                  icon: const Icon(Icons.how_to_vote),
                  label: const Text('Submit Vote'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],

            if (hasVoted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      'You have voted',
                      style: TextStyle(fontSize: 12, color: Colors.green[600], fontWeight: FontWeight.w500),
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
    int totalVotes,
  ) {
    final showResults = hasVoted || !isActive;

    return Column(
      children: options.map<Widget>((opt) {
        final optionId = opt['id'] as String;
        final text = opt['text'] as String? ?? '';
        final voteCount = opt['voteCount'] as int? ?? 0;
        final percentage = opt['percentage'] as num? ?? 0;
        final isSelected = _selectedOptions[pollId]?.contains(optionId) ?? false;

        if (showResults) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(text, style: const TextStyle(fontSize: 14)),
                    Text(
                      '$voteCount (${percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 8,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: () {
              setState(() {
                if (type == 'MULTIPLE_CHOICE') {
                  final current = _selectedOptions[pollId] ?? [];
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
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.blue : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(10),
                color: isSelected ? Colors.blue.withValues(alpha: 0.05) : null,
              ),
              child: Row(
                children: [
                  Icon(
                    type == 'MULTIPLE_CHOICE'
                        ? (isSelected ? Icons.check_box : Icons.check_box_outline_blank)
                        : (isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    color: isSelected ? Colors.blue : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(text, style: const TextStyle(fontSize: 14)),
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
            children: List.generate(maxRating, (index) {
              return Icon(
                Icons.star,
                color: Colors.amber,
                size: 28,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '$totalVotes responses',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
            value <= selected ? Icons.star : Icons.star_border,
            color: value <= selected ? Colors.amber : Colors.grey,
            size: 36,
          ),
        );
      }),
    );
  }
}
