import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/widgets/app_components.dart';

class ContactHostScreen extends ConsumerStatefulWidget {
  const ContactHostScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.organiserName,
  });

  final String eventId;
  final String eventTitle;
  final String organiserName;

  @override
  ConsumerState<ContactHostScreen> createState() => _ContactHostScreenState();
}

class _ContactHostScreenState extends ConsumerState<ContactHostScreen> {
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterYourQuestion),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final api = ref.read(apiServiceProvider);
      await api.askQuestion(widget.eventId, message);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.questionSentSuccessfully),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorUtils.extractMessage(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messageLength = _messageController.text.trim().length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l10n.contactHost),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.section),
            borderColor: AppColors.borderLight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: AppRadius.allLg,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.organiserName,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.eventTitle,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader(
            title: 'Write a clear question',
            subtitle:
                'Short, specific messages increase the chance of getting a useful reply from the organiser.',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: 'Message',
                  hint: l10n.enterQuestionForHost,
                  controller: _messageController,
                  maxLines: 10,
                  maxLength: 1000,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  helper:
                      'Include ticket type, timing or venue details if you need a precise answer.',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 16,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Replies usually come back through notifications and event messages.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '$messageLength/1000',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageX,
            AppSpacing.md,
            AppSpacing.pageX,
            AppSpacing.md,
          ),
          child: AppButton(
            label: l10n.send,
            icon: Icons.send_rounded,
            expanded: true,
            loading: _isSending,
            onPressed: _isSending ? null : _send,
          ),
        ),
      ),
    );
  }
}
