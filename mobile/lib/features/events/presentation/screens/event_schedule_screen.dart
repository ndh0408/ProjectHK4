import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_components.dart';

class EventScheduleScreen extends ConsumerStatefulWidget {
  const EventScheduleScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  ConsumerState<EventScheduleScreen> createState() =>
      _EventScheduleScreenState();
}

class _EventScheduleScreenState extends ConsumerState<EventScheduleScreen> {
  Map<String, dynamic>? _schedule;
  List<Map<String, dynamic>> _mySessions = [];
  bool _loading = true;
  String? _errorMessage;
  String _selectedTrack = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final schedule = await api.getEventSchedule(widget.eventId);
      final mySessions = await api.getMyEventSchedule(widget.eventId);
      if (!mounted) return;
      setState(() {
        _schedule = schedule;
        _mySessions = mySessions;
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

  Future<void> _registerForSession(String sessionId) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.registerForSession(sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session added to your schedule'),
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

  @override
  Widget build(BuildContext context) {
    final sessions = (_schedule?['sessions'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
    final tracks = [
      'All',
      ...(_schedule?['tracks'] as List<dynamic>?)?.cast<String>() ?? [],
    ];
    final mySessionIds = _mySessions.map((session) => session['id']).toSet();

    final filtered = _selectedTrack == 'All'
        ? sessions
        : sessions
            .where((session) => session['track'] == _selectedTrack)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Schedule'),
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
      ),
      body: _loading
          ? const LoadingState(message: 'Loading event schedule...')
          : _errorMessage != null
              ? ErrorState(message: _errorMessage!, onRetry: _loadData)
              : filtered.isEmpty && sessions.isEmpty
                  ? EmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'No sessions available',
                      subtitle:
                          'The organiser has not published the detailed agenda yet.',
                      actionLabel: 'Refresh',
                      onAction: _loadData,
                    )
                  : ListView(
                      padding: AppSpacing.screenPadding,
                      children: [
                        AppCard(
                          margin:
                              const EdgeInsets.only(bottom: AppSpacing.section),
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
                                  Icons.schedule_rounded,
                                  color: Colors.white,
                                ),
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
                                      '${sessions.length} sessions • ${_mySessions.length} in your personal plan',
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
                        if (tracks.length > 1) ...[
                          const SectionHeader(
                            title: 'Tracks',
                            subtitle:
                                'Use track filters to focus on one stream without losing the rest of the agenda.',
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: tracks.map((track) {
                                final selected = _selectedTrack == track;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      right: AppSpacing.sm),
                                  child: _TrackChip(
                                    label: track,
                                    selected: selected,
                                    onTap: () => setState(
                                      () => _selectedTrack = track,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),
                        ],
                        ...filtered.map(
                          (session) => _SessionCard(
                            session: session,
                            isRegistered: mySessionIds.contains(session['id']),
                            onRegister: () =>
                                _registerForSession(session['id'].toString()),
                          ),
                        ),
                        if (filtered.isEmpty)
                          const EmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            compact: true,
                            title: 'No sessions in this track',
                            subtitle:
                                'Switch tracks to browse the rest of the agenda.',
                          ),
                      ],
                    ),
    );
  }
}

class _TrackChip extends StatelessWidget {
  const _TrackChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.allPill,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : AppColors.surfaceVariant,
            borderRadius: AppRadius.allPill,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.isRegistered,
    required this.onRegister,
  });

  final Map<String, dynamic> session;
  final bool isRegistered;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final startTime = session['startTime'] != null
        ? DateTime.parse(session['startTime'].toString())
        : null;
    final endTime = session['endTime'] != null
        ? DateTime.parse(session['endTime'].toString())
        : null;
    final timeFormat = DateFormat('h:mm a');

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      borderColor: isRegistered
          ? AppColors.success.withValues(alpha: 0.3)
          : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (startTime != null && endTime != null)
                Container(
                  width: 76,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadius.allMd,
                  ),
                  child: Column(
                    children: [
                      Text(
                        timeFormat.format(startTime),
                        textAlign: TextAlign.center,
                        style: AppTypography.label.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        timeFormat.format(endTime),
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              if (startTime != null && endTime != null)
                const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session['title']?.toString() ?? '',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        if (session['track'] != null)
                          StatusChip(
                            label: session['track'].toString(),
                            variant: StatusChipVariant.primary,
                            compact: true,
                          ),
                        if (session['room'] != null)
                          StatusChip(
                            label: session['room'].toString(),
                            variant: StatusChipVariant.info,
                            compact: true,
                          ),
                        if (session['speakerName'] != null)
                          StatusChip(
                            label: session['speakerName'].toString(),
                            variant: StatusChipVariant.neutral,
                            compact: true,
                          ),
                        if (isRegistered)
                          const StatusChip(
                            label: 'In my schedule',
                            variant: StatusChipVariant.success,
                            compact: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (session['description']?.toString().trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              session['description'].toString(),
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (!isRegistered) ...[
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Add to My Schedule',
              icon: Icons.add_task_rounded,
              variant: AppButtonVariant.secondary,
              expanded: true,
              onPressed: onRegister,
            ),
          ],
        ],
      ),
    );
  }
}
