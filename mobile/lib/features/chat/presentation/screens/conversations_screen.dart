import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../services/websocket_service.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/models/registration.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../home/presentation/screens/home_screen.dart'; // for myFutureRegistrationsProvider
import '../providers/event_chats_provider.dart';

String? _localizedPreview(BuildContext context, String? raw) {
  if (raw == null) return null;
  final l10n = AppLocalizations.of(context)!;
  switch (raw) {
    case 'Sent an image':
      return l10n.messagePreviewImage;
    case 'Sent a file':
      return l10n.messagePreviewFile;
    case 'This message was deleted':
      return l10n.messageDeletedBody;
  }
  return raw;
}

final conversationsProvider = StateNotifierProvider.autoDispose<
    ConversationsNotifier, ConversationsState>((ref) {
  final user = ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  return ConversationsNotifier(api, isLoggedIn: user != null);
});

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
        // Advanced Messenger Sort: Pinned First, then Newest Message
        final sortedList = [...newConversations];
        sortedList.sort((a, b) {
          if (a.pinned != b.pinned) return b.pinned ? -1 : 1;
          final timeA =
              a.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB =
              b.lastMessageAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return timeB.compareTo(timeA);
        });

        state = state.copyWith(
          conversations: sortedList,
          isLoading: false,
          hasMore: response.hasMore,
          currentPage: response.number + 1,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
            isLoading: false, error: 'Failed to load conversations');
      }
    }
  }

  void markConversationRead(String conversationId) {
    final idx = state.conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) return;
    final updated = state.conversations[idx].copyWith(unreadCount: 0);
    final next = [...state.conversations];
    next[idx] = updated;
    state = state.copyWith(conversations: next);
  }

  Future<void> refresh() async {
    await loadConversations(refresh: true);
  }

  bool applyNewMessage({
    required String conversationId,
    required String? content,
    required DateTime? timestamp,
    required bool incrementUnread,
    String? messageId,
  }) {
    final idx = state.conversations.indexWhere((c) => c.id == conversationId);
    if (idx < 0) return false;
    final current = state.conversations[idx];
    final updated = current.copyWith(
      lastMessageContent: content ?? current.lastMessageContent,
      lastMessageAt: timestamp ?? current.lastMessageAt,
      unreadCount:
          incrementUnread ? current.unreadCount + 1 : current.unreadCount,
    );
    final next = [...state.conversations];
    next.removeAt(idx);
    next.insert(0, updated);
    state = state.copyWith(conversations: next);
    return true;
  }
}

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(conversationsProvider.notifier).loadConversations();
      }
    });
    Future.microtask(() => ref
        .read(conversationsProvider.notifier)
        .loadConversations(refresh: true));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openConversation(Conversation conversation) async {
    await context.push('/chat/${conversation.id}', extra: conversation);
  }

  Future<void> _openJoinedEventConversation({
    required String eventId,
    required ConversationsState state,
  }) async {
    final conversation = state.conversations.cast<Conversation?>().firstWhere(
          (c) => c?.eventId == eventId,
          orElse: () => null,
        );
    if (conversation == null || !mounted) return;
    await _openConversation(conversation);
  }

  Future<void> _joinOrOpenEventGroup({
    required Event event,
    required bool alreadyJoined,
    required ConversationsState conversationsState,
  }) async {
    if (alreadyJoined) {
      await _openJoinedEventConversation(
        eventId: event.id,
        state: conversationsState,
      );
      return;
    }

    try {
      final joined = await ref.read(eventChatsProvider.notifier).join(event.id);
      if (!mounted || joined == null) return;
      await ref.read(conversationsProvider.notifier).refresh();
      if (!mounted) return;
      await ref.read(eventChatsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.joinedEventChat)),
      );
      await _openJoinedEventConversation(
        eventId: event.id,
        state: ref.read(conversationsProvider),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not join: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationsProvider);
    final l10n = AppLocalizations.of(context)!;

    // Listen to WebSocket for real-time bumping
    ref.listen(pollEventStreamProvider, (previous, next) {
      next.whenData((eventData) {
        if (eventData['type'] == 'NEW_MESSAGE') {
          final payload = eventData['message'];
          final conversationId = eventData['conversationId'] as String?;
          if (payload != null && conversationId != null) {
            final isMe =
                payload['sender']?['id'] == ref.read(currentUserProvider)?.id;
            ref.read(conversationsProvider.notifier).applyNewMessage(
                  conversationId: conversationId,
                  content: payload['content'],
                  timestamp: payload['createdAt'] != null
                      ? DateTime.tryParse(payload['createdAt'])
                      : DateTime.now(),
                  incrementUnread: !isMe,
                  messageId: payload['id'],
                );
          }
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.messages, style: AppTypography.h3),
        centerTitle: false,
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            tabs: const [
              Tab(
                  icon: Icon(Icons.chat_bubble_outline, size: 20),
                  text: 'Chats'),
              Tab(
                  icon: Icon(Icons.groups_outlined, size: 20),
                  text: 'Join Groups'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConversationsList(state),
          _buildEventGroupsTab(),
        ],
      ),
    );
  }

  Widget _buildConversationsList(ConversationsState state) {
    if (state.isLoading && state.conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (state.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.noConversations,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start chatting with event participants',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(conversationsProvider.notifier).refresh(),
      color: AppColors.primary,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: state.conversations.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.conversations.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final conv = state.conversations[index];
          return _ConversationTile(conversation: conv);
        },
      ),
    );
  }

  Widget _buildEventGroupsTab() {
    final myEventsAsync = ref.watch(myFutureRegistrationsProvider);
    final state = ref.watch(conversationsProvider);
    final eventChatsState = ref.watch(eventChatsProvider);

    return myEventsAsync.when(
      data: (registrations) {
        final eventChatsById = {
          for (final chat in eventChatsState.chats) chat.eventId: chat,
        };
        final successfulRegs = registrations
            .where((r) =>
                r.status == RegistrationStatusEnum.approved ||
                r.status == RegistrationStatusEnum.confirmed ||
                r.status == RegistrationStatusEnum.checkedIn)
            .toList();

        if (successfulRegs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.event_available,
                    size: 64,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Register for events to unlock exclusive group chats',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    'Connect with other attendees, share ideas, and network',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 80),
          itemCount: successfulRegs.length,
          itemBuilder: (context, index) {
            final reg = successfulRegs[index];
            final event = reg.event;
            if (event == null) return const SizedBox.shrink();

            final eventChat = eventChatsById[event.id];
            final alreadyJoined = eventChat?.joined ??
                state.conversations.any((c) => c.eventId == event.id);
            final isJoining = eventChatsState.joiningEventId == event.id;
            final imageUrl = (event.imageUrl?.trim().isNotEmpty ?? false)
                ? event.imageUrl!
                : eventChat?.eventImageUrl;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: alreadyJoined
                    ? AppColors.success.withValues(alpha: 0.05)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: alreadyJoined
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.divider.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: isJoining
                    ? null
                    : () => _joinOrOpenEventGroup(
                          event: event,
                          alreadyJoined: alreadyJoined,
                          conversationsState: state,
                        ),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: imageUrl != null && imageUrl.isNotEmpty
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _EventAvatar(event: event),
                                )
                              : _EventAvatar(event: event),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: alreadyJoined
                                    ? AppColors.success.withValues(alpha: 0.2)
                                    : AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isJoining)
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  else
                                    Icon(
                                      alreadyJoined
                                          ? Icons.check_circle
                                          : Icons.add_circle_outline,
                                      size: 12,
                                      color: alreadyJoined
                                          ? AppColors.success
                                          : AppColors.primary,
                                    ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      isJoining
                                          ? 'Joining...'
                                          : alreadyJoined
                                              ? 'Joined'
                                              : 'Join Group',
                                      style: AppTypography.caption.copyWith(
                                        color: alreadyJoined
                                            ? AppColors.success
                                            : AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        alreadyJoined
                            ? Icons.arrow_forward_ios
                            : Icons.touch_app,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error: $err',
                style: AppTypography.body.copyWith(color: AppColors.error)),
          ],
        ),
      ),
    );
  }

  Widget _EventAvatar({required Event event}) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          event.title.isNotEmpty ? event.title[0].toUpperCase() : 'E',
          style: AppTypography.h4.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: hasUnread
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () =>
            context.push('/chat/${conversation.id}', extra: conversation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.surfaceVariant,
                    backgroundImage: conversation.displayImage != null &&
                            conversation.displayImage!.isNotEmpty
                        ? NetworkImage(conversation.displayImage!)
                        : null,
                    child: conversation.displayImage == null ||
                            conversation.displayImage!.isEmpty
                        ? conversation.isGroup
                            ? Icon(
                                Icons.groups,
                                color: AppColors.textSecondary,
                                size: 28,
                              )
                            : Text(
                                conversation.displayAvatarLabel,
                                style: AppTypography.h4.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                        : null,
                  ),
                  if (conversation.pinned)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.push_pin,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (hasUnread && !conversation.pinned)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 12, height: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            conversation.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(conversation.lastMessageAt),
                          style: AppTypography.caption.copyWith(
                            color: hasUnread
                                ? AppColors.primary
                                : AppColors.textLight,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (conversation.pinned) ...[
                          Icon(
                            Icons.push_pin,
                            size: 12,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            _localizedPreview(
                                    context, conversation.lastMessageContent) ??
                                '',
                            style: AppTypography.body.copyWith(
                              color: hasUnread
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '${conversation.unreadCount > 99 ? '99+' : conversation.unreadCount}',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    }
    return '${dt.day}/${dt.month}';
  }
}
