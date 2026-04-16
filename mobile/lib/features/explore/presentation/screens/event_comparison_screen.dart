import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../providers/comparison_provider.dart';

class EventComparisonScreen extends ConsumerStatefulWidget {
  final List<String>? eventIds;

  const EventComparisonScreen({super.key, this.eventIds});

  @override
  ConsumerState<EventComparisonScreen> createState() => _EventComparisonScreenState();
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
        categoryId: event.category?.id?.toString(),
        cityId: event.city?.id?.toString(),
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('So sánh sự kiện'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (selectedIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${selectedIds.length}/4',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
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
              label: const Text('Xóa tất cả'),
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_data == null || (_data?['events'] as List?)?.isEmpty == true) {
      return const Center(child: Text('Không có dữ liệu'));
    }

    return _buildComparisonView();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.compare_arrows,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Chọn sự kiện để so sánh',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Nhấn nút so sánh (⚖️) trong màn chi tiết sự kiện để thêm vào danh sách so sánh',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.explore),
              label: const Text('Khám phá sự kiện'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarEventsSelection() {
    if (_loadingSimilar) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected event section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ĐÃ CHỌN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: _clearAll,
                      child: const Icon(Icons.close, size: 20, color: AppColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_firstSelectedEvent != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
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
                                color: AppColors.primary.withOpacity(0.2),
                                child: const Icon(Icons.event, color: AppColors.primary),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _firstSelectedEvent!.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _firstSelectedEvent!.organiserName ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${_firstSelectedEvent!.city?.name ?? "Unknown"} • ${_firstSelectedEvent!.category?.name ?? "Unknown"}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
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

          const SizedBox(height: 24),

          // Similar events section
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Chọn thêm sự kiện để so sánh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dựa trên thể loại và thành phố tương tự',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Cần thêm ít nhất 1',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (_similarEvents == null || _similarEvents!.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Không tìm thấy sự kiện tương tự',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/events'),
                      icon: const Icon(Icons.explore),
                      label: const Text('Tìm sự kiện khác'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _similarEvents!.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final event = _similarEvents![index];
                return _SimilarEventCard(
                  event: event,
                  onAdd: () => _addEventToComparison(event.id.toString()),
                  onViewDetails: () => context.push('/event/${event.id}'),
                );
              },
            ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildComparisonView() {
    final events = (_data?['events'] as List<dynamic>?) ?? [];
    if (events.isEmpty) return const Center(child: Text('Không có dữ liệu'));

    // Calculate best values
    final bestValues = _calculateBestValues(events);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'So sánh ${events.length} sự kiện',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vuốt sang phải để xem chi tiết',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (events.length < 4)
                TextButton.icon(
                  onPressed: () {
                    // Show dialog to add more events
                    _showAddMoreDialog();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Thêm'),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal scrollable event cards
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

          const SizedBox(height: 24),

          // Comparison table section
          _buildComparisonTable(events, bestValues),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showAddMoreDialog() {
    final selectedIds = ref.read(selectedEventsForComparisonProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Thêm sự kiện để so sánh',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder(
                  future: ref.read(apiServiceProvider).getEvents(
                    categoryId: _firstSelectedEvent?.categoryId?.toString(),
                    size: 20,
                    upcoming: true,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allEvents = snapshot.data!.content
                        .where((e) => !selectedIds.contains(e.id.toString()))
                        .toList();

                    if (allEvents.isEmpty) {
                      return const Center(child: Text('Không còn sự kiện nào'));
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: allEvents.length,
                      itemBuilder: (context, index) {
                        final event = allEvents[index];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: event.imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: event.imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.event),
                                  ),
                          ),
                          title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${event.city?.name ?? "Unknown"} • ${event.category?.name ?? "Unknown"}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle, color: AppColors.success),
                            onPressed: () {
                              _addEventToComparison(event.id.toString());
                              Navigator.pop(context);
                            },
                          ),
                          onTap: () => context.push('/event/${event.id}'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _calculateBestValues(List<dynamic> events) {
    if (events.isEmpty) return {};

    // Lowest price
    final withPrice = events.where((e) => e['ticketPrice'] != null).toList();
    final lowestPrice = withPrice.isNotEmpty
        ? withPrice.map((e) => e['ticketPrice'] as num).reduce((a, b) => a < b ? a : b)
        : null;

    // Highest rating
    final withRating = events.where((e) => e['averageRating'] != null).toList();
    final highestRating = withRating.isNotEmpty
        ? withRating.map((e) => e['averageRating'] as num).reduce((a, b) => a > b ? a : b)
        : null;

    // Highest fill rate (most popular)
    final withFillRate = events.where((e) => e['fillRate'] != null).toList();
    final highestFillRate = withFillRate.isNotEmpty
        ? withFillRate.map((e) => e['fillRate'] as num).reduce((a, b) => a > b ? a : b)
        : null;

    // Most registrations
    final withRegistrations = events.where((e) => e['registrationCount'] != null).toList();
    final mostRegistrations = withRegistrations.isNotEmpty
        ? withRegistrations.map((e) => e['registrationCount'] as num).reduce((a, b) => a > b ? a : b)
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

    if (event['ticketPrice'] == bestValues['lowestPrice'] && event['ticketPrice'] != null) {
      badges.add('Giá tốt nhất');
    }
    if (event['averageRating'] == bestValues['highestRating'] && event['averageRating'] != null) {
      badges.add('Đánh giá cao nhất');
    }
    if (event['fillRate'] == bestValues['highestFillRate'] && event['fillRate'] != null) {
      badges.add('Phổ biến nhất');
    }
    if (event['registrationCount'] == bestValues['mostRegistrations'] &&
        event['registrationCount'] != null) {
      badges.add('Nhiều người đăng ký nhất');
    }

    return badges;
  }

  Widget _buildComparisonTable(List<dynamic> events, Map<String, dynamic> bestValues) {
    final rows = [
      _ComparisonRow(
        label: 'Giá vé',
        icon: Icons.attach_money,
        values: events.map((e) {
          final price = e['ticketPrice'];
          if (price == null) return 'Miễn phí';
          return '\$${(price as num).toStringAsFixed(0)}';
        }).toList(),
        highlights: events.map((e) => e['ticketPrice'] == bestValues['lowestPrice']).toList(),
        highlightColor: AppColors.success,
      ),
      _ComparisonRow(
        label: 'Đánh giá',
        icon: Icons.star,
        values: events.map((e) {
          final rating = e['averageRating'];
          if (rating == null) return 'Chưa có';
          return '${(rating as num).toStringAsFixed(1)} ⭐';
        }).toList(),
        highlights: events.map((e) => e['averageRating'] == bestValues['highestRating']).toList(),
        highlightColor: Colors.amber,
      ),
      _ComparisonRow(
        label: 'Số người đăng ký',
        icon: Icons.people,
        values: events.map((e) {
          final count = e['registrationCount'];
          if (count == null) return '-';
          return count.toString();
        }).toList(),
        highlights: events.map((e) => e['registrationCount'] == bestValues['mostRegistrations']).toList(),
        highlightColor: AppColors.primary,
      ),
      _ComparisonRow(
        label: 'Tỷ lệ lấp đầy',
        icon: Icons.pie_chart,
        values: events.map((e) {
          final rate = e['fillRate'];
          if (rate == null) return '-';
          return '${(rate as num).toStringAsFixed(0)}%';
        }).toList(),
        highlights: events.map((e) => e['fillRate'] == bestValues['highestFillRate']).toList(),
        highlightColor: AppColors.success,
      ),
      _ComparisonRow(
        label: 'Thời gian',
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
        label: 'Địa điểm',
        icon: Icons.location_on,
        values: events.map((e) => e['venue']?.toString() ?? '-').toList(),
      ),
      _ComparisonRow(
        label: 'Thành phố',
        icon: Icons.location_city,
        values: events.map((e) => e['cityName']?.toString() ?? '-').toList(),
      ),
      _ComparisonRow(
        label: 'Thể loại',
        icon: Icons.category,
        values: events.map((e) => e['categoryName']?.toString() ?? '-').toList(),
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.analytics, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Bảng so sánh chi tiết',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
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
                  final isHighlighted = row.highlights.length > index && row.highlights[index];

                  return Container(
                    width: 140,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: isHighlighted
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: row.highlightColor?.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: row.highlightColor?.withOpacity(0.3) ?? Colors.transparent,
                              ),
                            ),
                            child: Text(
                              value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: row.highlightColor ?? AppColors.textPrimary,
                              ),
                            ),
                          )
                        : Text(
                            value,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onViewDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: event.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.event, color: AppColors.primary),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.primary.withOpacity(0.1),
                        child: const Icon(Icons.event, color: AppColors.primary),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.organiserName ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${event.city?.name ?? "Unknown"} • ${event.category?.name ?? "Unknown"}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (event.averageRating != null) ...[
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            event.averageRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: event.ticketPrice != null
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            event.ticketPrice != null
                                ? '\$${event.ticketPrice!.toStringAsFixed(0)}'
                                : 'Miễn phí',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: event.ticketPrice != null
                                  ? AppColors.primary
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Thêm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
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

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isBestValue
                ? AppColors.success.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: isBestValue ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: isBestValue
            ? Border.all(color: AppColors.success.withOpacity(0.5), width: 2)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
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
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.primary.withOpacity(0.1),
                            child: const Icon(Icons.event, color: AppColors.primary),
                          ),
                        )
                      : Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Icon(Icons.event, color: AppColors.primary, size: 40),
                        ),
                ),
                // Remove button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                // Badges
                if (badges.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: badges.map((badge) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),

            // Content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      organiserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        if (rating != null)
                          Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                (rating as num).toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: price != null
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            price != null ? '\$${(price as num).toStringAsFixed(0)}' : 'Miễn phí',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: price != null ? AppColors.primary : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onViewDetails,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Xem chi tiết',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
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
