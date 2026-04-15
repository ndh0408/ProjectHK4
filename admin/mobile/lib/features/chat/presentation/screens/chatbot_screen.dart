import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../l10n/app_localizations.dart';
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
    '🎓 Find events in my city',
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
    await ref.read(chatbotProvider.notifier).sendMessage(message);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatbotProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('LUMA Assistant'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _showClearDialog(context);
            },
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
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'LUMA Assistant',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hi! I\'m here to help you discover amazing events.\nTap a suggestion or ask me anything:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Column(
                children: _suggestedQuestions
                    .map((question) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Text(
          text,
          style: TextStyle(color: AppColors.primary, fontSize: 14),
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

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isUser ? AppTheme.primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: message.isUser
                  ? null
                  : Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    color: message.isUser ? Colors.white : Colors.black,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                if (!message.isUser && message.intent != null && message.intent != 'ERROR')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Chip(
                          label: Text(
                            _formatIntent(message.intent!),
                            style: const TextStyle(fontSize: 11),
                          ),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.grey[200],
                        ),
                        if (message.dataPointsUsed != null &&
                            message.dataPointsUsed! > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Chip(
                              label: Text(
                                '${message.dataPointsUsed} items',
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.grey[200],
                            ),
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
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 200,
                width: MediaQuery.of(context).size.width * 0.8,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.events!.length,
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

  Widget _buildEventCard(BuildContext context, ChatbotEvent event) {
    return GestureDetector(
      onTap: () {
        context.push('/event/${event.id}');
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Center(
                child: Icon(
                  Icons.event,
                  color: AppTheme.primaryColor,
                  size: 40,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (event.city != null)
                      Text(
                        '📍 ${event.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    if (event.price != null && event.price! > 0)
                      Text(
                        '💰 ${event.price!.toStringAsFixed(0)}đ',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (event.approvedAttendees != null)
                      Text(
                        '👥 ${event.approvedAttendees}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
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

  Widget _buildTypingAnimation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypingDot(0),
          const SizedBox(width: 4),
          _buildTypingDot(1),
          const SizedBox(width: 4),
          _buildTypingDot(2),
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
            color: AppTheme.primaryColor.withOpacity(0.6 + (value.abs() * 0.4)),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
      onEnd: () {
        setState(() {});
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask me anything...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    hintStyle: TextStyle(color: Colors.grey[400]),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) {
                    _sendMessage(text);
                    _messageController.clear();
                  },
                  maxLines: null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  onPressed: () {
                    final text = _messageController.text;
                    _sendMessage(text);
                    _messageController.clear();
                  },
                  icon: Icon(
                    Icons.send_rounded,
                    color: AppTheme.primaryColor,
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
