import 'dart:async';
import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../services/websocket_service.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../auth/providers/auth_provider.dart';
import '../providers/event_chats_provider.dart';
import '../widgets/poll_message_card.dart';
import 'package:mobile/features/chat/providers/chat_providers.dart';
import 'package:mobile/features/chat/presentation/screens/conversations_screen.dart';

final chatMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, ChatMessagesState, String>(
        (ref, conversationId) {
  return ChatMessagesNotifier(ref.watch(apiServiceProvider), conversationId);
});

class ChatMessagesState {
  const ChatMessagesState({
    this.messages = const [],
    this.searchResults = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isSearchingServer = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  final List<ChatMessage> messages;
  final List<ChatMessage> searchResults;
  final bool isLoading;
  final bool isSending;
  final bool isSearchingServer;
  final String? error;
  final bool hasMore;
  final int currentPage;

  ChatMessagesState copyWith({
    List<ChatMessage>? messages,
    List<ChatMessage>? searchResults,
    bool? isLoading,
    bool? isSending,
    bool? isSearchingServer,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isSearchingServer: isSearchingServer ?? this.isSearchingServer,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  ChatMessagesNotifier(this._api, this._conversationId)
      : super(const ChatMessagesState());

  final ApiService _api;
  final String _conversationId;

  List<ChatMessage> _sortedUniqueMessages(Iterable<ChatMessage> messages) {
    final byId = <String, ChatMessage>{};
    for (final message in messages) {
      byId[message.id] = message;
    }
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  void _upsertMessage(ChatMessage message, {bool updateSending = false}) {
    state = state.copyWith(
      messages: _sortedUniqueMessages([...state.messages, message]),
      isSending: updateSending ? false : state.isSending,
    );
  }

  Future<void> loadMessages({bool refresh = false}) async {
    if (state.isLoading) return;
    if (!refresh && !state.hasMore) return;

    final page = refresh ? 0 : state.currentPage;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.getMessages(_conversationId, page: page);
      final newMessages = response.content.reversed.toList();

      final allMessages = refresh
          ? newMessages
          : _sortedUniqueMessages([...newMessages, ...state.messages]);

      state = state.copyWith(
        messages: allMessages,
        isLoading: false,
        hasMore: response.hasMore,
        currentPage: response.number + 1,
      );

      if (refresh) {
        _api.markConversationAsRead(_conversationId);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load messages',
      );
    }
  }

  Future<void> searchMessages(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: [], isSearchingServer: false);
      return;
    }

    state = state.copyWith(isSearchingServer: true);

    try {
      final response = await _api.searchMessages(_conversationId, query: query);
      state = state.copyWith(
        searchResults: response.content,
        isSearchingServer: false,
      );
    } catch (e) {
      state = state.copyWith(isSearchingServer: false);
    }
  }

  Future<bool> sendMessage(String content, {String? replyToId}) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await _api.sendMessage(
        _conversationId,
        content,
        replyToId: replyToId,
      );

      _upsertMessage(message, updateSending: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false);
      return false;
    }
  }

  Future<bool> sendImageMessage(File imageFile, {String? replyToId}) async {
    state = state.copyWith(isSending: true);

    try {
      final message = await _api.sendImageMessage(
        _conversationId,
        imageFile,
        replyToId: replyToId,
      );

      _upsertMessage(message, updateSending: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false);
      return false;
    }
  }

