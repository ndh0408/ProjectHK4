import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/registration.dart';

// Provider for event registrations
final eventRegistrationsProvider = FutureProvider.autoDispose
    .family<List<Registration>, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  try {
    final response = await api.getEventRegistrations(eventId);
    return response.content;
  } catch (e, stack) {
    debugPrint('Failed to load registrations: $e');
    debugPrint('Stack trace: $stack');
    rethrow;
  }
});

class EventRegistrationsScreen extends ConsumerStatefulWidget {
  const EventRegistrationsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  final String eventId;
  final String eventTitle;

  @override
  ConsumerState<EventRegistrationsScreen> createState() =>
      _EventRegistrationsScreenState();
}

class _EventRegistrationsScreenState
    extends ConsumerState<EventRegistrationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _filterStatus = null; // All
            break;
          case 1:
            _filterStatus = 'PENDING';
            break;
          case 2:
            _filterStatus = 'APPROVED';
            break;
          case 3:
            _filterStatus = 'REJECTED';
            break;
        }
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registrationsAsync =
        ref.watch(eventRegistrationsProvider(widget.eventId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registrations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              widget.eventTitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: AppLocalizations.of(context)!.scanQrCode,
            onPressed: () {
              context.push(
                '/event/${widget.eventId}/scan-checkin',
                extra: {'eventTitle': widget.eventTitle},
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: registrationsAsync.when(
        data: (registrations) {
          final filtered = _filterStatus == null
              ? registrations
              : registrations
                  .where((r) => r.status.name.toUpperCase() == _filterStatus)
                  .toList();

          if (filtered.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(eventRegistrationsProvider(widget.eventId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final registration = filtered[index];
                return _RegistrationCard(
                  registration: registration,
                  onApprove: () => _approveRegistration(registration),
                  onReject: () => _showRejectDialog(registration),
                  onCheckIn: () => _checkInRegistration(registration),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Failed to load registrations',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: TextStyle(color: Colors.red[400], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(eventRegistrationsProvider(widget.eventId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_filterStatus) {
      case 'PENDING':
        message = 'No pending registrations';
        icon = Icons.hourglass_empty;
        break;
      case 'APPROVED':
        message = 'No approved registrations';
        icon = Icons.check_circle_outline;
        break;
      case 'REJECTED':
        message = 'No rejected registrations';
        icon = Icons.cancel_outlined;
        break;
      default:
        message = 'No registrations yet';
        icon = Icons.people_outline;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRegistration(Registration registration) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.approveRegistration(registration.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${registration.userName ?? 'User'} approved'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(eventRegistrationsProvider(widget.eventId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(Registration registration) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject ${registration.userName ?? registration.userEmail}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _rejectRegistration(registration, reasonController.text);
    }
  }

  Future<void> _rejectRegistration(
      Registration registration, String? reason) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.rejectRegistration(
        registration.id,
        reason: reason?.isNotEmpty == true ? reason : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${registration.userName ?? 'User'} rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        ref.invalidate(eventRegistrationsProvider(widget.eventId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkInRegistration(Registration registration) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.checkInRegistration(registration.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${registration.userName ?? 'User'} checked in'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(eventRegistrationsProvider(widget.eventId));
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to check in';

        // Extract error message from DioException or API response
        if (e is DioException) {
          final responseData = e.response?.data;
          if (responseData is Map<String, dynamic>) {
            errorMessage = responseData['message'] ?? errorMessage;
          }
        }

        final errorStr = e.toString();
        if (errorStr.contains('not available yet') || errorMessage.contains('not available yet')) {
          errorMessage = 'Check-in is not available yet. Opens 2 hours before event.';
        } else if (errorStr.contains('period has ended') || errorMessage.contains('period has ended')) {
          errorMessage = 'Check-in period has ended for this event.';
        } else if (errorStr.contains('already been checked in') || errorMessage.contains('already been checked in')) {
          errorMessage = 'Already checked in.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

class _RegistrationCard extends StatelessWidget {
  const _RegistrationCard({
    required this.registration,
    required this.onApprove,
    required this.onReject,
    required this.onCheckIn,
  });

  final Registration registration;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User info row
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: registration.userAvatarUrl != null
                      ? CachedNetworkImageProvider(registration.userAvatarUrl!)
                      : null,
                  child: registration.userAvatarUrl == null
                      ? Text(
                          (registration.userName ?? registration.userEmail ?? 'U')[0]
                              .toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),

                // Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        registration.userName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (registration.userEmail != null)
                        Text(
                          registration.userEmail!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),

                // Status badge
                _buildStatusBadge(),
              ],
            ),

            const SizedBox(height: 12),

            // Registration date
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Registered ${dateFormat.format(registration.createdAt)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Phone if available
            if (registration.userPhone != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    registration.userPhone!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],

            // Checked-in status
            if (registration.isCheckedIn) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Checked in at ${DateFormat('MMM d, h:mm a').format(registration.checkedInAt!)}',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Rejection reason if rejected
            if (registration.isRejected &&
                registration.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        registration.rejectionReason!,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons
            if (registration.isPending || registration.isApproved) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (registration.isPending) ...[
                    // Reject button
                    OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Approve button
                    ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ] else if (registration.isApproved && !registration.isCheckedIn) ...[
                    // Check-in button (only show if not checked in)
                    ElevatedButton.icon(
                      onPressed: onCheckIn,
                      icon: const Icon(Icons.qr_code_scanner, size: 18),
                      label: const Text('Check In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color backgroundColor;
    Color textColor;
    String label;
    IconData icon;

    switch (registration.status) {
      case RegistrationStatusEnum.pending:
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[700]!;
        label = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      case RegistrationStatusEnum.approved:
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[700]!;
        label = 'Approved';
        icon = Icons.check_circle;
        break;
      case RegistrationStatusEnum.rejected:
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[700]!;
        label = 'Rejected';
        icon = Icons.cancel;
        break;
      case RegistrationStatusEnum.waitingList:
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[700]!;
        label = 'Waiting';
        icon = Icons.access_time;
        break;
      case RegistrationStatusEnum.cancelled:
        backgroundColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = 'Cancelled';
        icon = Icons.block;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
