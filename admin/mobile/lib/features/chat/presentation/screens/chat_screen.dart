import 'dart:io';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../services/websocket_service.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/models/conversation.dart';
import '../../../auth/providers/auth_provider.dart';

final chatMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatMessagesNotifier, ChatMessagesState, String>((ref, conversationId) {
  return ChatMessagesNotifier(ref.watch(apiServiceProvider), conversationId);
});

class ChatMessagesState {
  const ChatMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;
  final bool hasMore;
  final int currentPage;

  ChatMessagesState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return ChatMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
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
          : [...newMessages, ...state.messages];

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

  Future<bool> sendMessage(String content, {String? replyToId}) async {
    if (content.trim().isEmpty) return false;

    state = state.copyWith(isSending: true);

    try {
      final message = await _api.sendMessage(
        _conversationId,
        content,
        replyToId: replyToId,
      );

      state = state.copyWith(
        messages: [...state.messages, message],
        isSending: false,
      );
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

      state = state.copyWith(
        messages: [...state.messages, message],
        isSending: false,
      );
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
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  ChatMessage? _replyingTo;
  bool _showEmojiPicker = false;
  DateTime? _lastTypingSent;
  List<String> _typingUserNames = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
    Future.microtask(() {
      ref
          .read(chatMessagesProvider(widget.conversationId).notifier)
          .loadMessages(refresh: true);
      ref.read(webSocketServiceProvider).subscribeToConversation(widget.conversationId);

      ref.read(webSocketServiceProvider).sendRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final now = DateTime.now();
    if (_lastTypingSent == null || now.difference(_lastTypingSent!).inSeconds >= 2) {
      _lastTypingSent = now;
      ref.read(webSocketServiceProvider).sendTyping(widget.conversationId);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels <=
        _scrollController.position.minScrollExtent + 200) {
      ref.read(chatMessagesProvider(widget.conversationId).notifier).loadMessages();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
      subtitle = conversation.participantCount != null
          ? AppLocalizations.of(context)!.members(conversation.participantCount!)
          : 'Event Group';
    } else if (conversation.type == ConversationType.group) {
      subtitle = conversation.participantCount != null
          ? '${conversation.participantCount} members'
          : 'Group Chat';
    } else {
      final otherUser = conversation.participants?.firstOrNull;
      if (otherUser != null) {
        final isOnline = ref.watch(webSocketServiceProvider).isUserOnline(otherUser.userId);
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
              color: subtitleColor ?? AppColors.textOnPrimary.withValues(alpha: 0.8),
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

  void _showChatInfo(Conversation? conversation) {
    if (conversation == null) return;

    if (conversation.type == ConversationType.direct) {
      final otherUser = conversation.participants?.firstOrNull;
      if (otherUser != null) {
        context.push('/profile/${otherUser.userId}');
      }
    } else {
      _showGroupInfoSheet(conversation);
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
                    ? '${conversation.participantCount} members'
                    : 'Group Chat',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              if (conversation.eventTitle != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event, size: 16, color: AppColors.primary),
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
                child: conversation.participants != null
                    ? ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: conversation.participants!.length,
                        itemBuilder: (context, index) {
                          final participant = conversation.participants![index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                              backgroundImage: participant.avatarUrl != null
                                  ? NetworkImage(participant.avatarUrl!)
                                  : null,
                              child: participant.avatarUrl == null
                                  ? Text(
                                      participant.fullName.isNotEmpty
                                          ? participant.fullName[0].toUpperCase()
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
                                _startDirectChatWithUser(participant.userId);
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/profile/${participant.userId}');
                            },
                          );
                        },
                      )
                    : const Center(
                        child: Text('No members found'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDirectChatWithUser(String userId) async {
    try {
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleMenuAction(String action, Conversation? conversation) {
    switch (action) {
      case 'view_profile':
        final otherUser = conversation?.participants?.firstOrNull;
        if (otherUser != null) {
          context.push('/profile/${otherUser.userId}');
        }
        break;
      case 'view_members':
        if (conversation != null) {
          _showGroupInfoSheet(conversation);
        }
        break;
      case 'mute':
        _toggleMute(true);
        break;
      case 'unmute':
        _toggleMute(false);
        break;
      case 'search':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search coming soon')),
        );
        break;
      case 'media_gallery':
        _showMediaGallery();
        break;
      case 'block_user':
        final otherUser = conversation?.participants?.firstOrNull;
        if (otherUser != null) {
          _confirmBlockUser(otherUser.userId, otherUser.fullName);
        }
        break;
      case 'clear_chat':
        _confirmClearChat();
        break;
    }
  }

  Future<void> _toggleMute(bool mute) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.muteConversation(widget.conversationId, mute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mute ? 'Chat muted' : 'Chat unmuted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clear chat coming soon')),
      );
    }
  }

  Future<void> _confirmBlockUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: Text('Are you sure you want to block $userName? They will no longer be able to message you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.warning),
            child: const Text('Block'),
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
              content: Text('$userName has been blocked'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to block user: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _showMediaGallery() {
    final state = ref.read(chatMessagesProvider(widget.conversationId));
    final mediaMessages = state.messages.where((m) => m.mediaUrl != null).toList();

    if (mediaMessages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No media in this chat')),
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Media & Files',
                  style: TextStyle(
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
    final conversation = widget.conversation;

    ref.listen(chatEventStreamProvider, (previous, next) {
      next.whenData((event) {
        if (event.conversationId == widget.conversationId) {
          switch (event.type) {
            case ChatEventType.newMessage:
              ref.read(chatMessagesProvider(widget.conversationId).notifier)
                  .loadMessages(refresh: true);
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
              break;
            default:
              break;
          }
        }
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.primary,
        leadingWidth: 40,
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
                  color: AppColors.surface,
                  shape: BoxShape.circle,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textOnPrimary,
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
          if (conversation?.type == ConversationType.eventGroup && conversation?.eventId != null)
            IconButton(
              onPressed: () => context.push('/event/${conversation!.eventId}'),
              icon: const Icon(Icons.event, size: 22),
              tooltip: 'View Event',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) => _handleMenuAction(value, conversation),
            itemBuilder: (context) => [
              if (conversation?.type == ConversationType.direct)
                const PopupMenuItem(
                  value: 'view_profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 20),
                      SizedBox(width: 12),
                      Text('View Profile'),
                    ],
                  ),
                ),
              if (conversation?.isGroup == true)
                const PopupMenuItem(
                  value: 'view_members',
                  child: Row(
                    children: [
                      Icon(Icons.group_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('View Members'),
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
                    Text(conversation?.muted == true ? 'Unmute' : 'Mute'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'search',
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20),
                    SizedBox(width: 12),
                    Text('Search in Chat'),
                  ],
                ),
              ),
              if (conversation?.type == ConversationType.direct)
                const PopupMenuItem(
                  value: 'media_gallery',
                  child: Row(
                    children: [
                      Icon(Icons.photo_library_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Media & Files'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              if (conversation?.type == ConversationType.direct)
                const PopupMenuItem(
                  value: 'block_user',
                  child: Row(
                    children: [
                      Icon(Icons.block, size: 20, color: AppColors.warning),
                      SizedBox(width: 12),
                      Text('Block User', style: TextStyle(color: AppColors.warning)),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 20, color: AppColors.error),
                    SizedBox(width: 12),
                    Text('Clear Chat', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_showEmojiPicker) {
                  setState(() => _showEmojiPicker = false);
                }
              },
              child: state.messages.isEmpty && state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.messages.isEmpty
                      ? _buildEmptyState()
                      : _buildMessagesList(state, currentUser?.id),
            ),
          ),

          if (_replyingTo != null) _buildReplyPreview(),

          _buildInputBar(state.isSending),

          if (_showEmojiPicker) _buildEmojiPicker(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 60,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Send a message to start the conversation',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatMessagesState state, String? currentUserId) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: state.messages.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.isLoading && index == 0) {
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

        final adjustedIndex = state.isLoading ? index - 1 : index;
        if (adjustedIndex < 0) return const SizedBox.shrink();

        final message = state.messages[adjustedIndex];
        final isMe = message.sender?.id == currentUserId;
        final showDateHeader = _shouldShowDateHeader(adjustedIndex, state.messages);

        return Column(
          children: [
            if (showDateHeader) _buildDateHeader(message.createdAt),
            _MessageBubble(
              message: message,
              isMe: isMe,
              timeText: _formatTime(message.createdAt),
              onReply: () {
                setState(() => _replyingTo = message);
                _focusNode.requestFocus();
              },
              onDelete: isMe && !message.isDeleted
                  ? () => _deleteMessage(message.id)
                  : null,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
          left: const BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyingTo?.sender?.fullName ?? 'message'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo?.content ?? '',
                  style: const TextStyle(
                    fontSize: 13,
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
            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
            emojiSizeMax: 28 * (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    : const Icon(Icons.send, color: AppColors.textOnPrimary, size: 20),
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
  });

  final ChatMessage message;
  final bool isMe;
  final String timeText;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: AppColors.divider,
                shape: BoxShape.circle,
                image: message.sender?.avatarUrl != null
                    ? DecorationImage(
                        image: NetworkImage(message.sender!.avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: message.sender?.avatarUrl == null
                  ? const Icon(Icons.person, color: AppColors.textSecondary, size: 18)
                  : null,
            ),
          ],

          Flexible(
            child: GestureDetector(
              onLongPress: onReply,
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && message.sender != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        message.sender!.fullName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 18 : 4),
                        topRight: Radius.circular(isMe ? 4 : 18),
                        bottomLeft: const Radius.circular(18),
                        bottomRight: const Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyTo != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.textOnPrimary.withValues(alpha: 0.2)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: isMe ? AppColors.textOnPrimary : AppColors.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.replyTo!.senderName ?? 'Unknown',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isMe ? AppColors.textOnPrimary : AppColors.primary,
                                  ),
                                ),
                                Text(
                                  message.replyTo!.content,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe
                                        ? AppColors.textOnPrimary.withValues(alpha: 0.8)
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
                                color: isMe ? AppColors.textOnPrimary.withValues(alpha: 0.7) : AppColors.textLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(context)!.thisMessageWasDeleted,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: isMe ? AppColors.textOnPrimary.withValues(alpha: 0.7) : AppColors.textLight,
                                ),
                              ),
                            ],
                          )
                        else if (message.type == MessageType.image && message.mediaUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              message.mediaUrl!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 200,
                                  height: 200,
                                  color: AppColors.divider,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 200,
                                  height: 200,
                                  color: AppColors.divider,
                                  child: const Icon(Icons.broken_image, size: 40),
                                );
                              },
                            ),
                          )
                        else
                          Text(
                            message.content,
                            style: TextStyle(
                              fontSize: 14,
                              color: isMe ? AppColors.textOnPrimary : AppColors.textPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textLight,
                          ),
                        ),
                        if (onDelete != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onDelete,
                            child: const Icon(
                              Icons.delete_outline,
                              size: 14,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
