import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../services/websocket_service.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/event_chat_summary.dart';
import '../../../../shared/models/notification.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/presentation/providers/event_chats_provider.dart';
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

String _normalizeEventChatSearch(String value) {
  var normalized = value.toLowerCase().trim();
  const replacements = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  replacements.forEach((ascii, accentedChars) {
    for (final char in accentedChars.split('')) {
      normalized = normalized.replaceAll(char, ascii);
    }
  });

  return normalized;
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
  final _chatSearchController = TextEditingController();
  final _eventChatSearchController = TextEditingController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  bool _showEmojiPicker = false;
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedEventId;
  String _chatSearchQuery = '';
  String _eventChatSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(conversationsProvider.notifier).loadConversations(refresh: true);
      ref.read(notificationsProvider.notifier).loadNotifications(refresh: true);
      ref.read(eventChatsProvider.notifier).load();
    });
  }

  void _onTabChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    _messageController.dispose();
    _chatSearchController.dispose();
    _eventChatSearchController.dispose();
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

    // Push new-message events into both conversation lists (direct + event
    // groups) and the global unread badge, without any API round-trip.
    ref.listen<AsyncValue<ChatEvent>>(chatEventStreamProvider, (_, next) {
      next.whenData((event) {
        if (event.type != ChatEventType.newMessage) return;
        final payload = event.message;
        final conversationId = event.conversationId;
        if (payload == null || conversationId == null) return;

        final currentUserId = ref.read(currentUserProvider)?.id;
        final senderId = (payload['sender'] as Map<String, dynamic>?)?['id']
            as String?;
        final isOwnMessage =
            senderId != null && senderId == currentUserId;

        final typeStr = payload['type'] as String?;
        String? preview = payload['content'] as String?;
        if (typeStr == 'IMAGE') preview = 'Sent an image';
        if (typeStr == 'FILE') preview = 'Sent a file';

        DateTime? createdAt;
        final createdStr = payload['createdAt'] as String?;
        if (createdStr != null) createdAt = DateTime.tryParse(createdStr);

        final messageId = payload['id'] as String?;

        // Apply to both lists; each no-ops if the conversation isn't there.
        final appliedDirect = ref
            .read(conversationsProvider.notifier)
            .applyNewMessage(
              conversationId: conversationId,
              content: preview,
              timestamp: createdAt,
              incrementUnread: !isOwnMessage,
              messageId: messageId,
            );
        final appliedEvent = ref
            .read(eventChatsProvider.notifier)
            .applyNewMessage(
              conversationId: conversationId,
              content: preview,
              timestamp: createdAt,
              incrementUnread: !isOwnMessage,
              messageId: messageId,
            );

        // Only bump the global unread badge once per message, even if the
        // conversation is in both lists (shouldn't happen, but safe).
        if (!isOwnMessage && (appliedDirect || appliedEvent)) {
          ref.read(unreadMessageCountProvider.notifier).increment();
        }
      });
    });

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
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.forum, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.eventChatsTab,
                          style: const TextStyle(fontSize: 13),
                        ),
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
                _buildEventChatsTab(),
              ],
            ),
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
    final normalizedQuery = _normalizeEventChatSearch(_chatSearchQuery);
    final hasData = userQuestionGroups.isNotEmpty ||
        conversationsState.conversations.isNotEmpty;
    final filteredQuestionEntries = normalizedQuery.isEmpty
        ? userQuestionGroups.entries.toList()
        : userQuestionGroups.entries.where((entry) {
            final notifications = entry.value;
            final latestNotification = notifications.first;
            final haystack = _normalizeEventChatSearch([
              latestNotification.senderName ?? 'User',
              latestNotification.body,
              latestNotification.relatedEventId,
            ].whereType<String>().join(' '));
            return haystack.contains(normalizedQuery);
          }).toList();
    final filteredConversations = normalizedQuery.isEmpty
        ? conversationsState.conversations
        : conversationsState.conversations.where((conversation) {
            final haystack = _normalizeEventChatSearch([
              conversation.displayName,
              conversation.lastMessageContent,
              conversation.eventTitle,
              conversation.participants
                      ?.map((participant) => participant.fullName)
                      .join(' ') ??
                  '',
            ].whereType<String>().join(' '));
            return haystack.contains(normalizedQuery);
          }).toList();
    final hasFilteredData =
        filteredQuestionEntries.isNotEmpty || filteredConversations.isNotEmpty;

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
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _chatSearchController,
                  onChanged: (value) {
                    setState(() => _chatSearchQuery = value);
                  },
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchInChat,
                    hintStyle: TextStyle(color: AppColors.textLight),
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.textLight),
                    suffixIcon: _chatSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _chatSearchController.clear();
                              setState(() => _chatSearchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                if (_chatSearchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${filteredQuestionEntries.length + filteredConversations.length} kết quả',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!hasFilteredData)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.45,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 46,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Không tìm thấy cuộc trò chuyện phù hợp',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Thử tên người dùng hoặc nội dung tin nhắn khác',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ...filteredQuestionEntries.map((entry) {
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

          ...filteredConversations.map((conversation) {
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

  Widget _buildEventChatsTab() {
    final state = ref.watch(eventChatsProvider);
    final l10n = AppLocalizations.of(context)!;
    final normalizedQuery = _normalizeEventChatSearch(_eventChatSearchQuery);
    final filteredChats = normalizedQuery.isEmpty
        ? state.chats
        : state.chats.where((chat) {
            final haystack = _normalizeEventChatSearch([
              chat.eventTitle,
              chat.venue,
              chat.lastMessageContent,
              chat.joined ? 'joined da tham gia' : 'join tham gia',
              chat.closed ? 'closed da dong' : 'open dang mo',
            ].whereType<String>().join(' '));
            return haystack.contains(normalizedQuery);
          }).toList();

    if (state.isLoading && state.chats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.chats.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(eventChatsProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildEmptyState(
                l10n.eventChatsEmptyHint,
                Icons.forum_outlined,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.divider, width: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.eventChatsSubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _eventChatSearchController,
                onChanged: (value) {
                  setState(() => _eventChatSearchQuery = value);
                },
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.searchEventChatsHint,
                  hintStyle: TextStyle(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
                  suffixIcon: _eventChatSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _eventChatSearchController.clear();
                            setState(() => _eventChatSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_eventChatSearchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${filteredChats.length}/${state.chats.length} nhóm',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(eventChatsProvider.notifier).refresh(),
            child: filteredChats.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.48,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 48,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.eventChatsSearchEmpty,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              l10n.eventChatsSearchEmptySubtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: filteredChats.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      final isJoining = state.joiningEventId == chat.eventId;
                      return _EventChatTile(
                        chat: chat,
                        isJoining: isJoining,
                        onJoin: () => _joinEventChat(chat),
                        onOpen: () => _openEventChat(chat),
                        onLeave: () => _confirmLeaveEventChat(chat),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _joinEventChat(EventChatSummary chat) async {
    final l10n = AppLocalizations.of(context)!;
    if (chat.closed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventChatClosedBanner)),
      );
      return;
    }
    final updated = await ref.read(eventChatsProvider.notifier).join(chat.eventId);
    if (!mounted) return;
    if (updated == null) {
      final err = ref.read(eventChatsProvider).error ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.isEmpty ? l10n.failedToJoinChat : '${l10n.failedToJoinChat}: $err'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.joinedEventChat),
        backgroundColor: AppColors.success,
      ),
    );
    if (updated.conversationId != null) {
      context.push('/chat/${updated.conversationId}');
    }
  }

  Future<void> _openEventChat(EventChatSummary chat) async {
    final l10n = AppLocalizations.of(context)!;
    if (!chat.joined) {
      await _joinEventChat(chat);
      return;
    }
    if (chat.conversationId == null) return;
    if (chat.closed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventChatClosedBanner)),
      );
    }
    try {
      final api = ref.read(apiServiceProvider);
      final conversation = await api.getEventChat(chat.eventId);
      if (!mounted) return;
      context.push('/chat/${conversation.id}', extra: conversation);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.failedToJoinChat}: ${ErrorUtils.extractMessage(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _confirmLeaveEventChat(EventChatSummary chat) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveEventChatTitle),
        content: Text(l10n.leaveEventChatMessage(chat.eventTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await ref.read(eventChatsProvider.notifier).leave(chat.eventId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.leftEventChat),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      final err = ref.read(eventChatsProvider).error ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.isEmpty ? l10n.failedToLeaveChat : '${l10n.failedToLeaveChat}: $err'),
          backgroundColor: AppColors.error,
        ),
      );
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

class _EventChatTile extends StatelessWidget {
  const _EventChatTile({
    required this.chat,
    required this.isJoining,
    required this.onJoin,
    required this.onOpen,
    required this.onLeave,
  });

  final EventChatSummary chat;
  final bool isJoining;
  final VoidCallback onJoin;
  final VoidCallback onOpen;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final closed = chat.closed;
    final joined = chat.joined;
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        onTap: joined && !closed ? onOpen : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        image: chat.eventImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(chat.eventImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: chat.eventImageUrl == null
                          ? const Center(
                              child: Icon(
                                Icons.forum,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            )
                          : null,
                    ),
                    if (chat.unreadCount > 0 && joined && !closed)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: Text(
                            chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.w700,
                            ),
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
                              chat.eventTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (joined && !closed) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.check,
                                  size: 12, color: AppColors.success),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      _buildSubtitle(l10n),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildTrailing(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(AppLocalizations l10n) {
    if (chat.closed) {
      return Row(
        children: [
          const Icon(Icons.lock_clock, size: 13, color: AppColors.textLight),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              chat.closedAt != null
                  ? '${l10n.eventChatClosedSubtitle} · ${_formatTimeHelper(chat.closedAt)}'
                  : l10n.eventChatClosedSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (chat.joined &&
        chat.lastMessageContent != null &&
        chat.lastMessageContent!.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessageContent!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (chat.lastMessageAt != null) ...[
            const SizedBox(width: 4),
            Text(
              _formatTimeHelper(chat.lastMessageAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ],
      );
    }

    final subtitleText = chat.joined
        ? l10n.noMessagesYetTapToChat
        : l10n.notJoinedMembers(chat.participantCount);
    return Row(
      children: [
        Icon(
          chat.joined ? Icons.chat_bubble_outline : Icons.person_add_alt_1,
          size: 13,
          color: AppColors.textLight,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            subtitleText,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing(AppLocalizations l10n) {
    if (chat.closed) {
      return Chip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text(l10n.eventChatClosedLabel,
            style: const TextStyle(fontSize: 11)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      );
    }

    if (!chat.joined) {
      return SizedBox(
        height: 34,
        child: FilledButton.tonalIcon(
          onPressed: isJoining ? null : onJoin,
          icon: isJoining
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add, size: 16),
          label: Text(l10n.joinEventChat, style: const TextStyle(fontSize: 13)),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onSelected: (value) {
        if (value == 'open') {
          onOpen();
        } else if (value == 'leave') {
          onLeave();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'open', child: Text(l10n.openChat)),
        PopupMenuItem(value: 'leave', child: Text(l10n.leaveChat)),
      ],
    );
  }
}
