import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../../services/notification_service.dart' show notificationStreamProvider;
import '../../../../shared/models/notification.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../main/presentation/screens/main_shell.dart';

final notificationsProvider = StateNotifierProvider.autoDispose<
    NotificationsNotifier, NotificationsState>((ref) {
  final user = ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  final notifier = NotificationsNotifier(api, ref, isLoggedIn: user != null);

  final subscription = ref.listen<AsyncValue<AppNotification>>(
    notificationStreamProvider,
    (previous, next) {
      next.whenData((notification) {
        notifier.addNotification(notification);
      });
    },
  );

  ref.onDispose(() {
    subscription.close();
  });

  return notifier;
});

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._api, this._ref, {this.isLoggedIn = false})
      : super(const NotificationsState());

  final ApiService _api;
  final Ref _ref;
  final bool isLoggedIn;

  void addNotification(AppNotification notification) {
    final exists = state.notifications.any((n) => n.id == notification.id);
    if (exists) return;

    state = state.copyWith(
      notifications: [notification, ...state.notifications],
    );
    debugPrint('WebSocket: Added new notification ${notification.id}');
  }

  Future<void> loadNotifications({bool refresh = false}) async {
    debugPrint('=== loadNotifications called ===');
    debugPrint('isLoggedIn: $isLoggedIn');

    if (!isLoggedIn) {
      debugPrint('Not logged in, skipping load');
      return;
    }
    if (state.isLoading) {
      debugPrint('Already loading, skipping');
      return;
    }
    if (!refresh && !state.hasMore) {
      debugPrint('No more data to load');
      return;
    }

    final page = refresh ? 0 : state.currentPage;
    debugPrint('Loading page: $page');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.getNotifications(page: page);
      debugPrint('Got ${response.content.length} notifications');

      final newNotifications = refresh
          ? response.content
          : [...state.notifications, ...response.content];

      if (mounted) {
        state = state.copyWith(
          notifications: newNotifications,
          isLoading: false,
          hasMore: response.hasMore,
          currentPage: response.number + 1,
        );
        debugPrint('State updated with ${newNotifications.length} notifications');
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load notifications',
        );
      }
    }
  }

  Future<bool> markAsRead(String id) async {
    try {
      await _api.markNotificationAsRead(id);
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == id) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      await _api.markAllNotificationsAsRead();
      state = state.copyWith(
        notifications:
            state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    await loadNotifications(refresh: true);
  }

  void removeNotificationsBySenderId(String senderId) {
    state = state.copyWith(
      notifications: state.notifications
          .where((n) => n.senderId != senderId)
          .toList(),
    );
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _unawaited(
      Future.microtask(() async {
        await ref
            .read(notificationsProvider.notifier)
            .loadNotifications(refresh: true);
      }),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _unawaited(ref.read(notificationsProvider.notifier).loadNotifications());
    }
  }

  void _unawaited(Future<void>? future) {}

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
    if (diff < 7) return '${diff} days ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
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
        return const Color(0xFF0EA5E9);
      case 'BROADCAST':
        return const Color(0xFFEAB308);
      default:
        return AppColors.primary;
    }
  }

  bool _shouldShowDateHeader(int index, List<AppNotification> notifications) {
    if (index == 0) return true;
    final current = notifications[index].createdAt;
    final previous = notifications[index - 1].createdAt;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final hasUnread = state.notifications.any((n) => !n.isRead) ||
        unreadCountAsync.maybeWhen(
            data: (count) => count > 0, orElse: () => false);

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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), width: 2),
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
                  const Text(
                    'LUMA Notifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (hasUnread)
            IconButton(
              onPressed: () async {
                final success = await ref
                    .read(notificationsProvider.notifier)
                    .markAllAsRead();
                if (success) {
                  ref.read(unreadNotificationCountProvider.notifier).setZero();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    ref
                        .read(unreadNotificationCountProvider.notifier)
                        .loadCount();
                  });
                }
              },
              icon: const Icon(Icons.done_all, size: 22),
              tooltip: 'Mark all as read',
            ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, size: 22),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: state.notifications.isEmpty && !state.isLoading
                  ? _buildEmptyState()
                  : _buildChatMessages(state),
            ),
          ),

          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 40,
                    color: Colors.grey[400],
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
          ),
        ),
      ],
    );
  }

  Widget _buildChatMessages(NotificationsState state) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
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

            _ChatMessageBubble(
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
                    Future.delayed(const Duration(milliseconds: 300), () {
                      ref
                          .read(unreadNotificationCountProvider.notifier)
                          .loadCount();
                    });
                  }
                }
                if (notification.relatedEventId != null) {
                  context.push('/event/${notification.relatedEventId}');
                }
              },
            ),
          ],
        );
      },
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

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Icon(Icons.emoji_emotions_outlined,
                color: Colors.grey[500], size: 26),
            const SizedBox(width: 16),
            Icon(Icons.image_outlined, color: Colors.grey[500], size: 26),
            const SizedBox(width: 12),

            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(19),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notifications are read-only',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),
            Icon(Icons.more_horiz, color: Colors.grey[500], size: 26),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.notification,
    required this.timeText,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final AppNotification notification;
  final String timeText;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
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

                        ..._buildMessageContent(notification.body),

                        if (notification.relatedEventId != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Text(
                                  'View Event',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (notification.isRead) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.done_all,
                          size: 15,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 50),
        ],
      ),
    );
  }

  List<Widget> _buildMessageContent(String body) {
    if (body.contains('Q:') && body.contains('A:')) {
      final parts = body.split('\n\n');
      final widgets = <Widget>[];

      for (final part in parts) {
        if (part.startsWith('Q:')) {
          widgets.add(
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Your Question',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    part.substring(2).trim(),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
          );
        } else if (part.startsWith('A:')) {
          widgets.add(
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 14, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 4),
                      const Text(
                        'Answer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    part.substring(2).trim(),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                ],
              ),
            ),
          );
        } else if (part.isNotEmpty) {
          widgets.add(
            Text(
              part,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          );
        }
      }

      return widgets;
    }

    return [
      Text(
        body,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey[700],
          height: 1.4,
        ),
      ),
    ];
  }
}