  Future<bool> deleteMessage(String messageId) async {
    try {
      await _api.deleteMessage(messageId);

      state = state.copyWith(
        messages: state.messages.map((m) {
          if (m.id == messageId) {
            return ChatMessage(
              id: m.id,
              conversationId: m.conversationId,
              type: m.type,
              content: 'This message was deleted',
              sender: m.sender,
              replyTo: m.replyTo,
              createdAt: m.createdAt,
              deleted: true,
            );
          }
          return m;
        }).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> refresh() async {
    await loadMessages(refresh: true);
  }

  void addMessageFromEvent(ChatMessage message) {
    _upsertMessage(message);
  }

  /// Merge a poll snapshot update (from `/topic/event.X.polls`) into any
  /// chat message that embeds the same poll, so the bubble stays live.
  void applyPollUpdate(Map<String, dynamic> pollJson) {
    final pollId = pollJson['id'] as String?;
    if (pollId == null) return;

    PollSnapshot? parsed;
    try {
      // Build a PollSnapshot from the raw PollResponse payload. We preserve
      // the viewer-local `hasVoted` because the broadcast does not know the
      // subscriber identity.
      parsed = PollSnapshot(
        id: pollId,
        eventId: pollJson['eventId'] as String? ?? '',
        question: pollJson['question'] as String? ?? '',
        type: pollJson['type'] as String? ?? 'SINGLE_CHOICE',
        status: pollJson['status'] as String? ?? 'ACTIVE',
        isActive: pollJson['isActive'] as bool? ??
            pollJson['active'] as bool? ??
            false,
        totalVotes: (pollJson['totalVotes'] as num?)?.toInt() ?? 0,
        maxRating: (pollJson['maxRating'] as num?)?.toInt(),
        closesAt: pollJson['closesAt'] == null
            ? null
            : DateTime.tryParse(pollJson['closesAt'].toString()),
        closedAt: pollJson['closedAt'] == null
            ? null
            : DateTime.tryParse(pollJson['closedAt'].toString()),
        options: ((pollJson['options'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map((o) => PollSnapshotOption(
                  id: o['id'] as String,
                  text: o['text'] as String? ?? '',
                  voteCount: (o['voteCount'] as num?)?.toInt() ?? 0,
                  percentage: (o['percentage'] as num?)?.toDouble() ?? 0.0,
                  displayOrder: (o['displayOrder'] as num?)?.toInt() ?? 0,
                ))
            .toList(),
        hasVoted: false,
        hideResultsUntilClosed:
            pollJson['hideResultsUntilClosed'] as bool? ?? false,
        resultsHidden: pollJson['resultsHidden'] as bool? ?? false,
      );
    } catch (_) {
      return;
    }

    final updated = state.messages.map((m) {
      if (m.poll?.id == pollId) {
        // Broadcasts are identity-agnostic, so preserve viewer-local fields
        // (hasVoted + the specific picks/rating) from the previous snapshot.
        // Otherwise the "your choice" highlight disappears whenever anyone
        // else votes.
        final prev = m.poll!;
        return m.copyWith(
          poll: parsed!.copyWith(
            hasVoted: prev.hasVoted,
            votedOptionIds: prev.votedOptionIds,
            votedRating: prev.votedRating,
          ),
        );
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updated);
  }

  /// Apply a local snapshot edit (e.g. optimistic hasVoted=true) without
  /// touching any other poll.
  void applyLocalPollChange(String pollId, PollSnapshot updated) {
    final next = state.messages.map((m) {
      if (m.poll?.id == pollId) {
        return m.copyWith(poll: updated);
      }
      return m;
    }).toList();
    state = state.copyWith(messages: next);
  }

  void markMessageDeleted(String messageId) {
    state = state.copyWith(
      messages: state.messages.map((m) {
        if (m.id == messageId) {
          return ChatMessage(
            id: m.id,
            conversationId: m.conversationId,
            type: m.type,
            content: 'This message was deleted',
            sender: m.sender,
            replyTo: m.replyTo,
            createdAt: m.createdAt,
            deleted: true,
          );
        }
        return m;
      }).toList(),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    this.conversation,
  });

  final String conversationId;
  final Conversation? conversation;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _messageSearchController = TextEditingController();
  final _focusNode = FocusNode();
  final _messageSearchFocusNode = FocusNode();
  final _imagePicker = ImagePicker();
  ChatMessage? _replyingTo;
  bool _showEmojiPicker = false;
  bool _showMessageSearch = false;
  bool _isLoadingConversationDetails = false;
  DateTime? _lastTypingSent;
  final List<String> _typingUserNames = [];
  Conversation? _conversation;
  Future<Conversation?>? _conversationLoadFuture;
  String _messageSearchQuery = '';
  final _searchDebounce = _Debounce(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
    Future.microtask(() async {
      ref
          .read(webSocketServiceProvider)
          .subscribeToConversation(widget.conversationId);
      await _loadConversationDetailsIfNeeded();
      await ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .loadMessages(refresh: true);
      if (!mounted) return;
      // For event group chats, also follow the event's poll topic so the
      // inline poll cards auto-refresh when anyone votes or the poll closes.
      final eventId = (_conversation ?? widget.conversation)?.eventId;
      if (eventId != null) {
        ref.read(webSocketServiceProvider).subscribeToEventPolls(eventId);
      }
      // Opening a chat implies everything here is read — sync the global
      // unread total and the preview in the conversation list.
      ref.read(unreadMessageCountProvider.notifier).refresh();
      // Mark as read in BOTH lists — direct/group conversations and the
      // event-group chats tab. Each call is a no-op if the conversation
      // isn't in that particular list.
      ref
          .read(conversationsProvider.notifier)
          .markConversationRead(widget.conversationId);
      ref.read(webSocketServiceProvider).sendRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    // Drop the room subscription so we don't leak subscribers across navigations.
    try {
      ref
          .read(webSocketServiceProvider)
          .unsubscribeFromConversation(widget.conversationId);
      final eventId = (_conversation ?? widget.conversation)?.eventId;
      if (eventId != null) {
        ref.read(webSocketServiceProvider).unsubscribeFromEventPolls(eventId);
      }
    } catch (_) {}
    _scrollController.dispose();
    _messageController.dispose();
    _messageSearchController.dispose();
    _focusNode.dispose();
    _messageSearchFocusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final now = DateTime.now();
    if (_lastTypingSent == null ||
        now.difference(_lastTypingSent!).inSeconds >= 2) {
      _lastTypingSent = now;
      ref.read(webSocketServiceProvider).sendTyping(widget.conversationId);
    }
  }

  void _onScroll() {
    // With `reverse: true`, the top of the visible list (oldest messages)
    // sits at maxScrollExtent — not minScrollExtent. Trigger pagination as
    // the user approaches the top so older history pages are prefetched.
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .loadMessages();
    }
  }

  bool _needsConversationDetails(Conversation? conversation) {
    if (conversation == null) return true;
    if (conversation.participants == null) return true;
    if (conversation.isGroup &&
        conversation.participantCount != null &&
        conversation.participantCount! > 0 &&
        conversation.participants!.isEmpty) {
      return true;
    }
    return false;
  }

  Future<Conversation?> _loadConversationDetailsIfNeeded({
    bool force = false,
    bool showError = false,
  }) async {
    final current = _conversation ?? widget.conversation;
    final shouldLoad = force || _needsConversationDetails(current);
    if (!shouldLoad) return current;
    if (_conversationLoadFuture != null) return _conversationLoadFuture!;

    final future = _fetchConversationDetails(showError: showError);
    _conversationLoadFuture = future;
    try {
      return await future;
    } finally {
      _conversationLoadFuture = null;
    }
  }

  Future<Conversation?> _fetchConversationDetails(
      {bool showError = false}) async {
    if (mounted) {
      setState(() => _isLoadingConversationDetails = true);
    }

    try {
      final api = ref.read(apiServiceProvider);
      final conversation = await api.getConversation(widget.conversationId);
      if (mounted) {
        setState(() => _conversation = conversation);
      }
      return conversation;
    } catch (e) {
      if (showError && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load chat details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return _conversation ?? widget.conversation;
    } finally {
      if (mounted) {
        setState(() => _isLoadingConversationDetails = false);
      }
    }
  }

  void _openMessageSearch() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    }
    setState(() => _showMessageSearch = true);
    Future.microtask(_messageSearchFocusNode.requestFocus);
  }

  void _closeMessageSearch() {
    _messageSearchController.clear();
    setState(() {
      _showMessageSearch = false;
      _messageSearchQuery = '';
    });
    ref
        .read(chatMessagesProvider(widget.conversationId).notifier)
        .searchMessages('');
  }

  List<ChatMessage> _filterMessages(List<ChatMessage> messages) {
    final query = _messageSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return messages;

    return messages.where((message) {
      final content = message.content.toLowerCase();
      final senderName = message.sender?.fullName.toLowerCase() ?? '';
      final replyContent = message.replyTo?.content.toLowerCase() ?? '';
      return content.contains(query) ||
          senderName.contains(query) ||
          replyContent.contains(query);
    }).toList();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // With `reverse: true`, the latest message sits at pixel 0.
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _startDirectChat(String userId, String fullName) async {
    if (userId == ref.read(currentUserProvider)?.id) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final conversation = await ref.read(apiServiceProvider).getDirectChat(userId);
      if (mounted) {
        Navigator.pop(context); // close loader
        context.push('/chat/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start chat with $fullName')),
        );
      }
    }
  }

  /// Replace one participant's lastReadAt with the supplied timestamp so our
  /// own messages immediately flip their read state. No-op if we don't have
  /// the participants list yet (the next fetch will carry the real value).
  void _applyPeerRead(String peerUserId, DateTime readAt) {
    final current = _conversation ?? widget.conversation;
    final participants = current?.participants;
    if (current == null || participants == null) return;
    var changed = false;
    final updated = participants.map((p) {
      if (p.userId == peerUserId &&
          (p.lastReadAt == null || p.lastReadAt!.isBefore(readAt))) {
        changed = true;
        return ChatParticipant(
          userId: p.userId,
          fullName: p.fullName,
          avatarUrl: p.avatarUrl,
          lastReadAt: readAt,
        );
      }
      return p;
    }).toList();
    if (!changed) return;
    if (!mounted) return;
    setState(() {
      _conversation = current.copyWith(participants: updated);
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    final replyId = _replyingTo?.id;
    setState(() => _replyingTo = null);

    final success = await ref
        .read(chatMessagesProvider(widget.conversationId).notifier)
        .sendMessage(content, replyToId: replyId);

    if (success) {
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  Future<void> _pickAndSendImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final replyId = _replyingTo?.id;
      setState(() => _replyingTo = null);

      final success = await ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .sendImageMessage(File(pickedFile.path), replyToId: replyId);

      if (success) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMessage),
        content: Text(l10n.deleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .deleteMessage(messageId);
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

  bool _shouldShowDateHeader(int index, List<ChatMessage> messages) {
    if (index == 0) return true;
    final current = messages[index].createdAt;
    final previous = messages[index - 1].createdAt;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  Widget _buildSubtitle(Conversation? conversation) {
    if (conversation == null) return const SizedBox.shrink();

    if (_typingUserNames.isNotEmpty) {
      final typingText = _typingUserNames.length == 1
          ? '${_typingUserNames.first} is typing...'
          : '${_typingUserNames.length} people are typing...';
      return Row(
        children: [
          _buildTypingAnimation(),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              typingText,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textOnPrimary.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    String subtitle;
    Color? subtitleColor;
    bool showDot = false;

    if (conversation.type == ConversationType.eventGroup) {
      final count = conversation.participantCount;
      subtitle = count != null
          ? (count == 1 ? '1 member' : '$count members')
          : 'Event Group';
    } else if (conversation.type == ConversationType.group) {
      final count = conversation.participantCount;
      subtitle = count != null
          ? (count == 1 ? '1 member' : '$count members')
          : 'Group Chat';
    } else {
      final otherUser = conversation.participants?.firstOrNull;
      if (otherUser != null) {
        final isOnline = ref.watch(userOnlineStatusProvider(otherUser.userId));
        if (isOnline) {
          subtitle = 'Online';
          subtitleColor = Colors.greenAccent;
          showDot = true;
        } else {
          subtitle = 'Tap to view profile';
        }
      } else {
        subtitle = 'Tap to view profile';
      }
    }

    return Row(
      children: [
        if (showDot) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: subtitleColor ?? Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: subtitleColor ??
                  AppColors.textOnPrimary.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTypingAnimation() {
    return SizedBox(
      width: 20,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100)),
            builder: (context, value, child) {
              return Container(
                width: 4,
                height: 4 + (value * 2),
                decoration: BoxDecoration(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  /// Inline "X is typing…" bubble shown above the input bar so the user
  /// sees peer activity without looking at the AppBar subtitle. Uses the
  /// same animated dots as the header indicator for consistency.
  Widget _buildTypingBubble() {
    final text = _typingUserNames.length == 1
        ? '${_typingUserNames.first} is typing…'
        : '${_typingUserNames.length} people are typing…';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Padding(
        key: ValueKey(text),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.md),
                  topRight: Radius.circular(AppRadius.md),
                  bottomRight: Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(AppRadius.xs),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TypingDots(color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    text,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showChatInfo(Conversation? conversation) async {
    final resolved = await _loadConversationDetailsIfNeeded(
      force: conversation == null || _needsConversationDetails(conversation),
      showError: true,
    );
    final current = resolved ?? conversation;
    if (!mounted || current == null) return;

    if (current.type == ConversationType.direct) {
      final otherUser = current.participants?.firstOrNull;
      if (otherUser != null) {
        context.push('/profile/${otherUser.userId}');
      }
    } else {
      _showGroupInfoSheet(current);
    }
  }

  void _showGroupInfoSheet(Conversation conversation) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  image: conversation.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(conversation.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: conversation.imageUrl == null
                    ? Icon(
                        conversation.type == ConversationType.eventGroup
                            ? Icons.groups
                            : Icons.group,
                        size: 40,
                        color: AppColors.primary,
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                conversation.displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                conversation.participantCount != null
                    ? (conversation.participantCount == 1
                        ? '1 member'
                        : '${conversation.participantCount} members')
                    : 'Group Chat',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (conversation.eventTitle != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        conversation.eventTitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              Expanded(
                child: conversation.participants != null &&
                        conversation.participants!.isNotEmpty
                    ? ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: conversation.participants!.length,
                        itemBuilder: (context, index) {
                          final participant = conversation.participants![index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              backgroundImage: participant.avatarUrl != null
                                  ? NetworkImage(participant.avatarUrl!)
                                  : null,
                              child: participant.avatarUrl == null
                                  ? Text(
                                      participant.fullName.isNotEmpty
                                          ? participant.fullName[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(participant.fullName),
                            trailing: IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () {
                                Navigator.pop(context);
                                _startDirectChat(participant.userId, participant.fullName);
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/profile/${participant.userId}');
                            },
                          );
                        },
                      )
                    : Center(
                        child:
                            Text(AppLocalizations.of(context)!.noMembersFound),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(
      String action, Conversation? conversation) async {
    switch (action) {
      case 'view_profile':
        final resolved = await _loadConversationDetailsIfNeeded(
          force:
              conversation == null || _needsConversationDetails(conversation),
          showError: true,
        );
        final otherUser = (resolved ?? conversation)?.participants?.firstOrNull;
        if (!mounted) return;
        if (otherUser != null) {
          context.push('/profile/${otherUser.userId}');
        }
        break;
      case 'view_members':
        final resolved = await _loadConversationDetailsIfNeeded(
          force: true,
          showError: true,
        );
        final current = resolved ?? conversation;
        if (current != null) {
          _showGroupInfoSheet(current);
        }
        break;
      case 'mute':
        await _toggleMute(true);
        break;
      case 'unmute':
        await _toggleMute(false);
        break;
      case 'search':
        _openMessageSearch();
        break;
      case 'media_gallery':
        _showMediaGallery();
        break;
      case 'block_user':
        final resolved = await _loadConversationDetailsIfNeeded(
          force:
              conversation == null || _needsConversationDetails(conversation),
          showError: true,
        );
        final otherUser = (resolved ?? conversation)?.participants?.firstOrNull;
        if (otherUser != null) {
          await _confirmBlockUser(otherUser.userId, otherUser.fullName);
        }
        break;
      case 'leave_group':
        await _confirmLeaveEventGroup(conversation);
        break;
      case 'clear_chat':
        await _confirmClearChat();
        break;
    }
  }

  Future<void> _confirmLeaveEventGroup(Conversation? conversation) async {
    if (conversation == null || conversation.eventId == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.leaveEventChatTitle),
        content: Text(l10n.leaveEventChatMessage(conversation.displayName)),
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
    if (confirm != true || !mounted) return;
    final ok = await ref
        .read(eventChatsProvider.notifier)
        .leave(conversation.eventId!);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.leftEventChat),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } else {
      final err = ref.read(eventChatsProvider).error ?? 'Unknown error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.failedToLeaveChat}: $err'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _toggleMute(bool mute) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.muteConversation(widget.conversationId, mute);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        final current = _conversation ?? widget.conversation;
        if (current != null) {
          _conversation = current.copyWith(muted: mute);
        }
      });
      await ref.read(conversationsProvider.notifier).refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mute ? l10n.muteLabel : l10n.unmuteLabel),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmClearChat() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearChat),
        content: Text(l10n.clearChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.clearLabel),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.clearChatComingSoon)),
      );
    }
  }

  Future<void> _confirmBlockUser(String userId, String userName) async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.blockUserTitle),
        content: Text(l10n.blockUserConfirm(userName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: Text(l10n.block),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final api = ref.read(apiServiceProvider);
        await api.blockUser(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.userBlockedSnack(userName)),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.failedToBlockUser(e.toString())),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showMediaGallery() {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.read(chatMessagesProvider(widget.conversationId));
    final mediaMessages =
        state.messages.where((m) => m.mediaUrl != null).toList();

    if (mediaMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noMediaInChat)),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.mediaAndFiles,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: mediaMessages.length,
                  itemBuilder: (context, index) {
                    final message = mediaMessages[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showFullImage(message.mediaUrl!);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(message.mediaUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(imageUrl),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatMessagesProvider(widget.conversationId));
    final currentUser = ref.watch(currentUserProvider);
    final conversation = _conversation ?? widget.conversation;

    ref.listen(pollEventStreamProvider, (previous, next) {
      next.whenData((payload) {
        ref
            .read(chatMessagesProvider(widget.conversationId).notifier)
            .applyPollUpdate(payload);
      });
    });

    ref.listen(chatEventStreamProvider, (previous, next) {
      next.whenData((event) {
        if (event.conversationId != widget.conversationId) return;
        final notifier =
            ref.read(chatMessagesProvider(widget.conversationId).notifier);
        switch (event.type) {
          case ChatEventType.newMessage:
            final payload = event.message;
            if (payload == null) return;
            try {
              final msg = ChatMessage.fromJson(payload);
              notifier.addMessageFromEvent(msg);
              // Auto-scroll if the event came from someone else
              if (msg.sender?.id != currentUser?.id) {
                Future.delayed(
                    const Duration(milliseconds: 50), _scrollToBottom);
              }
            } catch (_) {
              // Fallback only if the payload is malformed
              notifier.loadMessages(refresh: true);
            }
            break;
          case ChatEventType.messageDeleted:
            final payload = event.message;
            final id = payload != null ? payload['id'] as String? : null;
            if (id != null) {
              notifier.markMessageDeleted(id);
            }
            break;
          case ChatEventType.typing:
            if (event.userId != currentUser?.id && event.userName != null) {
              setState(() {
                if (!_typingUserNames.contains(event.userName)) {
                  _typingUserNames.add(event.userName!);
                }
              });
              Future.delayed(const Duration(seconds: 3), () {
                if (mounted) {
                  setState(() {
                    _typingUserNames.remove(event.userName);
                  });
                }
              });
            }
            break;
          case ChatEventType.read:
            // Peer marked the conversation read — update that participant's
            // local lastReadAt so our own messages flip from ✓ to ✓✓ in
            // realtime without waiting for a refresh.
            final peerId = event.userId;
            if (peerId != null && peerId != currentUser?.id) {
              _applyPeerRead(peerId, DateTime.now());
            }
            break;
          default:
            break;
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 72,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: () => _showChatInfo(conversation),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: AppRadius.allPill,
                  image: conversation?.displayImage != null
                      ? DecorationImage(
                          image: NetworkImage(conversation!.displayImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: conversation?.displayImage == null
                    ? Icon(
                        conversation?.type == ConversationType.eventGroup
                            ? Icons.groups
                            : conversation?.type == ConversationType.group
                                ? Icons.group
                                : Icons.person,
                        color: AppColors.primary,
                        size: 22,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation?.displayName ?? 'Chat',
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    _buildSubtitle(conversation),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (conversation?.type == ConversationType.eventGroup &&
              conversation?.eventId != null)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () => context.push('/event/${conversation!.eventId}'),
              icon: const Icon(Icons.event, size: 22),
              tooltip: AppLocalizations.of(context)!.viewEventTooltip,
            ),
          PopupMenuButton<String>(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
            ),
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) => _handleMenuAction(value, conversation),
            itemBuilder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return [
                if (conversation?.type == ConversationType.direct)
                  PopupMenuItem(
                    value: 'view_profile',
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.viewProfile),
                      ],
                    ),
                  ),
                if (conversation?.isGroup == true)
                  PopupMenuItem(
                    value: 'view_members',
                    child: Row(
                      children: [
                        const Icon(Icons.group_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.viewMembers),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: conversation?.muted == true ? 'unmute' : 'mute',
                  child: Row(
                    children: [
                      Icon(
                        conversation?.muted == true
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(conversation?.muted == true
                          ? l10n.unmuteLabel
                          : l10n.muteLabel),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20),
                      const SizedBox(width: 12),
                      Text(l10n.searchInChat),
                    ],
                  ),
                ),
                if (conversation?.type == ConversationType.direct)
                  PopupMenuItem(
                    value: 'media_gallery',
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library_outlined, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.mediaAndFiles),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                if (conversation?.type == ConversationType.direct)
                  PopupMenuItem(
                    value: 'block_user',
                    child: Row(
                      children: [
                        const Icon(Icons.block,
                            size: 20, color: AppColors.warning),
                        const SizedBox(width: 12),
                        Text(l10n.blockUserTitle,
                            style: const TextStyle(color: AppColors.warning)),
                      ],
                    ),
                  ),
                if (conversation?.type == ConversationType.eventGroup)
                  PopupMenuItem(
                    value: 'leave_group',
                    child: Row(
                      children: [
                        const Icon(Icons.logout,
                            size: 20, color: AppColors.error),
                        const SizedBox(width: 12),
                        Text(
                          l10n.leaveGroup,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  )
                else
                  PopupMenuItem(
                    value: 'clear_chat',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_outlined,
                            size: 20, color: AppColors.error),
                        const SizedBox(width: 12),
                        Text(
                          l10n.clearChat,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoadingConversationDetails && conversation == null)
            const LinearProgressIndicator(minHeight: 2),
          if (conversation?.pinnedMessage != null)
            _buildPinnedBanner(conversation!.pinnedMessage!),
          if (_showMessageSearch) _buildMessageSearchBar(),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_showEmojiPicker) {
                  setState(() => _showEmojiPicker = false);
                }
              },
              child: _buildMessagesContent(state, currentUser?.id),
            ),
          ),
          if (_typingUserNames.isNotEmpty) _buildTypingBubble(),
          if (_replyingTo != null) _buildReplyPreview(),
          if (conversation?.isClosed == true)
            _buildClosedBanner()
          else
            _buildInputBar(state.isSending),
          if (_showEmojiPicker) _buildEmojiPicker(),
        ],
      ),
    );
  }

  Widget _buildPinnedBanner(PinnedMessage pinned) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: InkWell(
        onTap: () => _scrollToMessage(pinned.id),
        child: Row(
          children: [
            const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pinned Message',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${pinned.senderName}: ${pinned.content}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final state = ref.read(chatMessagesProvider(widget.conversationId));
    final indexInList =
        state.messages.indexWhere((m) => m.id == messageId);

    if (indexInList == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is too old to jump to')),
      );
      return;
    }

    final messageCount = state.messages.length;
    final reversedIndex = messageCount - 1 - indexInList;

    _scrollController.animateTo(
      reversedIndex * 80.0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildClosedBanner() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        AppSpacing.md,
        AppSpacing.pageX,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        background: AppColors.surfaceVariant,
        borderColor: AppColors.borderLight,
        child: Row(
          children: [
            const Icon(Icons.lock_clock, color: AppColors.textLight, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.eventChatClosedBanner,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      compact: true,
      title: 'No messages yet',
      subtitle: 'Send a message to start the conversation.',
    );
  }

  Widget _buildMessagesContent(ChatMessagesState state, String? currentUserId) {
    if (_showMessageSearch) {
      if (state.isSearchingServer) {
        return const LoadingState(message: 'Searching...');
      }
      if (state.searchResults.isEmpty) {
        return _buildMessageSearchEmptyState();
      }
      return _buildMessagesList(
        state,
        currentUserId,
        state.searchResults,
        isSearch: true,
      );
    }

    if (state.messages.isEmpty && state.isLoading) {
      return const LoadingState(message: 'Loading messages...');
    }

    if (state.messages.isEmpty && state.error != null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref
            .read(chatMessagesProvider(widget.conversationId).notifier)
            .loadMessages(refresh: true),
      );
    }

    if (state.messages.isEmpty) {
      return _buildEmptyState();
    }

    final filteredMessages = _filterMessages(state.messages);
    if (_showMessageSearch && filteredMessages.isEmpty) {
      return _buildMessageSearchEmptyState();
    }

    return _buildMessagesList(
      state,
      currentUserId,
      filteredMessages,
    );
  }

  Widget _buildMessageSearchBar() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        AppSpacing.sm,
        AppSpacing.pageX,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.borderLight),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: _messageSearchController,
                focusNode: _messageSearchFocusNode,
                hintText: l10n.searchInChat,
                autofocus: true,
                onChanged: (value) {
                  setState(() => _messageSearchQuery = value);
                  _searchDebounce.run(() {
                    ref
                        .read(chatMessagesProvider(widget.conversationId).notifier)
                        .searchMessages(value);
                  });
                },
                trailing: _messageSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _messageSearchController.clear();
                          setState(() => _messageSearchQuery = '');
                          ref
                              .read(chatMessagesProvider(widget.conversationId)
                                  .notifier)
                              .searchMessages('');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: _closeMessageSearch,
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageSearchEmptyState() {
    return const EmptyState(
      icon: Icons.search_off_rounded,
      compact: true,
      title: 'No matching messages',
      subtitle: 'Try a different keyword or phrase.',
    );
  }

  Widget _buildMessagesList(
    ChatMessagesState state,
    String? currentUserId,
    List<ChatMessage> visibleMessages, {
    bool isSearch = false,
  }) {
    final messageCount = visibleMessages.length;
    final itemCount = messageCount + (!isSearch && state.isLoading ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      reverse: !isSearch,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (!isSearch && state.isLoading && index == messageCount) {
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

        final messageIndex = !isSearch ? (messageCount - 1 - index) : index;
        if (messageIndex < 0 || messageIndex >= messageCount) {
          return const SizedBox.shrink();
        }

        final message = visibleMessages[messageIndex];
        final isMe = message.sender?.id == currentUserId;
        final showDateHeader = !isSearch &&
            _shouldShowDateHeader(messageIndex, visibleMessages);

        bool readByOthers = false;
        if (isMe) {
          final convo = _conversation ?? widget.conversation;
          final others = convo?.participants
                  ?.where((p) => p.userId != currentUserId) ??
              const <ChatParticipant>[];
          for (final p in others) {
            final lastRead = p.lastReadAt;
            if (lastRead != null && !lastRead.isBefore(message.createdAt)) {
              readByOthers = true;
              break;
            }
          }
        }

        return Column(
          children: [
            if (showDateHeader) _buildDateHeader(message.createdAt),
            _MessageBubble(
              message: message,
              isMe: isMe,
              timeText: _formatTime(message.createdAt),
              readByOthers: readByOthers,
              onAvatarTap: () {
                if (!isMe && message.sender != null) {
                  _startDirectChat(message.sender!.id, message.sender!.fullName);
                }
              },
              onReply: () {
                setState(() => _replyingTo = message);
                _focusNode.requestFocus();
              },
              onDelete: isMe && !message.isDeleted
                  ? () => _deleteMessage(message.id)
                  : null,
              onPollVoted: (updated) {
                ref
                    .read(chatMessagesProvider(widget.conversationId).notifier)
                    .applyLocalPollChange(updated.id, updated);
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
            color: AppColors.textLight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateHeader(dateTime),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(
          top: BorderSide(color: AppColors.borderLight, width: 1),
          left: const BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.allSm,
            ),
            child: const Icon(
              Icons.reply_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyingTo?.sender?.fullName ?? 'message'}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo?.content ?? '',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 20),
            padding: const EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
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
      selection: TextSelection.collapsed(
        offset: start + emoji.emoji.length,
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

  Widget _buildInputBar(bool isSending) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageX,
        AppSpacing.sm,
        AppSpacing.pageX,
        AppSpacing.pageX,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              onTap: _toggleEmojiPicker,
              child: Icon(
                _showEmojiPicker
                    ? Icons.keyboard
                    : Icons.emoji_emotions_outlined,
                color:
                    _showEmojiPicker ? AppColors.primary : AppColors.textLight,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isSending ? null : _pickAndSendImage,
              child: Icon(
                Icons.image_outlined,
                color: isSending ? AppColors.divider : AppColors.textLight,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
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
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.typeMessage,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: isSending ? null : _sendMessage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSending ? AppColors.textLight : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: isSending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : const Icon(Icons.send,
                        color: AppColors.textOnPrimary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.timeText,
    required this.onReply,
    this.onDelete,
    this.onPollVoted,
    this.readByOthers = false,
    this.onAvatarTap,
  });

  final ChatMessage message;
  final bool isMe;
  final String timeText;
  final VoidCallback onReply;
  final VoidCallback? onDelete;
  final PollVoted? onPollVoted;
  final bool readByOthers;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: onAvatarTap,
              child: AvatarComponent(
                url: message.sender?.avatarUrl,
                initials: message.sender?.fullName.isNotEmpty == true
                    ? message.sender!.fullName[0]
                    : '?',
                size: 32,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onReply,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe ? null : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isMe ? AppColors.primary : Colors.black)
                          .withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      if (!isMe && message.sender != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                message.sender!.fullName,
                                style: AppTypography.caption.copyWith(
                                  color: message.isFromOrganiser
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: message.isFromOrganiser
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              if (message.isFromOrganiser) ...[
                                const SizedBox(width: 6),
                                const _OrganiserBadge(),
                              ],
                            ],
                          ),
                        ),
                      if (isMe && message.isFromOrganiser)
                        const Padding(
                          padding: EdgeInsets.only(right: 4, bottom: 2),
                          child: _OrganiserBadge(),
                        ),
                      if (message.type == MessageType.poll && message.poll != null)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          child: PollMessageCard(
                            poll: message.poll!,
                            onVoted: (updated) => onPollVoted?.call(updated),
                          ),
                        )
                      else if (message.type == MessageType.image &&
                          message.mediaUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            message.mediaUrl!,
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                width: 200,
                                height: 200,
                                color: AppColors.surfaceVariant,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Container(
                              width: 200,
                              height: 200,
                              color: AppColors.surfaceVariant,
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 48),
                              ),
                            ),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.replyTo != null) ...[
                              Container(
                                padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.textOnPrimary
                                          .withValues(alpha: 0.18)
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border(
                                    left: BorderSide(
                                      color: isMe
                                          ? AppColors.textOnPrimary
                                          : AppColors.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.reply_rounded,
                                          size: 12,
                                          color: isMe
                                              ? AppColors.textOnPrimary
                                              : AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            message.replyTo!.senderName,
                                            style: AppTypography.caption.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: isMe
                                                  ? AppColors.textOnPrimary
                                                  : AppColors.primary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      message.replyTo!.content,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: isMe
                                            ? AppColors.textOnPrimary
                                                .withValues(alpha: 0.8)
                                            : AppColors.textSecondary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (message.isDeleted)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.block,
                                    size: 14,
                                    color: isMe
                                        ? AppColors.textOnPrimary
                                            .withValues(alpha: 0.7)
                                        : AppColors.textLight,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      message.deletedByName != null
                                          ? AppLocalizations.of(context)!
                                              .messageDeletedBy(
                                                  message.deletedByName!)
                                          : AppLocalizations.of(context)!
                                              .thisMessageWasDeleted,
                                      style: AppTypography.body.copyWith(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: isMe
                                            ? AppColors.textOnPrimary
                                                .withValues(alpha: 0.7)
                                            : AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                message.content ?? '',
                                style: AppTypography.body.copyWith(
                                  fontSize: 14,
                                  color: isMe
                                      ? AppColors.textOnPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isMe && readByOthers) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.done_all,
              size: 16,
              color: AppColors.primary,
            ),
          ],
          const SizedBox(width: 4),
          Text(
            timeText,
            style: AppTypography.caption.copyWith(
              color: isMe
                  ? AppColors.textOnPrimary.withValues(alpha: 0.7)
                  : AppColors.textLight,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganiserBadge extends StatelessWidget {
  const _OrganiserBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user,
            size: 10,
            color: AppColors.primary,
          ),
          const SizedBox(width: 3),
          Text(
            'HOST',
            style: AppTypography.caption.copyWith(
              color: AppColors.primary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final t = (_controller.value - (i * 0.2)) % 1.0;
              final scale = 0.4 + 0.6 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 6 * scale,
                  height: 6 * scale,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _Debounce {
  _Debounce({required this.milliseconds});
  final int milliseconds;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
