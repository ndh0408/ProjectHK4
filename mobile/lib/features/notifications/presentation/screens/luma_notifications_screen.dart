import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/notification.dart';
import '../../../main/presentation/screens/main_shell.dart';
import 'notifications_screen.dart';

/// Screen that displays notifications in a chat-like format
class LumaNotificationsScreen extends ConsumerStatefulWidget {
  const LumaNotificationsScreen({super.key});

  @override
  ConsumerState<LumaNotificationsScreen> createState() =>
      _LumaNotificationsScreenState();
}

class _LumaNotificationsScreenState
    extends ConsumerState<LumaNotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(notificationsProvider.notifier).loadNotifications(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).loadNotifications();
    }
  }

  Future<void> _openChatWithUser(String userId) async {
    try {
      // Get or create direct chat with this user
      final api = ref.read(apiServiceProvider);
      final conversation = await api.getDirectChat(userId);

      if (mounted) {
        context.push('/chat/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  bool _shouldShowDateHeader(int index, List<AppNotification> notifications) {
    if (index == 0) return true;
    final current = notifications[index].createdAt;
    final previous = notifications[index - 1].createdAt;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'EVENT_APPROVED':
        return Icons.check_circle;
      case 'EVENT_REJECTED':
        return Icons.cancel;
      case 'REGISTRATION_APPROVED':
        return Icons.how_to_reg;
      case 'REGISTRATION_REJECTED':
        return Icons.person_off;
      case 'EVENT_REMINDER':
        return Icons.alarm;
      case 'EVENT_UPDATE':
        return Icons.update;
      case 'NEW_FOLLOWER':
        return Icons.person_add;
      case 'QUESTION_ANSWERED':
        return Icons.question_answer;
      case 'BROADCAST':
        return Icons.campaign;
      case 'EVENT_CREATED':
        return Icons.event_available;
      case 'NEW_REGISTRATION':
        return Icons.person_add_alt_1;
      case 'NEW_QUESTION':
        return Icons.help_outline;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'EVENT_APPROVED':
      case 'REGISTRATION_APPROVED':
        return const Color(0xFF22C55E);
      case 'EVENT_REJECTED':
      case 'REGISTRATION_REJECTED':
        return const Color(0xFFEF4444);
      case 'EVENT_REMINDER':
        return const Color(0xFFF97316);
      case 'NEW_FOLLOWER':
        return const Color(0xFF8B5CF6);
      case 'QUESTION_ANSWERED':
      case 'NEW_QUESTION':
        return const Color(0xFF0EA5E9);
      case 'BROADCAST':
        return const Color(0xFFEAB308);
      case 'EVENT_CREATED':
      case 'NEW_REGISTRATION':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final hasUnread = state.notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            // LUMA Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    Colors.white.withValues(alpha: 0.9),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'LUMA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: AppColors.primary,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'System Notifications',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () async {
                final success = await ref
                    .read(notificationsProvider.notifier)
                    .markAllAsRead();
                if (success) {
                  ref.read(unreadNotificationCountProvider.notifier).setZero();
                }
              },
              child: const Text(
                'Read all',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: state.notifications.isEmpty && state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationsList(state),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your notifications will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(NotificationsState state) {
    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: state.notifications.length + (state.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            );
          }

          final notification = state.notifications[index];
          final showDateHeader =
              _shouldShowDateHeader(index, state.notifications);

          return Column(
            children: [
              if (showDateHeader) _buildDateHeader(notification.createdAt),
              _NotificationBubble(
                notification: notification,
                timeText: _formatTime(notification.createdAt),
                icon: _getNotificationIcon(notification.type),
                iconColor: _getNotificationColor(notification.type),
                onTap: () async {
                  if (!notification.isRead) {
                    final success = await ref
                        .read(notificationsProvider.notifier)
                        .markAsRead(notification.id);
                    if (success) {
                      ref
                          .read(unreadNotificationCountProvider.notifier)
                          .decrement();
                    }
                  }

                  // If NEW_QUESTION with senderId, open chat with the sender
                  if (notification.canReply && notification.senderId != null) {
                    if (mounted) {
                      _openChatWithUser(notification.senderId!);
                    }
                  } else if (notification.relatedEventId != null) {
                    if (mounted) {
                      context.push('/event/${notification.relatedEventId}');
                    }
                  }
                },
                onReply: notification.canReply
                    ? () => _openChatWithUser(notification.senderId!)
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateHeader(DateTime dateTime) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.grey[400]?.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateHeader(dateTime),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBubble extends StatelessWidget {
  const _NotificationBubble({
    required this.notification,
    required this.timeText,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.onReply,
  });

  final AppNotification notification;
  final String timeText;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LUMA Avatar
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.7),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 18,
            ),
          ),

          // Message bubble
          Flexible(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnread
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                      border: isUnread
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1)
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon and title row
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 16, color: iconColor),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Body
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.3,
                          ),
                        ),
                        // Reply button for questions
                        if (onReply != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: onReply,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.reply,
                                      size: 14, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Reply',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // View event link
                        if (notification.relatedEventId != null &&
                            onReply == null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event,
                                  size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'View Event',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_forward_ios,
                                  size: 10, color: AppColors.primary),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Time
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4),
                    child: Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
