import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';

class EventComparisonScreen extends ConsumerStatefulWidget {
  final List<String> eventIds;

  const EventComparisonScreen({super.key, required this.eventIds});

  @override
  ConsumerState<EventComparisonScreen> createState() => _EventComparisonScreenState();
}

class _EventComparisonScreenState extends ConsumerState<EventComparisonScreen> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  late List<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = List.from(widget.eventIds);
    if (_selectedIds.length >= 2) {
      _loadComparison();
    }
  }

  Future<void> _loadComparison() async {
    if (_selectedIds.length < 2) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final data = await api.compareEvents(_selectedIds);
      setState(() { _data = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load comparison: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = (_data?['events'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compare Events'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _selectedIds.length < 2
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.compare_arrows, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Select 2-4 events to compare',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Go to event details and long-press to add events for comparison.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : events.isEmpty
                  ? const Center(child: Text('No data available'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildComparisonTable(events),
                    ),
                  ),
                ),
    );
  }

  Widget _buildComparisonTable(List<dynamic> events) {
    final fields = [
      {'label': 'Event', 'key': 'title'},
      {'label': 'Organiser', 'key': 'organiserName'},
      {'label': 'Category', 'key': 'categoryName'},
      {'label': 'City', 'key': 'cityName'},
      {'label': 'Price', 'key': 'ticketPrice', 'format': 'price'},
      {'label': 'Capacity', 'key': 'capacity'},
      {'label': 'Registered', 'key': 'registrationCount'},
      {'label': 'Fill Rate', 'key': 'fillRate', 'format': 'percent'},
      {'label': 'Rating', 'key': 'averageRating', 'format': 'rating'},
      {'label': 'Reviews', 'key': 'reviewCount'},
      {'label': 'Venue', 'key': 'venue'},
    ];

    return Table(
      border: TableBorder.all(color: Colors.grey[300]!, borderRadius: BorderRadius.circular(8)),
      defaultColumnWidth: const FixedColumnWidth(160),
      columnWidths: const {0: FixedColumnWidth(100)},
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.blue[50]),
          children: [
            _headerCell(''),
            ...events.map((e) => _headerCell(e['title'] ?? '', isTitle: true)),
          ],
        ),
        ...fields.map((field) => TableRow(
          children: [
            _labelCell(field['label'] as String),
            ...events.map((e) {
              var value = e[field['key']];
              String display;
              if (field['format'] == 'price') {
                display = value != null ? '\$${(value as num).toStringAsFixed(0)}' : 'Free';
              } else if (field['format'] == 'percent') {
                display = value != null ? '${(value as num).toStringAsFixed(1)}%' : '-';
              } else if (field['format'] == 'rating') {
                display = value != null ? '${(value as num).toStringAsFixed(1)} / 5' : 'No ratings';
              } else {
                display = value?.toString() ?? '-';
              }
              return _valueCell(display);
            }),
          ],
        )),
      ],
    );
  }

  Widget _headerCell(String text, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: isTitle ? 13 : 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _labelCell(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.grey[50],
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
    );
  }

  Widget _valueCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }
}
