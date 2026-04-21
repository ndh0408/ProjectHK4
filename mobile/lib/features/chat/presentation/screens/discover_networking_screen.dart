import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_components.dart';

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
  String? _errorMessage;
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
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final profiles = await api.discoverNetworking();
      final pendingData = await api.getPendingConnectionRequests();
      final pendingList = (pendingData['content'] as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _pendingRequests = pendingList.cast<Map<String, dynamic>>();
        _currentIndex = 0;
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

  Future<void> _connect(Map<String, dynamic> profile) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.sendConnectionRequest(profile['userId']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request sent to ${profile['fullName']}'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() {
        if (_currentIndex < _profiles.length - 1) {
          _currentIndex++;
        } else if (_profiles.isNotEmpty) {
          _profiles.removeAt(_currentIndex);
          if (_currentIndex >= _profiles.length && _profiles.isNotEmpty) {
            _currentIndex = _profiles.length - 1;
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _skip() {
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection accepted'),
          backgroundColor: AppColors.success,
        ),
      );
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _declineRequest(String requestId) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.declineConnectionRequest(requestId);
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Networking'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.pageX),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Discover'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Requests'),
                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        borderRadius: AppRadius.allPill,
                      ),
                      child: Text(
                        '${_pendingRequests.length}',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                        ),
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
          ? const LoadingState(message: 'Loading networking matches...')
          : _errorMessage != null
              ? ErrorState(message: _errorMessage!, onRetry: _loadData)
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
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No matches yet',
        subtitle:
            'Join more events to unlock attendee suggestions with similar interests and schedules.',
        actionLabel: 'Explore Events',
        onAction: () => context.go('/explore'),
      );
    }

    if (_currentIndex >= _profiles.length) {
      return EmptyState(
        icon: Icons.check_circle_outline_rounded,
        iconColor: AppColors.success,
        title: 'You have reviewed all matches',
        subtitle:
            'Refresh later for new networking suggestions based on fresh registrations.',
        actionLabel: 'Refresh',
        onAction: _loadData,
      );
    }

    final profile = _profiles[_currentIndex];
    final status = profile['connectionStatus'] as String? ?? 'NONE';
    final score = (profile['compatibilityScore'] as num?)?.toDouble() ?? 0;
    final interests = (profile['interests'] as List<dynamic>?) ?? [];

    return ListView(
      padding: AppSpacing.screenPadding,
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
                  gradient: AppColors.primaryGradient,
                  borderRadius: AppRadius.allLg,
                ),
                child: const Icon(Icons.hub_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_currentIndex + 1} of ${_profiles.length} suggested connections',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Swipe mentally through people one at a time so the primary action remains decisive.',
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
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.primarySoft,
                backgroundImage: profile['avatarUrl'] != null
                    ? NetworkImage(profile['avatarUrl'])
                    : null,
                child: profile['avatarUrl'] == null
                    ? Text(
                        (profile['fullName'] as String? ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: AppTypography.h1.copyWith(
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                profile['fullName'] ?? '',
                style: AppTypography.h2.copyWith(
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  StatusChip(
                    label: '${score.toStringAsFixed(0)}% match',
                    variant: score >= 70
                        ? StatusChipVariant.success
                        : score >= 40
                            ? StatusChipVariant.warning
                            : StatusChipVariant.neutral,
                  ),
                  if (status != 'NONE')
                    StatusChip(
                      label: status == 'CONNECTED'
                          ? 'Connected'
                          : status == 'PENDING_SENT'
                              ? 'Request sent'
                              : status == 'PENDING_RECEIVED'
                                  ? 'Pending you'
                                  : status,
                      variant: status == 'CONNECTED'
                          ? StatusChipVariant.success
                          : StatusChipVariant.info,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _NetworkingStat(
                      icon: Icons.event_outlined,
                      label: 'Shared',
                      value: '${profile['sharedEventsCount'] ?? 0}',
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _NetworkingStat(
                      icon: Icons.people_outline_rounded,
                      label: 'Connections',
                      value: '${profile['connectionsCount'] ?? 0}',
                    ),
                  ),
                ],
              ),
              if (profile['bio'] != null &&
                  (profile['bio'] as String).trim().isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  profile['bio'],
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (interests.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: interests
                      .take(6)
                      .map<Widget>(
                        (interest) => StatusChip(
                          label: interest.toString(),
                          variant: StatusChipVariant.primary,
                          compact: true,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'Skip',
                variant: AppButtonVariant.secondary,
                icon: Icons.close_rounded,
                expanded: true,
                onPressed: _skip,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: AppButton(
                label: status == 'NONE' ? 'Connect' : 'Connected',
                icon: status == 'NONE'
                    ? Icons.person_add_alt_1_rounded
                    : Icons.check_rounded,
                expanded: true,
                onPressed: status == 'NONE' ? () => _connect(profile) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return const EmptyState(
        icon: Icons.mail_outline_rounded,
        compact: true,
        title: 'No pending requests',
        subtitle: 'Incoming networking requests will appear here.',
      );
    }

    return ListView(
      padding: AppSpacing.screenPadding,
      children: _pendingRequests.map((request) {
        return AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primarySoft,
                    backgroundImage: request['senderAvatarUrl'] != null
                        ? NetworkImage(request['senderAvatarUrl'])
                        : null,
                    child: request['senderAvatarUrl'] == null
                        ? Text(
                            (request['senderName'] as String? ?? '?')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: AppTypography.h4.copyWith(
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request['senderName'] ?? '',
                          style: AppTypography.h4.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          request['message']?.toString().trim().isNotEmpty ==
                                  true
                              ? request['message'].toString()
                              : 'Wants to connect with you',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Decline',
                      variant: AppButtonVariant.secondary,
                      expanded: true,
                      onPressed: () => _declineRequest(request['id']),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Accept',
                      icon: Icons.check_rounded,
                      expanded: true,
                      onPressed: () => _acceptRequest(request['id']),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _NetworkingStat extends StatelessWidget {
  const _NetworkingStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: AppRadius.allMd,
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.h4.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
