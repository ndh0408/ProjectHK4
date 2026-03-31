import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/conversation.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../main/presentation/screens/main_shell.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';

final conversationsProvider = StateNotifierProvider.autoDispose<
    ConversationsNotifier, ConversationsState>((ref) {
  final user = ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  return ConversationsNotifier(api, isLoggedIn: user != null);
});

final unreadMessageCountProvider = StateNotifierProvider.autoDispose<
    UnreadMessageCountNotifier, AsyncValue<int>>((ref) {
  final user = ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  return UnreadMessageCountNotifier(api, user != null);
});

class UnreadMessageCountNotifier extends StateNotifier<AsyncValue<int>> {
  UnreadMessageCountNotifier(this._api, bool isLoggedIn)
      : super(const AsyncValue.data(0)) {
    if (isLoggedIn) {
      loadCount();
    }
  }

  final ApiService _api;

  Future<void> loadCount() async {
    try {
      final count = await _api.getUnreadMessageCount();
      if (mounted) {
        state = AsyncValue.data(count);
      }
    } catch (e) {
      if (mounted) {
        state = const AsyncValue.data(0);
      }
    }
  }

  void decrement() {
    state.whenData((count) {
      if (count > 0) {
        state = AsyncValue.data(count - 1);
      }
    });
  }

  void setZero() {
    state = const AsyncValue.data(0);
  }
}

class ConversationsState {
  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  ConversationsState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  ConversationsNotifier(this._api, {this.isLoggedIn = false})
      : super(const ConversationsState());

  final ApiService _api;
  final bool isLoggedIn;

  Future<void> loadConversations({bool refresh = false}) async {
    if (!isLoggedIn) return;
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 0 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.getConversations(page: page);
      final newConversations = refresh
          ? response.content
          : [...state.conversations, ...response.content];

      if (mounted) {
        state = state.copyWith(
          conversations: newConversations,
          isLoading: false,
          hasMore: response.hasMore,
          currentPage: response.number + 1,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load conversations',
        );
      }
    }
  }

  Future<void> refresh() async {
    await loadConversations(refresh: true);
  }

  Future<bool> deleteConversation(String conversationId) async {
    try {
      await _api.deleteConversation(conversationId);
      if (mounted) {
        state = state.copyWith(
          conversations: state.conversations
              .where((c) => c.id != conversationId)
              .toList(),
        );
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      return false;
    }
  }
}

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
      ref.read(conversationsProvider.notifier).loadConversations(refresh: true);
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
      ref.read(conversationsProvider.notifier).loadConversations();
    }
  }

  String _formatTime(DateTime? dateTime) {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final notificationsState = ref.watch(notificationsProvider);

    debugPrint('=== ConversationsScreen Debug ===');
    debugPrint('Conversations count: ${state.conversations.length}');
    debugPrint('Conversations isLoading: ${state.isLoading}');
    debugPrint('Conversations error: ${state.error}');
    debugPrint('Notifications count: ${notificationsState.notifications.length}');
    debugPrint('Notifications isLoading: ${notificationsState.isLoading}');
    debugPrint('Notifications error: ${notificationsState.error}');

    final latestNotification = notificationsState.notifications.isNotEmpty
        ? notificationsState.notifications.first
        : null;

    debugPrint('Latest notification: ${latestNotification?.title}');

    if (state.conversations.isEmpty && state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(conversationsProvider.notifier).refresh();
        await ref.read(notificationsProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.conversations.length + 1 + (state.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _LumaNotificationsTile(
              unreadCount: unreadNotifications.maybeWhen(
                data: (count) => count,
                orElse: () => 0,
              ),
              lastMessage: latestNotification?.title ?? 'No notifications yet',
              lastMessageTime: latestNotification?.createdAt,
              onTap: () => context.push('/luma-notifications'),
            );
          }

          if (index == state.conversations.length + 1) {
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

          final conversation = state.conversations[index - 1];
          return _ConversationTile(
            conversation: conversation,
            timeText: _formatTime(conversation.lastMessageAt),
            onTap: () {
              context.push('/chat/${conversation.id}', extra: conversation);
            },
          );
        },
      ),
    );
  }
}

class _LumaNotificationsTile extends StatelessWidget {
  const _LumaNotificationsTile({
    required this.unreadCount,
    required this.lastMessage,
    required this.onTap,
    this.lastMessageTime,
  });

  final int unreadCount;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final VoidCallback onTap;

  String _formatTime(DateTime? dateTime) {
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

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 0.5,
            ),
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
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
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
                        child: Row(
                          children: [
                            Text(
                              'LUMA',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    hasUnread ? FontWeight.w700 : FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              hasUnread ? AppColors.primary : Colors.grey[500],
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
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                hasUnread ? Colors.black87 : Colors.grey[600],
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
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
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
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.timeText,
    required this.onTap,
  });

  final Conversation conversation;
  final String timeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 0.5,
            ),
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
                        : Colors.grey[200],
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
                          color:
                              conversation.type == ConversationType.eventGroup
                                  ? AppColors.primary
                                  : Colors.grey[600],
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
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.event,
                        color: Colors.white,
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
                            color: Colors.black87,
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
                              hasUnread ? AppColors.primary : Colors.grey[500],
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
                                hasUnread ? Colors.black87 : Colors.grey[600],
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
                              color: Colors.white,
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
    );
  }
}
