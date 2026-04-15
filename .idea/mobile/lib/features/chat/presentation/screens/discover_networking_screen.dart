import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/api_service.dart';

class DiscoverNetworkingScreen extends ConsumerStatefulWidget {
  const DiscoverNetworkingScreen({super.key});

  @override
  ConsumerState<DiscoverNetworkingScreen> createState() =>
      _DiscoverNetworkingScreenState();
}

class _DiscoverNetworkingScreenState
    extends ConsumerState<DiscoverNetworkingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final profiles = await api.discoverNetworking();
      final pendingData = await api.getPendingConnectionRequests();
      final pendingList = (pendingData['content'] as List<dynamic>?) ?? [];
      setState(() {
        _profiles = profiles;
        _pendingRequests = pendingList.cast<Map<String, dynamic>>();
        _currentIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _connect(Map<String, dynamic> profile) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.sendConnectionRequest(profile['userId']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request sent to ${profile['fullName']}!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          if (_currentIndex < _profiles.length - 1) {
            _currentIndex++;
          } else {
            _profiles.removeAt(_currentIndex);
            if (_currentIndex >= _profiles.length && _profiles.isNotEmpty) {
              _currentIndex = _profiles.length - 1;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _skip() async {
    setState(() {
      if (_currentIndex < _profiles.length - 1) {
        _currentIndex++;
      }
    });
  }

  Future<void> _acceptRequest(String requestId) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.acceptConnectionRequest(requestId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection accepted!'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _declineRequest(String requestId) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.declineConnectionRequest(requestId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Networking'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(text: 'Discover'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDiscoverTab(),
                _buildRequestsTab(),
              ],
            ),
    );
  }

  Widget _buildDiscoverTab() {
    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No matches yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Register for events to discover\npeople with similar interests!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    if (_currentIndex >= _profiles.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text(
              'You\'ve seen all matches!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new connections.',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _loadData,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }
    final profile = _profiles[_currentIndex];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            '${_currentIndex + 1} / ${_profiles.length}',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildProfileCard(profile),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'skip',
                onPressed: _skip,
                backgroundColor: Colors.grey[200],
                child: const Icon(Icons.close, color: Colors.grey, size: 30),
              ),
              FloatingActionButton.large(
                heroTag: 'connect',
                onPressed: profile['connectionStatus'] == 'NONE'
                    ? () => _connect(profile)
                    : null,
                backgroundColor: profile['connectionStatus'] == 'NONE'
                    ? Colors.blue
                    : Colors.grey,
                child: const Icon(Icons.person_add, color: Colors.white, size: 36),
              ),
              FloatingActionButton(
                heroTag: 'chat',
                onPressed: profile['connectionStatus'] == 'CONNECTED'
                    ? () {}
                    : null,
                backgroundColor: profile['connectionStatus'] == 'CONNECTED'
                    ? Colors.green
                    : Colors.grey[200],
                child: Icon(
                  Icons.chat,
                  color: profile['connectionStatus'] == 'CONNECTED'
                      ? Colors.white
                      : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    final interests = (profile['interests'] as List<dynamic>?) ?? [];
    final score = (profile['compatibilityScore'] as num?)?.toDouble() ?? 0;
    final status = profile['connectionStatus'] as String? ?? 'NONE';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: profile['avatarUrl'] != null
                  ? NetworkImage(profile['avatarUrl'])
                  : null,
              child: profile['avatarUrl'] == null
                  ? Text(
                      (profile['fullName'] as String? ?? '?')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 36),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              profile['fullName'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (status != 'NONE')
              Chip(
                label: Text(
                  status == 'CONNECTED' ? 'Connected' :
                  status == 'PENDING_SENT' ? 'Request Sent' :
                  status == 'PENDING_RECEIVED' ? 'Wants to Connect' : status,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor: status == 'CONNECTED' ? Colors.green[50] :
                    status == 'PENDING_RECEIVED' ? Colors.blue[50] : Colors.orange[50],
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(Icons.event, '${profile['sharedEventsCount'] ?? 0} shared'),
                const SizedBox(width: 8),
                _buildStatChip(Icons.people, '${profile['connectionsCount'] ?? 0} connections'),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _scoreColor(score).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 18, color: _scoreColor(score)),
                  const SizedBox(width: 6),
                  Text(
                    '${score.toStringAsFixed(0)}% Match',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _scoreColor(score),
                    ),
                  ),
                ],
              ),
            ),
            if (profile['bio'] != null && (profile['bio'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                profile['bio'],
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
            if (interests.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: interests.take(6).map<Widget>((i) => Chip(
                  label: Text(i.toString(), style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.blue[50],
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No pending requests', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final req = _pendingRequests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: req['senderAvatarUrl'] != null
                  ? NetworkImage(req['senderAvatarUrl'])
                  : null,
              child: req['senderAvatarUrl'] == null
                  ? Text((req['senderName'] as String? ?? '?')[0])
                  : null,
            ),
            title: Text(req['senderName'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: req['message'] != null
                ? Text(req['message'], maxLines: 1, overflow: TextOverflow.ellipsis)
                : const Text('Wants to connect', style: TextStyle(fontStyle: FontStyle.italic)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _declineRequest(req['id']),
                ),
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => _acceptRequest(req['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
