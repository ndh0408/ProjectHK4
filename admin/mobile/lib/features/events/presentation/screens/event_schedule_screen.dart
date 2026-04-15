import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_service.dart';

class EventScheduleScreen extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const EventScheduleScreen({super.key, required this.eventId, required this.eventTitle});

  @override
  ConsumerState<EventScheduleScreen> createState() => _EventScheduleScreenState();
}

class _EventScheduleScreenState extends ConsumerState<EventScheduleScreen> {
  Map<String, dynamic>? _schedule;
  List<Map<String, dynamic>> _mySessions = [];
  bool _loading = true;
  String _selectedTrack = 'All';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final schedule = await api.getEventSchedule(widget.eventId);
      final mySessions = await api.getMyEventSchedule(widget.eventId);
      setState(() { _schedule = schedule; _mySessions = mySessions; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _registerForSession(String sessionId) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.registerForSession(sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registered for session!'), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    final sessions = (_schedule?['sessions'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    final tracks = ['All', ...(_schedule?['tracks'] as List<dynamic>?)?.cast<String>() ?? []];
    final mySessionIds = _mySessions.map((s) => s['id']).toSet();

    final filtered = _selectedTrack == 'All'
        ? sessions
        : sessions.where((s) => s['track'] == _selectedTrack).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule - ${widget.eventTitle}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (tracks.length > 2)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: tracks.map((track) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(track),
                          selected: _selectedTrack == track,
                          onSelected: (v) => setState(() => _selectedTrack = track),
                        ),
                      )).toList(),
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No sessions available'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final session = filtered[i];
                            final isRegistered = mySessionIds.contains(session['id']);
                            return _buildSessionCard(session, isRegistered);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session, bool isRegistered) {
    final startTime = session['startTime'] != null ? DateTime.parse(session['startTime'].toString()) : null;
    final endTime = session['endTime'] != null ? DateTime.parse(session['endTime'].toString()) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isRegistered ? Colors.green : Colors.grey[300]!, width: isRegistered ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(session['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                if (isRegistered) const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            if (startTime != null && endTime != null)
              Row(children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')} - ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ]),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              if (session['room'] != null) Chip(label: Text(session['room'], style: const TextStyle(fontSize: 11)), avatar: const Icon(Icons.room, size: 14), visualDensity: VisualDensity.compact),
              if (session['track'] != null) Chip(label: Text(session['track'], style: const TextStyle(fontSize: 11)), visualDensity: VisualDensity.compact),
              if (session['speakerName'] != null) Chip(label: Text(session['speakerName'], style: const TextStyle(fontSize: 11)), avatar: const Icon(Icons.person, size: 14), visualDensity: VisualDensity.compact),
            ]),
            if (!isRegistered) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _registerForSession(session['id'].toString()),
                  child: const Text('Add to My Schedule'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
