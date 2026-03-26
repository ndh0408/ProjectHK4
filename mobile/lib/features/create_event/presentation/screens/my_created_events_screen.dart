import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';

// Provider for user's created events
final myCreatedEventsProvider = FutureProvider.autoDispose<List<Event>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  final response = await apiService.getMyCreatedEvents();
  return response.content;
});

class MyCreatedEventsScreen extends ConsumerWidget {
  const MyCreatedEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(myCreatedEventsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context)!.myCreatedEvents,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildEventsList(context, ref, events);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Failed to load events',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(myCreatedEventsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create-event'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No Events Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first event and share it with the world!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/create-event'),
              icon: const Icon(Icons.add),
              label: const Text('Create Event'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, WidgetRef ref, List<Event> events) {
    // Group events by status
    final draftEvents = events.where((e) => e.status == EventStatus.draft).toList();
    final pendingEvents = events.where((e) => e.status == EventStatus.pending).toList();
    final publishedEvents = events.where((e) => e.status == EventStatus.published || e.status == EventStatus.approved).toList();
    final rejectedEvents = events.where((e) => e.status == EventStatus.rejected).toList();
    final otherEvents = events.where((e) =>
        e.status != EventStatus.draft &&
        e.status != EventStatus.pending &&
        e.status != EventStatus.published &&
        e.status != EventStatus.approved &&
        e.status != EventStatus.rejected).toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myCreatedEventsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pendingEvents.isNotEmpty) ...[
            _buildSectionHeader('Pending Approval', Colors.orange),
            ...pendingEvents.map((e) => _EventCard(event: e)),
            const SizedBox(height: 24),
          ],
          if (draftEvents.isNotEmpty) ...[
            _buildSectionHeader('Drafts', Colors.grey),
            ...draftEvents.map((e) => _EventCard(event: e)),
            const SizedBox(height: 24),
          ],
          if (publishedEvents.isNotEmpty) ...[
            _buildSectionHeader('Published', Colors.green),
            ...publishedEvents.map((e) => _EventCard(event: e)),
            const SizedBox(height: 24),
          ],
          if (rejectedEvents.isNotEmpty) ...[
            _buildSectionHeader('Rejected', Colors.red),
            ...rejectedEvents.map((e) => _EventCard(event: e)),
            const SizedBox(height: 24),
          ],
          if (otherEvents.isNotEmpty) ...[
            _buildSectionHeader('Other', Colors.grey),
            ...otherEvents.map((e) => _EventCard(event: e)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE, MMM d · h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => context.push('/event/${event.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: event.imageUrl != null
                    ? Image.network(
                        event.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
              const SizedBox(width: 12),

              // Event Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    _buildStatusBadge(),
                    const SizedBox(height: 6),

                    // Title
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Date
                    Text(
                      dateFormat.format(event.startDate),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),

                    // Registered count
                    if (event.status == EventStatus.published || event.status == EventStatus.approved)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text(
                              '${event.registeredCount} registered',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // More options
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: () => _showOptionsMenu(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.event, color: Colors.grey[400], size: 32),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;
    String text;

    switch (event.status) {
      case EventStatus.draft:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        text = 'Draft';
        break;
      case EventStatus.pending:
        bgColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        text = 'Pending';
        break;
      case EventStatus.published:
      case EventStatus.approved:
        bgColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        text = 'Published';
        break;
      case EventStatus.rejected:
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        text = 'Rejected';
        break;
      case EventStatus.cancelled:
        bgColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        text = 'Cancelled';
        break;
      case EventStatus.completed:
        bgColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        text = 'Completed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('View Event'),
              onTap: () {
                Navigator.pop(context);
                context.push('/event/${event.id}');
              },
            ),
            // Manage Registrations - only for published events
            if (event.status == EventStatus.published || event.status == EventStatus.approved)
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Manage Registrations'),
                subtitle: Text(
                  '${event.registeredCount} registered',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push(
                    '/event-registrations/${event.id}',
                    extra: {'eventTitle': event.title},
                  );
                },
              ),
            if (event.status == EventStatus.draft || event.status == EventStatus.rejected)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Event'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to edit event screen
                },
              ),
            if (event.status == EventStatus.draft)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete Event', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show delete confirmation
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
