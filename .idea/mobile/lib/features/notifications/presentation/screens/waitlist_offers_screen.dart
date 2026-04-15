import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';

class WaitlistOffersScreen extends ConsumerStatefulWidget {
  const WaitlistOffersScreen({super.key});

  @override
  ConsumerState<WaitlistOffersScreen> createState() =>
      _WaitlistOffersScreenState();
}

class _WaitlistOffersScreenState extends ConsumerState<WaitlistOffersScreen> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = true;
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
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final offers = await api.getWaitlistOffers();
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _updateCountdowns() {
    if (mounted) setState(() {});
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.acceptWaitlistOffer(offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer accepted! You are now registered.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOffers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept offer: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _declineOffer(String offerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline Offer'),
        content: const Text(
          'Are you sure? This will remove you from the waitlist for this event.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.declineWaitlistOffer(offerId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offer declined.')),
        );
        _loadOffers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waitlist Offers'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _offers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadOffers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _offers.length,
                    itemBuilder: (context, index) =>
                        _buildOfferCard(_offers[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_offer_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No pending offers',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When a spot opens up in an event you\'re\nwaitlisted for, you\'ll see the offer here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> offer) {
    final remaining = _getRemainingTime(offer['expiresAt'] ?? '');
    final isExpired = remaining == Duration.zero;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    Color timerColor;
    if (isExpired) {
      timerColor = Colors.red;
    } else if (minutes <= 5) {
      timerColor = Colors.red;
    } else if (minutes <= 15) {
      timerColor = Colors.orange;
    } else {
      timerColor = Colors.green;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isExpired ? Colors.grey[300]! : timerColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.celebration, color: timerColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    offer['eventTitle'] ?? 'Event',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: timerColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer, color: timerColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    isExpired
                        ? 'EXPIRED'
                        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} remaining',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: timerColor,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Text(
              isExpired
                  ? 'This offer has expired.'
                  : 'A spot opened up! Accept before time runs out.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),

            if (offer['priorityScore'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    'Priority Score: ${offer['priorityScore']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],

            if (!isExpired) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _declineOffer(offer['id']),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () => _acceptOffer(offer['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Accept Offer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
