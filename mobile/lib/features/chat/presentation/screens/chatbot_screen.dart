import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../shared/widgets/luma_logo.dart';
import '../models/chatbot_message.dart';
import '../providers/chatbot_provider.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;

  final List<String> _suggestedQuestions = [
    '🔍 Show me tech events in Hanoi',
    '🎉 What\'s happening this weekend?',
    '💡 Recommend something fun',
    '📂 Show all categories',
    '💰 What are free events?',
    '🌟 Show trending events',
  ];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String message) async {
    if (message.isEmpty) return;
    _messageController.clear();
    await ref.read(chatbotProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatbotProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Row(
          children: [
            LumaLogo(size: 32),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LUMA Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('AI-powered event discovery', style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
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
            onPressed: () => _showClearDialog(context),
            tooltip: 'Clear chat',
          ),
        ],
      ),
      body: chatState.when(
        data: (messages) => Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _buildMessageBubble(context, message);
                      },
                    ),
            ),
            // Quick suggestions when chatting
            if (messages.isNotEmpty && messages.last.isUser == false && !messages.last.isLoading)
              _buildQuickSuggestions(),
            _buildInputArea(context),
          ],
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(chatbotProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    final suggestions = ['More events', 'Free events', 'This weekend', 'Categories'];
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(suggestions[index], style: const TextStyle(fontSize: 12)),
            backgroundColor: AppColors.primary.withOpacity(0.1),
            side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
            onPressed: () => _sendMessage(suggestions[index]),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const LumaLogo(size: 80),
              const SizedBox(height: 24),
              const Text(
                'LUMA Assistant',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI-powered event discovery assistant.\nAsk me anything about events!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              Column(
                children: _suggestedQuestions
                    .map((question) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildSuggestedQuestion(question),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestion(String text) {
    return GestureDetector(
      onTap: () => _sendMessage(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
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
              child: Text(text, style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatbotMessage message) {
    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: _buildTypingAnimation(),
        ),
      );
    }

    final isError = message.intent == 'ERROR';

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isUser
                  ? AppColors.primary
                  : isError
                      ? AppColors.error.withOpacity(0.1)
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
                  : isError
                      ? Border.all(color: AppColors.error.withOpacity(0.3))
                      : Border.all(color: Colors.grey[200]!),
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
                        Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text('Error', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
                      ],
                    ),
                  ),
                _buildFormattedText(
                  message.content,
                  isUser: message.isUser,
                ),
                if (!message.isUser && message.intent != null && !isError
                    && message.intent != 'OFF_TOPIC' && message.intent != 'GREETING')
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIntentChip(message.intent!),
                        if (message.dataPointsUsed != null && message.dataPointsUsed! > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: _buildInfoChip('${message.dataPointsUsed} items', Icons.dataset_outlined),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Event cards
          if (message.events != null && message.events!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: SizedBox(
                height: 180,
                width: MediaQuery.of(context).size.width * 0.85,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.events!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    return _buildEventCard(context, message.events![index]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Renders text with basic markdown: **bold**, bullet points
  Widget _buildFormattedText(String text, {bool isUser = false}) {
    final color = isUser ? Colors.white : AppColors.textPrimary;
    final lines = text.split('\n');
    final spans = <InlineSpan>[];

    for (int i = 0; i < lines.length; i++) {
      if (i > 0) spans.add(const TextSpan(text: '\n'));
      final line = lines[i];

      // Handle bullet points
      String processedLine = line;
      if (line.trimLeft().startsWith('• ') || line.trimLeft().startsWith('- ')) {
        processedLine = line;
      }

      // Parse **bold** within line
      final parts = _parseBold(processedLine);
      for (final part in parts) {
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

    return RichText(
      text: TextSpan(children: spans),
    );
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
    if (parts.isEmpty) {
      parts.add(_TextPart(text, false));
    }
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
        style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, ChatbotEvent event) {
    return GestureDetector(
      onTap: () => context.push('/event/${event.id}'),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
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
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: SizedBox(
                height: 80,
                width: double.infinity,
                child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: event.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Center(child: Icon(Icons.event, color: AppColors.primary)),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.primary.withOpacity(0.1),
                          child: const Center(child: Icon(Icons.event, color: AppColors.primary)),
                        ),
                      )
                    : Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: const Center(child: Icon(Icons.event, color: AppColors.primary, size: 32)),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                    const Spacer(),
                    if (event.startTime != null)
                      Row(
                        children: [
                          Icon(Icons.schedule, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _formatEventDate(event.startTime!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (event.city != null) ...[
                          Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              event.city!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (event.price != null && event.price! > 0)
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (event.price != null && event.price! > 0)
                                ? '\$${event.price!.toStringAsFixed(0)}'
                                : 'Free',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: (event.price != null && event.price! > 0)
                                  ? AppColors.primary
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatEventDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildTypingAnimation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypingDot(0),
          const SizedBox(width: 4),
          _buildTypingDot(1),
          const SizedBox(width: 4),
          _buildTypingDot(2),
          const SizedBox(width: 8),
          Text('Thinking...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 100)),
      builder: (context, value, child) {
        final height = 8 + (value.abs() * 4);
        return Container(
          width: 8,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.6 + (value.abs() * 0.4)),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return SafeArea(
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
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask me about events...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) => _sendMessage(text),
                  maxLines: null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () => _sendMessage(_messageController.text),
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
          'Are you sure you want to delete all messages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(chatbotProvider.notifier).clearMessages();
              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatIntent(String intent) {
    return intent
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
}

class _TextPart {
  final String text;
  final bool isBold;
  _TextPart(this.text, this.isBold);
}
