import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/app_components.dart';
import '../providers/comparison_provider.dart';

class EventComparisonScreen extends ConsumerStatefulWidget {
  final List<String>? eventIds;

  const EventComparisonScreen({super.key, this.eventIds});

  @override
  ConsumerState<EventComparisonScreen> createState() =>
      _EventComparisonScreenState();
}

class _EventComparisonScreenState extends ConsumerState<EventComparisonScreen> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  List<Event>? _similarEvents;
  bool _loadingSimilar = false;
  Event? _firstSelectedEvent;

  @override
  void initState() {
    super.initState();
    // Sync eventIds from navigation to the provider without clearing existing ones
    // This ensures events added via the comparison button are preserved
    if (widget.eventIds != null && widget.eventIds!.isNotEmpty) {
      final notifier = ref.read(selectedEventsForComparisonProvider.notifier);
      for (final id in widget.eventIds!) {
        notifier.addEventId(id);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    final selectedIds = ref.read(selectedEventsForComparisonProvider);
    if (selectedIds.length >= 2) {
      await _loadComparison();
    } else if (selectedIds.length == 1) {
      // Load first selected event details and similar events
      await _loadFirstEventAndSimilar(selectedIds.first);
    }
  }

  Future<void> _loadFirstEventAndSimilar(String eventId) async {
    setState(() => _loadingSimilar = true);
    try {
      final api = ref.read(apiServiceProvider);

      // Load event details
      final event = await api.getEventById(eventId);
      setState(() => _firstSelectedEvent = event);

      // Load similar events based on category and city
      final similarResponse = await api.getEvents(
        categoryId: event.category?.id.toString(),
        cityId: event.city?.id.toString(),
        size: 10,
        upcoming: true,
      );

      // Filter out the already selected event
      final filtered = similarResponse.content
          .where((e) => e.id.toString() != eventId)
          .take(6)
          .toList();

      setState(() {
        _similarEvents = filtered;
        _loadingSimilar = false;
      });
    } catch (e) {
      setState(() => _loadingSimilar = false);
    }
  }

  Future<void> _loadComparison() async {
    final selectedIds = ref.read(selectedEventsForComparisonProvider);
    if (selectedIds.length < 2) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.compareEvents(selectedIds);
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comparison: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _addEventToComparison(String eventId) {
    final notifier = ref.read(selectedEventsForComparisonProvider.notifier);
    notifier.addEventId(eventId);
    final selectedIds = ref.read(selectedEventsForComparisonProvider);

    if (selectedIds.length >= 2) {
      _loadComparison();
    } else {
      // Reload similar events
      _loadFirstEventAndSimilar(selectedIds.first);
    }
  }

  void _removeEvent(String eventId) {
    final notifier = ref.read(selectedEventsForComparisonProvider.notifier);
    notifier.removeEventId(eventId);
    final selectedIds = ref.read(selectedEventsForComparisonProvider);

    if (selectedIds.isEmpty) {
      setState(() {
        _data = null;
        _firstSelectedEvent = null;
        _similarEvents = null;
      });
    } else if (selectedIds.length == 1) {
      setState(() => _data = null);
      _loadFirstEventAndSimilar(selectedIds.first);
    } else {
      _loadComparison();
    }
  }

  void _clearAll() {
    final notifier = ref.read(selectedEventsForComparisonProvider.notifier);
    notifier.clear();
    setState(() {
      _data = null;
      _firstSelectedEvent = null;
      _similarEvents = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(selectedEventsForComparisonProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Event Comparison'),
        actions: [
          if (selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.pageX),
              child: Container(
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.allPill,
                ),
                child: Text(
                  '${selectedIds.length}/4',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(selectedIds),
      floatingActionButton: selectedIds.length >= 2
          ? FloatingActionButton.extended(
              onPressed: _clearAll,
              backgroundColor: AppColors.error,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear All'),
            )
          : null,
    );
  }

  Widget _buildBody(List<String> selectedIds) {
    if (selectedIds.isEmpty) {
      return _buildEmptyState();
    }

    if (selectedIds.length == 1) {
      return _buildSimilarEventsSelection();
    }

    if (_loading) {
      return const LoadingState(message: 'Preparing comparison...');
    }

    if (_data == null || (_data?['events'] as List?)?.isEmpty == true) {
      return const EmptyState(
        icon: Icons.compare_arrows_rounded,
        compact: true,
        title: 'No comparison data',
        subtitle: 'Add more events or refresh to load the comparison matrix.',
      );
    }

    return _buildComparisonView();
  }

  Widget _buildEmptyState() {
    return EmptyState(
      icon: Icons.compare_arrows_rounded,
      title: 'Select events to compare',
      subtitle:
          'Use the compare action from event detail pages to build a shortlist, then return here for side-by-side decisions.',
      actionLabel: 'Explore Events',
      onAction: () => context.pop(),
    );
  }

  Widget _buildSimilarEventsSelection() {
    if (_loadingSimilar) {
      return const LoadingState(message: 'Finding similar events...');
    }

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        AppCard(
          margin: const EdgeInsets.only(bottom: AppSpacing.section),
          borderColor: AppColors.primary.withValues(alpha: 0.2),
          background: AppColors.primarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const StatusChip(
                    label: 'Selected',
                    variant: StatusChipVariant.primary,
                    compact: true,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _clearAll,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.error,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_firstSelectedEvent != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.allMd,
                      child: _firstSelectedEvent!.imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _firstSelectedEvent!.imageUrl!,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              color: AppColors.primary.withValues(alpha: 0.18),
                              child: const Icon(
                                Icons.event,
                                color: AppColors.primary,
                              ),
                            ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _firstSelectedEvent!.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.h3.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _firstSelectedEvent!.organiserName,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${_firstSelectedEvent!.city?.name ?? "Unknown"} • ${_firstSelectedEvent!.category?.name ?? "Unknown"}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Add a second event',
          subtitle:
              'We recommend nearby matches from the same city or category so the comparison remains relevant.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: const BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: AppRadius.allPill,
              ),
              child: Text(
                'Need at least 1 more',
                style: AppTypography.caption.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_similarEvents == null || _similarEvents!.isEmpty)
          EmptyState(
            icon: Icons.search_off_rounded,
            compact: true,
            title: 'No similar events found',
            subtitle:
                'Open the broader event directory to add a different candidate manually.',
            actionLabel: 'Browse Events',
            onAction: () => context.push('/events'),
          )
        else
          ..._similarEvents!.map((event) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _SimilarEventCard(
                event: event,
                onAdd: () => _addEventToComparison(event.id.toString()),
                onViewDetails: () => context.push('/event/${event.id}'),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildComparisonView() {
    final events = (_data?['events'] as List<dynamic>?) ?? [];
    if (events.isEmpty) {
      return const EmptyState(
        icon: Icons.compare_arrows_rounded,
        compact: true,
        title: 'No data available',
        subtitle: 'Refresh or add a different event set to compare.',
      );
    }

    // Calculate best values
    final bestValues = _calculateBestValues(events);

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
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comparing ${events.length} events',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Shortlist cards appear first, then the metric table confirms the best value.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (events.length < 4)
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                  onPressed: _showAddMoreDialog,
                  icon: const Icon(Icons.add_rounded),
                ),
            ],
          ),
        ),
        const SectionHeader(
          title: 'Compared events',
          subtitle:
              'Cards stay visual, while the table below highlights where each event wins.',
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 320,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final event = events[index] as Map<String, dynamic>;
              final eventId = event['id']?.toString() ?? '';
              final badges = _getBadgesForEvent(event, bestValues, events);
              return _EventComparisonCard(
                event: event,
                badges: badges,
                isBestValue: badges.isNotEmpty,
                onRemove: () => _removeEvent(eventId),
                onViewDetails: () => context.push('/event/$eventId'),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        _buildComparisonTable(events, bestValues),
      ],
    );
  }

  void _showAddMoreDialog() {
    final selectedIds = ref.read(selectedEventsForComparisonProvider);
    AppBottomSheet.show<void>(
      context: context,
      title: 'Add events to compare',
      subtitle:
          'Select up to four events. Recommendations stay close to your current shortlist.',
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: FutureBuilder(
          future: ref.read(apiServiceProvider).getEvents(
                categoryId: _firstSelectedEvent?.categoryId?.toString(),
                size: 20,
                upcoming: true,
              ),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingState(
                message: 'Loading recommended events...',
              );
            }

            if (snapshot.hasError) {
              return EmptyState(
                icon: Icons.error_outline_rounded,
                compact: true,
                title: 'Could not load more events',
                subtitle: 'Try again in a moment or browse events manually.',
                actionLabel: 'Browse Events',
                onAction: () {
                  Navigator.of(context).pop();
                  context.push('/events');
                },
              );
            }

            final allEvents = snapshot.data!.content
                .where((e) => !selectedIds.contains(e.id.toString()))
                .toList();

            if (allEvents.isEmpty) {
              return const EmptyState(
                icon: Icons.playlist_add_check_circle_rounded,
                compact: true,
                title: 'Shortlist is complete',
                subtitle:
                    'There are no more recommended events to add right now.',
              );
            }

            return ListView.separated(
              itemCount: allEvents.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final event = allEvents[index];
                return EventListTile(
                  event: event,
                  compact: true,
                  onTap: () => context.push('/event/${event.id}'),
                  trailing: IconButton(
                    onPressed: () {
                      _addEventToComparison(event.id.toString());
                      Navigator.of(context).pop();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.successLight,
                      foregroundColor: AppColors.success,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateBestValues(List<dynamic> events) {
    if (events.isEmpty) return {};

    // Lowest price
    final withPrice = events.where((e) => e['ticketPrice'] != null).toList();
    final lowestPrice = withPrice.isNotEmpty
        ? withPrice
            .map((e) => e['ticketPrice'] as num)
            .reduce((a, b) => a < b ? a : b)
        : null;

    // Highest rating
    final withRating = events.where((e) => e['averageRating'] != null).toList();
    final highestRating = withRating.isNotEmpty
        ? withRating
            .map((e) => e['averageRating'] as num)
            .reduce((a, b) => a > b ? a : b)
        : null;

    // Highest fill rate (most popular)
    final withFillRate = events.where((e) => e['fillRate'] != null).toList();
    final highestFillRate = withFillRate.isNotEmpty
        ? withFillRate
            .map((e) => e['fillRate'] as num)
            .reduce((a, b) => a > b ? a : b)
        : null;

    // Most registrations
    final withRegistrations =
        events.where((e) => e['registrationCount'] != null).toList();
    final mostRegistrations = withRegistrations.isNotEmpty
        ? withRegistrations
            .map((e) => e['registrationCount'] as num)
            .reduce((a, b) => a > b ? a : b)
        : null;

    return {
      'lowestPrice': lowestPrice,
      'highestRating': highestRating,
      'highestFillRate': highestFillRate,
      'mostRegistrations': mostRegistrations,
    };
  }

  List<String> _getBadgesForEvent(
    Map<String, dynamic> event,
    Map<String, dynamic> bestValues,
    List<dynamic> allEvents,
  ) {
    final badges = <String>[];

    if (event['ticketPrice'] == bestValues['lowestPrice'] &&
        event['ticketPrice'] != null) {
      badges.add('Best Price');
    }
    if (event['averageRating'] == bestValues['highestRating'] &&
        event['averageRating'] != null) {
      badges.add('Top Rated');
    }
    if (event['fillRate'] == bestValues['highestFillRate'] &&
        event['fillRate'] != null) {
      badges.add('Most Popular');
    }
    if (event['registrationCount'] == bestValues['mostRegistrations'] &&
        event['registrationCount'] != null) {
      badges.add('Most Registrations');
    }

    return badges;
  }

  Widget _buildComparisonTable(
      List<dynamic> events, Map<String, dynamic> bestValues) {
    final rows = [
      _ComparisonRow(
        label: 'Ticket Price',
        icon: Icons.attach_money,
        values: events.map((e) {
          final price = e['ticketPrice'];
          if (price == null) return 'Free';
          return '\$${(price as num).toStringAsFixed(0)}';
        }).toList(),
        highlights: events
            .map((e) => e['ticketPrice'] == bestValues['lowestPrice'])
            .toList(),
        highlightColor: AppColors.success,
      ),
      _ComparisonRow(
        label: 'Rating',
        icon: Icons.star,
        values: events.map((e) {
          final rating = e['averageRating'];
          if (rating == null) return 'N/A';
          return '${(rating as num).toStringAsFixed(1)} ⭐';
        }).toList(),
        highlights: events
            .map((e) => e['averageRating'] == bestValues['highestRating'])
            .toList(),
        highlightColor: Colors.amber,
      ),
      _ComparisonRow(
        label: 'Registrations',
        icon: Icons.people,
        values: events.map((e) {
          final count = e['registrationCount'];
          if (count == null) return '-';
          return count.toString();
        }).toList(),
        highlights: events
            .map((e) =>
                e['registrationCount'] == bestValues['mostRegistrations'])
            .toList(),
        highlightColor: AppColors.primary,
      ),
      _ComparisonRow(
        label: 'Fill Rate',
        icon: Icons.pie_chart,
        values: events.map((e) {
          final rate = e['fillRate'];
          if (rate == null) return '-';
          return '${(rate as num).toStringAsFixed(0)}%';
        }).toList(),
        highlights: events
            .map((e) => e['fillRate'] == bestValues['highestFillRate'])
            .toList(),
        highlightColor: AppColors.success,
      ),
      _ComparisonRow(
        label: 'Date',
        icon: Icons.schedule,
        values: events.map((e) {
          final startDate = e['startDate'] ?? e['startTime'];
          if (startDate == null) return '-';
          try {
            final date = DateTime.parse(startDate.toString());
            return DateFormat('dd/MM/yyyy').format(date);
          } catch (_) {
            return startDate.toString();
          }
        }).toList(),
      ),
      _ComparisonRow(
        label: 'Venue',
        icon: Icons.location_on,
        values: events.map((e) => e['venue']?.toString() ?? '-').toList(),
      ),
      _ComparisonRow(
        label: 'City',
        icon: Icons.location_city,
        values: events.map((e) => e['cityName']?.toString() ?? '-').toList(),
      ),
      _ComparisonRow(
        label: 'Category',
        icon: Icons.category,
        values:
            events.map((e) => e['categoryName']?.toString() ?? '-').toList(),
      ),
    ];

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Detailed Comparison',
                  style: AppTypography.h4.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          ...rows.map((row) => _buildRow(row)),
        ],
      ),
    );
  }

  Widget _buildRow(_ComparisonRow row) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Icon(row.icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.label,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: row.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final value = entry.value;
                  final isHighlighted =
                      row.highlights.length > index && row.highlights[index];

                  return Container(
                    width: 140,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: isHighlighted
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: row.highlightColor?.withValues(alpha: 0.1),
                              borderRadius: AppRadius.allXs,
                              border: Border.all(
                                color: row.highlightColor
                                        ?.withValues(alpha: 0.3) ??
                                    Colors.transparent,
                              ),
                            ),
                            child: Text(
                              value,
                              textAlign: TextAlign.center,
                              style: AppTypography.caption.copyWith(
                                color:
                                    row.highlightColor ?? AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : Text(
                            value,
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarEventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onAdd;
  final VoidCallback onViewDetails;

  const _SimilarEventCard({
    required this.event,
    required this.onAdd,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onViewDetails,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: AppRadius.allMd,
            child: SizedBox(
              width: 84,
              height: 84,
              child: event.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: event.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: AppColors.primarySoft,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        child:
                            const Icon(Icons.event, color: AppColors.primary),
                      ),
                    )
                  : Container(
                      color: AppColors.primarySoft,
                      child: const Icon(Icons.event, color: AppColors.primary),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h4.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  event.organiserName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '${event.city?.name ?? "Unknown"} • ${event.category?.name ?? "Unknown"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    if (event.averageRating != null) ...[
                      const Icon(Icons.star_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: AppSpacing.xxs),
                      Text(
                        event.averageRating!.toStringAsFixed(1),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    StatusChip(
                      label: event.ticketPrice != null
                          ? '\$${event.ticketPrice!.toStringAsFixed(0)}'
                          : 'Free',
                      variant: event.ticketPrice != null
                          ? StatusChipVariant.primary
                          : StatusChipVariant.success,
                      compact: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          AppButton(
            label: 'Add',
            size: AppButtonSize.sm,
            icon: Icons.add_rounded,
            variant: AppButtonVariant.tonal,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _EventComparisonCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final List<String> badges;
  final bool isBestValue;
  final VoidCallback onRemove;
  final VoidCallback onViewDetails;

  const _EventComparisonCard({
    required this.event,
    required this.badges,
    required this.isBestValue,
    required this.onRemove,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = event['imageUrl']?.toString();
    final title = event['title']?.toString() ?? 'Untitled';
    final organiserName = event['organiserName']?.toString() ?? 'Unknown';
    final price = event['ticketPrice'];
    final rating = event['averageRating'];

    return SizedBox(
      width: 220,
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: isBestValue
            ? AppColors.success.withValues(alpha: 0.35)
            : AppColors.borderLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.primarySoft,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.primarySoft,
                            child: const Icon(Icons.event,
                                color: AppColors.primary),
                          ),
                        )
                      : Container(
                          color: AppColors.primarySoft,
                          child: const Icon(Icons.event,
                              color: AppColors.primary, size: 40),
                        ),
                ),
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: IconButton(
                    onPressed: onRemove,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.55),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ),
                if (badges.isNotEmpty)
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: badges.map((badge) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge,
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      organiserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (rating != null)
                          Row(
                            children: [
                              const Icon(Icons.star,
                                  size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                (rating as num).toStringAsFixed(1),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        StatusChip(
                          label: price != null
                              ? '\$${(price as num).toStringAsFixed(0)}'
                              : 'Free',
                          variant: price != null
                              ? StatusChipVariant.primary
                              : StatusChipVariant.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: 'View Details',
                      size: AppButtonSize.sm,
                      expanded: true,
                      onPressed: onViewDetails,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonRow {
  final String label;
  final IconData icon;
  final List<String> values;
  final List<bool> highlights;
  final Color? highlightColor;

  _ComparisonRow({
    required this.label,
    required this.icon,
    required this.values,
    this.highlights = const [],
    this.highlightColor,
  });
}
