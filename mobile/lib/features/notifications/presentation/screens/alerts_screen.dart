import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/event_buddy.dart';
import '../../../../shared/models/notification.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/presentation/screens/conversations_screen.dart';
import '../../../main/presentation/screens/main_shell.dart';
import 'notifications_screen.dart';

String _formatTimeHelper(DateTime? dateTime) {
  if (dateTime == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
  final diff = today.difference(date).inDays;

  if (diff == 0) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '${diff}d ago';
  return '${dateTime.day}/${dateTime.month}';
}

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  bool _showEmojiPicker = false;
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedEventId;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(conversationsProvider.notifier).loadConversations(refresh: true);
      ref.read(notificationsProvider.notifier).loadNotifications(refresh: true);
      ref.read(eventBuddiesProvider.notifier).loadBuddies();
    });
  }

  void _onTabChanged() {
    if (_tabController.index != 2 && _isSelectionMode) {
      setState(() => _isSelectionMode = false);
      ref.read(eventBuddiesProvider.notifier).clearSelection();
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(notificationsProvider.notifier).loadNotifications();
    }
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

  bool _isChatMessage(AppNotification notification) {
    final chatMessageTypes = [
      'NEW_QUESTION',
      'NEW_REGISTRATION',
      'REGISTRATION_CANCELLED',
      'REPLY_MESSAGE',
    ];
    return chatMessageTypes.contains(notification.type) && notification.senderId != null;
  }

  Map<String, List<AppNotification>> _groupChatMessages(
      List<AppNotification> notifications, String? currentUserId) {
    final Map<String, List<AppNotification>> grouped = {};

    final Set<String> otherUserIds = {};
    for (final notification in notifications) {
      if (_isChatMessage(notification) && notification.senderId != currentUserId) {
        otherUserIds.add(notification.senderId!);
      }
    }

    for (final notification in notifications) {
      if (_isChatMessage(notification)) {
        String? otherUserId;
        if (notification.senderId == currentUserId) {
          if (notification.userId.isNotEmpty &&
              notification.userId != currentUserId &&
              otherUserIds.contains(notification.userId)) {
            otherUserId = notification.userId;
          }
        } else {
          otherUserId = notification.senderId!;
        }

        if (otherUserId != null) {
          grouped.putIfAbsent(otherUserId, () => []);
          grouped[otherUserId]!.add(notification);
        }
      }
    }
    return grouped;
  }

  List<AppNotification> _getSystemNotifications(
      List<AppNotification> notifications) {
    return notifications.where((n) => !_isChatMessage(n)).toList();
  }

  List<AppNotification> _getChatMessages(
      List<AppNotification> notifications, String? userId) {
    if (userId == null) return [];
    final currentUserId = ref.read(currentUserProvider)?.id;

    return notifications.where((n) {
      if (!_isChatMessage(n)) return false;

      if (n.senderId == userId) return true;

      if (n.senderId == currentUserId && n.userId == userId) {
        return true;
      }

      return false;
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
        return AppColors.success;
      case 'EVENT_REJECTED':
      case 'REGISTRATION_REJECTED':
        return AppColors.error;
      case 'EVENT_REMINDER':
        return AppColors.warning;
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

  Future<void> _openChatWithUser(String userId, String userName, {String? eventId}) async {
    setState(() {
      _selectedUserId = userId;
      _selectedUserName = userName;
      _selectedEventId = eventId;
      _tabController.animateTo(1);
    });
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUserId = null;
      _selectedUserName = null;
      _selectedEventId = null;
    });
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, emoji.emoji);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.emoji.length),
    );
  }

  Future<void> _pickAndSendImage() async {
    if (_selectedUserId == null) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image == null) return;

      final api = ref.read(apiServiceProvider);
      final conversation = await api.getDirectChat(_selectedUserId!);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload coming soon!')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_selectedUserId == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    try {
      final api = ref.read(apiServiceProvider);
      await api.sendReplyNotification(
        recipientId: _selectedUserId!,
        message: text,
        eventId: _selectedEventId,
      );

      _messageController.clear();
      setState(() => _showEmojiPicker = false);

      final sentNotification = AppNotification(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: _selectedUserId!,
        title: 'Reply from ${currentUser.fullName}',
        body: text,
        isRead: true,
        createdAt: DateTime.now(),
        type: 'REPLY_MESSAGE',
        relatedEventId: _selectedEventId,
        senderId: currentUser.id,
        senderName: currentUser.fullName,
      );
      ref.read(notificationsProvider.notifier).addNotification(sentNotification);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final unreadMessages = ref.watch(unreadMessageCountProvider);
    final notificationsState = ref.watch(notificationsProvider);
    final conversationsState = ref.watch(conversationsProvider);

    final totalUnread = (unreadNotifications.maybeWhen(
          data: (count) => count,
          orElse: () => 0,
        )) +
        (unreadMessages.maybeWhen(
          data: (count) => count,
          orElse: () => 0,
        ));

    final systemNotifications =
        _getSystemNotifications(notificationsState.notifications);

    final lumaUnreadCount = systemNotifications.where((n) => !n.isRead).length;
    final chatMessagesUnreadCount = notificationsState.notifications
        .where((n) => _isChatMessage(n) && !n.isRead)
        .length;
    final chatsUnreadCount = chatMessagesUnreadCount +
        (unreadMessages.maybeWhen(data: (count) => count, orElse: () => 0));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () {
            if (_selectedUserId != null) {
              _clearSelectedUser();
            } else {
              context.pop();
            }
          },
        ),
        title: _selectedUserId != null
            ? Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _selectedUserName?.isNotEmpty == true
                            ? _selectedUserName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedUserName ?? 'User',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Question & Answer',
                          style: const TextStyle(fontSize: 12, color: AppColors.textOnPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const Text(
                    'Messages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  if (totalUnread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        totalUnread > 99 ? '99+' : totalUnread.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        bottom: _selectedUserId == null
            ? TabBar(
                controller: _tabController,
                indicatorColor: AppColors.textOnPrimary,
                indicatorWeight: 3,
                labelColor: AppColors.textOnPrimary,
                unselectedLabelColor:
                    AppColors.textOnPrimary.withValues(alpha: 0.6),
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.notifications, size: 16),
                        const SizedBox(width: 4),
                        const Text('LUMA', style: TextStyle(fontSize: 13)),
                        if (lumaUnreadCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              lumaUnreadCount > 99
                                  ? '99+'
                                  : lumaUnreadCount.toString(),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chat, size: 16),
                        const SizedBox(width: 4),
                        Text(AppLocalizations.of(context)!.chat, style: const TextStyle(fontSize: 13)),
                        if (chatsUnreadCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              chatsUnreadCount > 99
                                  ? '99+'
                                  : chatsUnreadCount.toString(),
                              style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, size: 16),
                        SizedBox(width: 4),
                        Text('Buddies', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              )
            : null,
        actions: [
          if (_selectedUserId == null) ...[
            IconButton(
              onPressed: () => context.push('/waitlist-offers'),
              icon: const Icon(Icons.local_offer, size: 22),
              tooltip: 'Waitlist Offers',
            ),
            IconButton(
              onPressed: () async {
                final success = await ref
                    .read(notificationsProvider.notifier)
                    .markAllAsRead();
                if (success) {
                  ref.read(unreadNotificationCountProvider.notifier).setZero();
                }
              },
              icon: const Icon(Icons.done_all, size: 22),
              tooltip: 'Mark all as read',
            ),
          ],
        ],
      ),
      body: _selectedUserId != null
          ? _buildUserChatView(notificationsState)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildLumaNotificationsTab(systemNotifications, notificationsState),
                _buildChatsTab(
                    _groupChatMessages(notificationsState.notifications, ref.watch(currentUserProvider)?.id),
                    conversationsState,
                    notificationsState),
                _buildEventBuddiesTab(),
              ],
            ),
      floatingActionButton: _tabController.index == 2 && _isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: ref.watch(eventBuddiesProvider).selectedBuddies.isNotEmpty
                  ? _showCreateGroupDialog
                  : null,
              backgroundColor: ref.watch(eventBuddiesProvider).selectedBuddies.isNotEmpty
                  ? AppColors.primary
                  : AppColors.textLight,
              icon: const Icon(Icons.group_add, color: AppColors.textOnPrimary),
              label: Text(
                'Create Group (${ref.watch(eventBuddiesProvider).selectedBuddies.length})',
                style: const TextStyle(color: AppColors.textOnPrimary),
              ),
            )
          : null,
    );
  }

  Widget _buildLumaNotificationsTab(
      List<AppNotification> notifications, NotificationsState state) {
    if (notifications.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notifications.isEmpty) {
      return _buildEmptyState('No system notifications', Icons.notifications_off);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: notifications.length + (state.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == notifications.length) {
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

          final notification = notifications[index];
          final showDateHeader = _shouldShowDateHeader(index, notifications);

          return Column(
            children: [
              if (showDateHeader) _buildDateHeader(notification.createdAt),
              _NotificationBubble(
                notification: notification,
                timeText: _formatTimeHelper(notification.createdAt),
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
                  if (notification.relatedEventId != null) {
                    context.push('/event/${notification.relatedEventId}');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChatsTab(
    Map<String, List<AppNotification>> userQuestionGroups,
    ConversationsState conversationsState,
    NotificationsState notificationsState,
  ) {
    final hasData = userQuestionGroups.isNotEmpty ||
        conversationsState.conversations.isNotEmpty;

    if (!hasData && (conversationsState.isLoading || notificationsState.isLoading)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!hasData) {
      return _buildEmptyState('No chats yet', Icons.chat_bubble_outline);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(conversationsProvider.notifier).refresh();
        await ref.read(notificationsProvider.notifier).refresh();
      },
      child: ListView(
        children: [
          ...userQuestionGroups.entries.map((entry) {
            final senderId = entry.key;
            final notifications = entry.value;
            final latestNotification = notifications.first;
            final unreadCount = notifications.where((n) => !n.isRead).length;

            return _UserChatTile(
              senderId: senderId,
              senderName: latestNotification.senderName ?? 'User',
              lastMessage: latestNotification.body,
              lastMessageTime: latestNotification.createdAt,
              unreadCount: unreadCount,
              notificationType: latestNotification.type,
              onTap: () => _openChatWithUser(
                senderId,
                latestNotification.senderName ?? 'User',
                eventId: latestNotification.relatedEventId,
              ),
              onDelete: () {
                ref.read(notificationsProvider.notifier).removeNotificationsBySenderId(senderId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat deleted')),
                );
              },
            );
          }),

          ...conversationsState.conversations.map((conversation) {
            return _ConversationTile(
              conversation: conversation,
              timeText: _formatTimeHelper(conversation.lastMessageAt),
              onTap: () {
                context.push('/chat/${conversation.id}', extra: conversation);
              },
              onDelete: () async {
                final success = await ref
                    .read(conversationsProvider.notifier)
                    .deleteConversation(conversation.id);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Conversation deleted')),
                  );
                }
              },
            );
          }),

          if (conversationsState.isLoading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserChatView(NotificationsState state) {
    final chatMessages =
        _getChatMessages(state.notifications, _selectedUserId);
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_showEmojiPicker) {
                setState(() => _showEmojiPicker = false);
              }
            },
            child: chatMessages.isEmpty
                ? _buildEmptyState('No messages yet', Icons.chat_bubble_outline)
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(notificationsProvider.notifier).refresh(),
                    child: ListView.builder(
                      reverse: true,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: chatMessages.length,
                      itemBuilder: (context, index) {
                        final notification =
                            chatMessages[chatMessages.length - 1 - index];
                        final isSentByMe = notification.senderId == currentUserId;
                        return _ChatMessageBubble(
                          notification: notification,
                          timeText: _formatTimeHelper(notification.createdAt),
                          isSentByMe: isSentByMe,
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
                          },
                        );
                      },
                    ),
                  ),
          ),
        ),

        _buildInputBar(),

        if (_showEmojiPicker) _buildEmojiPicker(),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggleEmojiPicker,
              child: Icon(
                _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                color: _showEmojiPicker ? AppColors.primary : AppColors.textLight,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _pickAndSendImage,
              child: Icon(Icons.image_outlined, color: AppColors.textLight, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  onTap: () {
                    if (_showEmojiPicker) {
                      setState(() => _showEmojiPicker = false);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Type your answer...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: AppColors.textOnPrimary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: _onEmojiSelected,
        config: Config(
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: 28 *
                (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                    ? 1.2
                    : 1.0),
          ),
          skinToneConfig: const SkinToneConfig(),
          categoryViewConfig: CategoryViewConfig(
            initCategory: Category.RECENT,
            indicatorColor: AppColors.primary,
            iconColorSelected: AppColors.primary,
          ),
          bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
          searchViewConfig: const SearchViewConfig(),
        ),
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
            color: AppColors.textLight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateHeader(dateTime),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, size: 40, color: AppColors.textLight),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBuddiesTab() {
    final state = ref.watch(eventBuddiesProvider);

    if (state.isLoading && state.buddies.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.buddies.isEmpty) {
      return _buildEmptyState(
        'No event buddies yet',
        Icons.people_outline,
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _isSelectionMode
                      ? '${state.selectedBuddies.length} selected'
                      : 'People who joined same events as you',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: _isSelectionMode ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isSelectionMode = !_isSelectionMode;
                    if (!_isSelectionMode) {
                      ref.read(eventBuddiesProvider.notifier).clearSelection();
                    }
                  });
                },
                icon: Icon(
                  _isSelectionMode ? Icons.close : Icons.group_add,
                  size: 18,
                  color: _isSelectionMode ? AppColors.error : AppColors.primary,
                ),
                label: Text(
                  _isSelectionMode ? 'Cancel' : 'Create Group',
                  style: TextStyle(
                    fontSize: 13,
                    color: _isSelectionMode ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(eventBuddiesProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.buddies.length,
              itemBuilder: (context, index) {
                final buddy = state.buddies[index];
                final isSelected = state.selectedBuddies.any((b) => b.userId == buddy.userId);

                return _BuddyTile(
                  buddy: buddy,
                  isSelectionMode: _isSelectionMode,
                  isSelected: isSelected,
                  onTap: () {
                    if (_isSelectionMode) {
                      ref.read(eventBuddiesProvider.notifier).toggleBuddySelection(buddy);
                    } else {
                      _startDirectChat(buddy);
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      setState(() => _isSelectionMode = true);
                      ref.read(eventBuddiesProvider.notifier).toggleBuddySelection(buddy);
                    }
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _startDirectChat(EventBuddy buddy) async {
    try {
      final api = ref.read(apiServiceProvider);
      final conversation = await api.getDirectChat(buddy.userId);

      if (mounted) {
        context.push('/chat/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCreateGroupDialog() {
    final selectedBuddies = ref.read(eventBuddiesProvider).selectedBuddies;
    if (selectedBuddies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 buddy to create a group')),
      );
      return;
    }

    final groupNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group Chat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              'Members (${selectedBuddies.length}):',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedBuddies.map((buddy) {
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundImage: buddy.avatarUrl != null
                        ? NetworkImage(buddy.avatarUrl!)
                        : null,
                    child: buddy.avatarUrl == null
                        ? Text(
                            buddy.fullName.isNotEmpty
                                ? buddy.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  label: Text(
                    buddy.fullName,
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final groupName = groupNameController.text.trim();
              if (groupName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a group name')),
                );
                return;
              }
              Navigator.pop(context);
              await _createGroupChat(groupName, selectedBuddies);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createGroupChat(String groupName, List<EventBuddy> members) async {
    try {
      final api = ref.read(apiServiceProvider);
      final memberIds = members.map((b) => b.userId).toList();

      final conversation = await api.createGroupChat(
        name: groupName,
        participantIds: memberIds,
      );

      ref.read(eventBuddiesProvider.notifier).clearSelection();
      setState(() => _isSelectionMode = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "$groupName" created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.push('/chat/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _NotificationBubble extends StatelessWidget {
  const _NotificationBubble({
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              color: AppColors.surface,
              size: 18,
            ),
          ),
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
                          : AppColors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.06),
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
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notification.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        if (notification.relatedEventId != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event, size: 14, color: AppColors.primary),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4),
                    child: Text(
                      timeText,
                      style: TextStyle(fontSize: 11, color: AppColors.textLight),
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

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.notification,
    required this.timeText,
    required this.onTap,
    this.isSentByMe = false,
  });

  final AppNotification notification;
  final String timeText;
  final VoidCallback onTap;
  final bool isSentByMe;

  IconData get _typeIcon {
    switch (notification.type) {
      case 'NEW_REGISTRATION':
        return Icons.person_add_alt_1;
      case 'REGISTRATION_CANCELLED':
        return Icons.person_remove;
      case 'NEW_QUESTION':
        return Icons.help_outline;
      case 'REPLY_MESSAGE':
        return Icons.reply;
      default:
        return Icons.chat_bubble_outline;
    }
  }

  Color get _typeColor {
    if (isSentByMe) return AppColors.primary;
    switch (notification.type) {
      case 'NEW_REGISTRATION':
        return AppColors.success;
      case 'REGISTRATION_CANCELLED':
        return AppColors.error;
      case 'NEW_QUESTION':
        return const Color(0xFF0EA5E9);
      case 'REPLY_MESSAGE':
        return AppColors.primary;
      default:
        return const Color(0xFF0EA5E9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    if (isSentByMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.surface,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeText,
                          style: TextStyle(fontSize: 11, color: AppColors.textLight),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.done_all, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                notification.senderName?.isNotEmpty == true
                    ? notification.senderName![0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _typeColor,
                ),
              ),
            ),
          ),
          Flexible(
            child: GestureDetector(
              onTap: onTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUnread
                          ? _typeColor.withValues(alpha: 0.1)
                          : AppColors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeText,
                          style: TextStyle(fontSize: 11, color: AppColors.textLight),
                        ),
                        if (notification.isRead) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.done_all, size: 14, color: _typeColor),
                        ],
                      ],
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

class _UserChatTile extends StatelessWidget {
  const _UserChatTile({
    required this.senderId,
    required this.senderName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.notificationType,
    required this.onTap,
    this.onDelete,
  });

  final String senderId;
  final String senderName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String? notificationType;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  IconData get _typeIcon {
    switch (notificationType) {
      case 'NEW_REGISTRATION':
        return Icons.person_add_alt_1;
      case 'REGISTRATION_CANCELLED':
        return Icons.person_remove;
      case 'NEW_QUESTION':
      default:
        return Icons.help_outline;
    }
  }

  Color get _typeColor {
    switch (notificationType) {
      case 'NEW_REGISTRATION':
        return AppColors.success;
      case 'REGISTRATION_CANCELLED':
        return AppColors.error;
      case 'NEW_QUESTION':
      default:
        return const Color(0xFF0EA5E9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return Dismissible(
      key: Key('user_chat_$senderId'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: AppColors.textOnPrimary),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: const Text('Are you sure you want to delete this chat?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: hasUnread
                ? AppColors.primary.withValues(alpha: 0.05)
                : AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _typeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: _typeColor,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _typeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: Icon(
                      _typeIcon,
                      color: AppColors.surface,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeHelper(lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              hasUnread ? AppColors.primary : AppColors.textLight,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_typeIcon, size: 14, color: _typeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.surface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.timeText,
    required this.onTap,
    this.onDelete,
  });

  final Conversation conversation;
  final String timeText;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return Dismissible(
      key: Key('conversation_${conversation.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(Icons.delete, color: AppColors.textOnPrimary),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Conversation'),
            content: const Text('Are you sure you want to delete this conversation?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => onDelete?.call(),
      child: InkWell(
        onTap: onTap,
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.surface,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: conversation.type == ConversationType.eventGroup
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.divider,
                    shape: BoxShape.circle,
                    image: conversation.displayImage != null
                        ? DecorationImage(
                            image: NetworkImage(conversation.displayImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: conversation.displayImage == null
                      ? Icon(
                          conversation.type == ConversationType.eventGroup
                              ? Icons.groups
                              : Icons.person,
                          color: conversation.type == ConversationType.eventGroup
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 28,
                        )
                      : null,
                ),
                if (conversation.type == ConversationType.eventGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                      child: const Icon(
                        Icons.event,
                        color: AppColors.surface,
                        size: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              hasUnread ? AppColors.primary : AppColors.textLight,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessageContent ?? 'No messages yet',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : conversation.unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.surface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

class _BuddyTile extends StatelessWidget {
  const _BuddyTile({
    required this.buddy,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final EventBuddy buddy;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    image: buddy.avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(buddy.avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: buddy.avatarUrl == null
                      ? Center(
                          child: Text(
                            buddy.fullName.isNotEmpty
                                ? buddy.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : null,
                ),
                if (isSelectionMode)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.textLight,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: AppColors.textOnPrimary,
                              size: 14,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buddy.fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.event,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${buddy.sharedEventsCount} shared event${buddy.sharedEventsCount > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (buddy.displayLatestEventName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      buddy.displayLatestEventName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (!isSelectionMode)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
