import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/luma_logo.dart';
import '../models/chatbot_message.dart';
import '../providers/chatbot_provider.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocus = FocusNode();

  bool _composerHasText = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleComposerChange);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChange);
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _handleComposerChange() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _composerHasText) {
      setState(() => _composerHasText = hasText);
    }
  }

  // Locale-aware default suggestions for the very first turn (before we
  // have any AI-supplied ones).
  List<String> _defaultSuggestions(BuildContext ctx) {
    final isVi = Localizations.localeOf(ctx).languageCode == 'vi';
    return isVi
        ? const [
            '🔍 Sự kiện công nghệ ở Hà Nội',
            '🎉 Cuối tuần này có gì hay?',
            '💡 Gợi ý cho mình',
            '📂 Liệt kê danh mục',
            '💰 Sự kiện miễn phí',
            '🌟 Sự kiện đang hot',
            '🎫 Vé của tôi',
            '⭐ Sự kiện đã lưu',
          ]
        : const [
            '🔍 Show me tech events in Hanoi',
            '🎉 What\'s happening this weekend?',
            '💡 Recommend something fun',
            '📂 Show all categories',
            '💰 What are free events?',
            '🌟 Show trending events',
            '🎫 My tickets',
            '⭐ Saved events',
          ];
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    final notifier = ref.read(chatbotProvider.notifier);
    if (notifier.isThinking) return;
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;
    HapticFeedback.lightImpact();
    _messageController.clear();
    await notifier.sendMessage(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<ChatbotMessage>>>(chatbotProvider, (prev, next) {
      final prevCount = prev?.valueOrNull?.length ?? 0;
      final nextCount = next.valueOrNull?.length ?? 0;
      if (nextCount != prevCount) _scrollToBottom();
    });

    final chatState = ref.watch(chatbotProvider);
    final isThinking = ref.watch(
      chatbotProvider.select((s) {
        final list = s.valueOrNull;
        return list != null && list.isNotEmpty && list.last.isLoading;
      }),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Row(
          children: [
            LumaLogo(size: 32),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('LUMA Assistant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('AI-powered event discovery',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _showClearDialog,
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: chatState.when(
        data: (messages) {
          // Note: auto-scroll is driven by the `ref.listen` above, which
          // only fires on count changes. Avoid calling addPostFrameCallback
          // here — this `build()` also runs when the composer text changes,
          // which would fight the user's scroll position while typing.
          final lastAssistant = _lastAssistantMessage(messages);
          final suggestions = lastAssistant?.suggestions;
          return Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) =>
                            _buildMessageBubble(messages[index]),
                      ),
              ),
              if (messages.isNotEmpty &&
                  !messages.last.isUser &&
                  !messages.last.isLoading &&
                  suggestions != null &&
                  suggestions.isNotEmpty)
                _buildQuickSuggestions(suggestions),
              _buildInputArea(isThinking: isThinking),
            ],
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Error: $error', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(chatbotProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  ChatbotMessage? _lastAssistantMessage(List<ChatbotMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (!m.isUser && !m.isLoading) return m;
    }
    return null;
  }

  // ───────────────────────────── Empty state ─────────────────────────────

  Widget _buildEmptyState() {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const LumaLogo(size: 80),
            const SizedBox(height: 20),
            const Text(
              'LUMA Assistant',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isVi
                  ? 'Trợ lý AI khám phá sự kiện trên LUMA.\n'
                      'Mình chỉ hỗ trợ về sự kiện trên LUMA — hỏi gì cũng được!'
                  : 'Your AI-powered event discovery assistant.\n'
                      'I can only help with events on LUMA — ask me anything about them!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildScopeBadge(isVi),
            const SizedBox(height: 28),
            Column(
              children: _defaultSuggestions(context)
                  .map((q) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildSuggestedQuestion(q),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeBadge(bool isVi) {
    Widget pill(IconData icon, String text) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(text,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        pill(Icons.auto_awesome, isVi ? 'Dùng AI' : 'AI-powered'),
        pill(Icons.storage_rounded, isVi ? 'Dữ liệu thật' : 'Live database'),
        pill(Icons.lock_outline, isVi ? 'Chỉ sự kiện' : 'Events only'),
      ],
    );
  }

  Widget _buildSuggestedQuestion(String text) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _sendMessage(text),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14, color: AppColors.primary.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Message bubble ────────────────────────────

  Widget _buildMessageBubble(ChatbotMessage message) {
    if (message.isLoading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: _TypingIndicator(),
        ),
      );
    }

    final isError = message.intent == 'ERROR';
    final canInteract =
        !message.isUser && !isError && message.content.isNotEmpty;

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: message.isUser
            ? AppColors.primary
            : isError
                ? AppColors.error.withOpacity(0.08)
                : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(message.isUser ? 16 : 4),
          bottomRight: Radius.circular(message.isUser ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: message.isUser
            ? null
            : Border.all(
                color: isError
                    ? AppColors.error.withOpacity(0.3)
                    : AppColors.neutral200,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isError)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: AppColors.error),
                  const SizedBox(width: 4),
                  Text('Error',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.error)),
                ],
              ),
            ),
          _buildFormattedText(message.content, isUser: message.isUser),
          if (!message.isUser &&
              message.intent != null &&
              !isError &&
              message.intent != 'OFF_TOPIC' &&
              message.intent != 'GREETING' &&
              message.intent != 'AUTH_REQUIRED')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildIntentChip(message.intent!),
                  if ((message.dataPointsUsed ?? 0) > 0)
                    _buildInfoChip(
                      '${message.dataPointsUsed} items',
                      Icons.dataset_outlined,
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    final body = GestureDetector(
      onLongPress: canInteract ? () => _showMessageActions(message) : null,
      child: bubble,
    );

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          body,
          if (message.events != null && message.events!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: SizedBox(
                height: 278,
                width: MediaQuery.of(context).size.width * 0.85,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.events!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) =>
                      _buildEventCard(message.events![index]),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.only(
              top: 2,
              bottom: 8,
              left: message.isUser ? 0 : 4,
              right: message.isUser ? 4 : 0,
            ),
            child: Text(
              DateFormat('HH:mm').format(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(ChatbotMessage message) {
    HapticFeedback.selectionClick();
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutral300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: Text(isVi ? 'Sao chép tin nhắn' : 'Copy message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isVi ? 'Đã sao chép' : 'Copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded),
              title: Text(isVi ? 'Hỏi lại' : 'Regenerate response'),
              subtitle: Text(isVi
                  ? 'Hỏi lại câu hỏi gần nhất'
                  : 'Re-ask the last question'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(chatbotProvider.notifier).regenerateLast();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Text / chips / events ───────────────────────

  Widget _buildFormattedText(String text, {bool isUser = false}) {
    final color = isUser ? Colors.white : AppColors.textPrimary;
    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      for (final part in _parseBold(lines[i])) {
        spans.add(TextSpan(
          text: part.text,
          style: TextStyle(
            color: color,
            fontSize: 14.5,
            height: 1.5,
            fontWeight: part.isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ));
      }
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  List<_TextPart> _parseBold(String text) {
    final parts = <_TextPart>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        parts.add(_TextPart(text.substring(lastEnd, match.start), false));
      }
      parts.add(_TextPart(match.group(1)!, true));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      parts.add(_TextPart(text.substring(lastEnd), false));
    }
    if (parts.isEmpty) parts.add(_TextPart(text, false));
    return parts;
  }

  Widget _buildIntentChip(String intent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatIntent(intent),
        style: TextStyle(
            fontSize: 10,
            color: AppColors.primary,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.neutral100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEventCard(ChatbotEvent event) {
    return _ChatbotEventCard(event: event);
  }

  // ───────────────────────────── Composer ────────────────────────────────

  Widget _buildQuickSuggestions(List<String> suggestions) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = suggestions[index];
          return ActionChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            backgroundColor: AppColors.primary.withOpacity(0.1),
            side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
            onPressed: () => _sendMessage(label),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildInputArea({required bool isThinking}) {
    final canSend = !isThinking && _composerHasText;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.neutral300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _inputFocus,
                  enabled: !isThinking,
                  decoration: InputDecoration(
                    hintText: isThinking
                        ? (isVi ? 'LUMA đang suy nghĩ…' : 'LUMA is thinking…')
                        : (isVi
                            ? 'Hỏi mình về sự kiện…'
                            : 'Ask me about events...'),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    hintStyle: TextStyle(color: AppColors.neutral400),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: canSend ? _sendMessage : null,
                  maxLines: 4,
                  minLines: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4, bottom: 4, top: 4),
                child: _SendButton(
                  isThinking: isThinking,
                  enabled: canSend,
                  onPressed: () {
                    if (isThinking) {
                      ref.read(chatbotProvider.notifier).cancelInFlight();
                      HapticFeedback.mediumImpact();
                    } else if (canSend) {
                      _sendMessage(_messageController.text);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDialog() {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isVi ? 'Xoá lịch sử chat' : 'Clear Chat History'),
        content: Text(isVi
            ? 'Xoá toàn bộ tin nhắn? Hành động này không thể hoàn tác.'
            : 'Are you sure you want to delete all messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isVi ? 'Huỷ' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatbotProvider.notifier).clearMessages();
              Navigator.pop(context);
            },
            child: Text(isVi ? 'Xoá' : 'Clear',
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _formatIntent(String intent) => intent
      .split('_')
      .map((w) => w.isEmpty
          ? w
          : w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

// ─────────────────────────── Small helpers ─────────────────────────────

class _TextPart {
  final String text;
  final bool isBold;
  const _TextPart(this.text, this.isBold);
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.isThinking,
    required this.enabled,
    required this.onPressed,
  });

  final bool isThinking;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isThinking
        ? AppColors.error
        : (enabled ? AppColors.primary : AppColors.primary.withOpacity(0.4));
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Icon(
              isThinking ? Icons.stop_rounded : Icons.send_rounded,
              color: Colors.white,
              size: isThinking ? 20 : 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// Three-dot typing indicator driven by a single [AnimationController].
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(0),
          const SizedBox(width: 4),
          _dot(1),
          const SizedBox(width: 4),
          _dot(2),
          const SizedBox(width: 8),
          Text(
            isVi ? 'Đang nghĩ…' : 'Thinking...',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = (_controller.value - index * 0.15) % 1.0;
        final t = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
        return Container(
          width: 8,
          height: 8 + t * 4,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.5 + t * 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

/// Event card with inline action buttons (View / Bookmark / Share). Tracks
/// its own bookmark state so toggles stay snappy without a global refresh.
class _ChatbotEventCard extends ConsumerStatefulWidget {
  const _ChatbotEventCard({required this.event});

  final ChatbotEvent event;

  @override
  ConsumerState<_ChatbotEventCard> createState() => _ChatbotEventCardState();
}

class _ChatbotEventCardState extends ConsumerState<_ChatbotEventCard> {
  bool? _bookmarked; // null = unknown, hide icon until first toggle/check
  bool _busy = false;

  Future<void> _toggleBookmark() async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    try {
      final api = ref.read(apiServiceProvider);
      final bookmarked = await api.toggleBookmark(widget.event.id);
      if (!mounted) return;
      setState(() => _bookmarked = bookmarked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bookmarked
              ? (isVi ? 'Đã lưu sự kiện' : 'Event saved')
              : (isVi ? 'Đã bỏ lưu' : 'Removed from saved')),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.statusCode == 401 || e.response?.statusCode == 403
          ? (isVi ? 'Vui lòng đăng nhập' : 'Please sign in to save events')
          : (isVi ? 'Không thể lưu' : 'Could not save event');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isVi ? 'Không thể lưu' : 'Could not save event'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    HapticFeedback.lightImpact();
    final url = 'https://luma.com/event/${widget.event.id}';
    await Share.share(url, subject: widget.event.title);
  }

  String _formatEventDate(String dateStr) {
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/event/${event.id}'),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 80,
                width: double.infinity,
                child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _placeholder(),
                        errorWidget: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => context.push('/event/${event.id}'),
                    child: Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (event.startTime != null)
                    Row(
                      children: [
                        Icon(Icons.schedule,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _formatEventDate(event.startTime!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (event.city != null) ...[
                        Icon(Icons.location_on,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event.city!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                      _PriceBadge(price: event.price, isVi: isVi),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Primary register CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
            child: SizedBox(
              width: double.infinity,
              height: 32,
              child: FilledButton.icon(
                onPressed: () => context.push('/event/${event.id}'),
                icon: const Icon(Icons.confirmation_number_outlined, size: 14),
                label: Text(
                  isVi ? 'Đăng ký' : 'Register',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          // Action row
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.neutral100)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconAction(
                  icon: Icons.open_in_new_rounded,
                  tooltip: isVi ? 'Xem chi tiết' : 'View details',
                  onTap: () => context.push('/event/${event.id}'),
                ),
                _IconAction(
                  icon: _bookmarked == true
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  tooltip: isVi ? 'Lưu sự kiện' : 'Save event',
                  busy: _busy,
                  highlighted: _bookmarked == true,
                  onTap: _toggleBookmark,
                ),
                _IconAction(
                  icon: Icons.share_outlined,
                  tooltip: isVi ? 'Chia sẻ' : 'Share',
                  onTap: _share,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.primary.withOpacity(0.1),
        child: const Center(
          child: Icon(Icons.event, color: AppColors.primary, size: 32),
        ),
      );
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.busy = false,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool busy;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  icon,
                  size: 18,
                  color: highlighted
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
        ),
      ),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.price, required this.isVi});
  final double? price;
  final bool isVi;

  @override
  Widget build(BuildContext context) {
    final isPaid = price != null && price! > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPaid
            ? AppColors.primary.withOpacity(0.1)
            : AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPaid ? '\$${price!.toStringAsFixed(0)}' : (isVi ? 'Free' : 'Free'),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPaid ? AppColors.primary : AppColors.success,
        ),
      ),
    );
  }
}
