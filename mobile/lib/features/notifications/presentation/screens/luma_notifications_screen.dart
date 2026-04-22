import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/notification.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../main/presentation/screens/main_shell.dart';
import 'notifications_screen.dart';

class LumaNotificationsScreen extends ConsumerStatefulWidget {
  const LumaNotificationsScreen({super.key});

  @override
  ConsumerState<LumaNotificationsScreen> createState() =>
      _LumaNotificationsScreenState();
}

class _LumaNotificationsScreenState
    extends ConsumerState<LumaNotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(() {
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
      ref.read(notificationsProvider.notifier).loadNotifications();
    }
  }

  Future<void> _openChatWithUser(String userId) async {
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

  Future<void> _handleNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      final success = await ref
          .read(notificationsProvider.notifier)
          .markAsRead(notification.id);
      if (success) {
        ref.read(unreadNotificationCountProvider.notifier).decrement();
      }
    }

    if (!mounted) return;

    if (notification.type == 'TICKET_TRANSFER_RECEIVED' &&
        notification.relatedEventId != null) {
      await _handleIncomingTransfer(notification);
      return;
    }

    if (notification.canReply && notification.senderId != null) {
      await _openChatWithUser(notification.senderId!);
      return;
    }

    final route = _routeForNotification(notification);
    if (route != null) {
      context.push(route);
    }
  }

  Future<void> _handleIncomingTransfer(AppNotification notification) async {
    final transferId = notification.relatedEventId!;
    final choice = await showDialog<_TransferChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Incoming ticket transfer'),
        content: Text(notification.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _TransferChoice.decline),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _TransferChoice.accept),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    try {
      final api = ref.read(apiServiceProvider);
      if (choice == _TransferChoice.accept) {
        await api.acceptTicketTransfer(transferId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket transfer accepted'),
            backgroundColor: AppColors.success,
          ),
        );
        context.push('/my-events');
      } else {
        await api.declineTicketTransfer(transferId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket transfer declined'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = ErrorUtils.extractMessage(
        e,
        fallback: 'Could not process transfer',
      );
      final alreadyHandled = msg.toLowerCase().contains('no longer');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alreadyHandled
              ? 'This transfer was already handled.'
              : msg),
          backgroundColor:
              alreadyHandled ? AppColors.warning : AppColors.error,
        ),
      );
    }
  }

  /// Deep-link target for a notification. Each `NotificationType` routes to
  /// the screen that shows the relevant context (waitlist offers page for
  /// waitlist offers, my coupons for coupon applied, etc.). Falls back to
  /// the event page when `relatedEventId` is set and no type-specific route
  /// applies, and returns null for purely informational notifications.
  String? _routeForNotification(AppNotification n) {
    switch (n.type) {
      case 'WAITLIST_OFFER':
      case 'WAITLIST_OFFER_EXPIRED':
        return '/waitlist-offers';
      case 'COUPON_APPLIED':
        return '/my-coupons';
      case 'TICKET_TRANSFER_RECEIVED':
      case 'TICKET_TRANSFER_ACCEPTED':
      case 'REGISTRATION_APPROVED':
      case 'REGISTRATION_REJECTED':
      case 'REGISTRATION_CANCELLED':
        return '/my-events';
      case 'CONNECTION_REQUEST':
      case 'CONNECTION_ACCEPTED':
      case 'NEW_FOLLOWER':
        return '/event-buddies';
      case 'SEAT_LOCK_EXPIRING':
      case 'PAYMENT':
      case 'EVENT_REMINDER':
      case 'EVENT_UPDATE':
      case 'EVENT_APPROVED':
      case 'EVENT_REJECTED':
      case 'EVENT_CREATED':
      case 'NEW_REGISTRATION':
      case 'NEW_QUESTION':
      case 'QUESTION_ANSWERED':
      case 'BROADCAST':
      case 'REPLY_MESSAGE':
        if (n.relatedEventId != null) {
          return '/event/${n.relatedEventId}';
        }
        return null;
      default:
        // WITHDRAWAL_* + SYSTEM are informational for users — no deep link.
        if (n.relatedEventId != null) {
          return '/event/${n.relatedEventId}';
        }
        return null;
    }
  }

  String _actionLabelFor(AppNotification n) {
    switch (n.type) {
      case 'WAITLIST_OFFER':
      case 'WAITLIST_OFFER_EXPIRED':
        return 'View offer';
      case 'COUPON_APPLIED':
        return 'View coupons';
      case 'TICKET_TRANSFER_RECEIVED':
      case 'TICKET_TRANSFER_ACCEPTED':
      case 'REGISTRATION_APPROVED':
      case 'REGISTRATION_REJECTED':
      case 'REGISTRATION_CANCELLED':
        return 'View ticket';
      case 'CONNECTION_REQUEST':
      case 'CONNECTION_ACCEPTED':
      case 'NEW_FOLLOWER':
        return 'View connections';
      case 'SEAT_LOCK_EXPIRING':
        return 'Resume booking';
      default:
        return 'Open event';
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
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  bool _shouldShowDateHeader(int index, List<AppNotification> notifications) {
    if (index == 0) return true;
    final current = notifications[index].createdAt;
    final previous = notifications[index - 1].createdAt;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      // Event lifecycle
      case 'EVENT_CREATED':
        return Icons.event_available_rounded;
      case 'EVENT_APPROVED':
        return Icons.check_circle_rounded;
      case 'EVENT_REJECTED':
        return Icons.cancel_rounded;
      case 'EVENT_REMINDER':
        return Icons.alarm_rounded;
      case 'EVENT_UPDATE':
        return Icons.update_rounded;
      // Registration lifecycle
      case 'REGISTRATION_APPROVED':
        return Icons.confirmation_number_rounded;
      case 'REGISTRATION_REJECTED':
        return Icons.person_off_rounded;
      case 'REGISTRATION_CANCELLED':
        return Icons.event_busy_rounded;
      case 'NEW_REGISTRATION':
        return Icons.person_add_alt_1_rounded;
      // Q&A
      case 'NEW_QUESTION':
        return Icons.chat_bubble_outline_rounded;
      case 'QUESTION_ANSWERED':
        return Icons.question_answer_rounded;
      case 'REPLY_MESSAGE':
        return Icons.reply_rounded;
      // Social
      case 'NEW_FOLLOWER':
        return Icons.person_add_rounded;
      case 'CONNECTION_REQUEST':
        return Icons.group_add_rounded;
      case 'CONNECTION_ACCEPTED':
        return Icons.handshake_rounded;
      // Waitlist
      case 'WAITLIST_OFFER':
        return Icons.card_giftcard_rounded;
      case 'WAITLIST_OFFER_EXPIRED':
        return Icons.hourglass_disabled_rounded;
      // Tickets / commerce
      case 'TICKET_TRANSFER_RECEIVED':
        return Icons.move_down_rounded;
      case 'TICKET_TRANSFER_ACCEPTED':
        return Icons.check_circle_outline_rounded;
      case 'COUPON_APPLIED':
        return Icons.local_offer_rounded;
      case 'SEAT_LOCK_EXPIRING':
        return Icons.timer_rounded;
      case 'PAYMENT':
        return Icons.payment_rounded;
      // Withdrawals
      case 'WITHDRAWAL_REQUEST':
        return Icons.request_quote_rounded;
      case 'WITHDRAWAL_APPROVED':
        return Icons.price_check_rounded;
      case 'WITHDRAWAL_REJECTED':
        return Icons.money_off_rounded;
      case 'WITHDRAWAL_COMPLETED':
        return Icons.account_balance_wallet_rounded;
      // Misc
      case 'BROADCAST':
        return Icons.campaign_rounded;
      case 'SYSTEM':
        return Icons.info_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  StatusChipVariant _getNotificationVariant(String? type) {
    switch (type) {
      // Positive outcomes → success
      case 'EVENT_APPROVED':
      case 'REGISTRATION_APPROVED':
      case 'CONNECTION_ACCEPTED':
      case 'TICKET_TRANSFER_ACCEPTED':
      case 'WITHDRAWAL_APPROVED':
      case 'WITHDRAWAL_COMPLETED':
      case 'COUPON_APPLIED':
      case 'PAYMENT':
        return StatusChipVariant.success;
      // Negative outcomes → danger
      case 'EVENT_REJECTED':
      case 'REGISTRATION_REJECTED':
      case 'REGISTRATION_CANCELLED':
      case 'WITHDRAWAL_REJECTED':
      case 'WAITLIST_OFFER_EXPIRED':
        return StatusChipVariant.danger;
      // Time-sensitive → warning
      case 'EVENT_REMINDER':
      case 'SEAT_LOCK_EXPIRING':
      case 'WAITLIST_OFFER':
        return StatusChipVariant.warning;
      // Informational → info
      case 'QUESTION_ANSWERED':
      case 'NEW_QUESTION':
      case 'EVENT_UPDATE':
      case 'REPLY_MESSAGE':
      case 'TICKET_TRANSFER_RECEIVED':
      case 'WITHDRAWAL_REQUEST':
        return StatusChipVariant.info;
      default:
        return StatusChipVariant.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);
    final unreadCount = state.notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                final success = await ref
                    .read(notificationsProvider.notifier)
                    .markAllAsRead();
                if (success) {
                  ref.read(unreadNotificationCountProvider.notifier).setZero();
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: state.notifications.isEmpty && state.isLoading
          ? const LoadingState(message: 'Loading notifications...')
          : state.notifications.isEmpty
              ? Padding(
                  padding: AppSpacing.screenPadding,
                  child: const EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No notifications yet',
                    subtitle:
                        'Order updates, reminders, approvals and organiser replies will appear here.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notificationsProvider.notifier).refresh(),
                  child: ListView(
                    controller: _scrollController,
                    padding: AppSpacing.screenPadding,
                    children: [
                      _NotificationsHero(unreadCount: unreadCount),
                      const SizedBox(height: AppSpacing.xl),
                      ...List.generate(state.notifications.length, (index) {
                        final notification = state.notifications[index];
                        final showDateHeader =
                            _shouldShowDateHeader(index, state.notifications);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDateHeader) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md,
                                  top: AppSpacing.sm,
                                ),
                                child: Text(
                                  _formatDateHeader(notification.createdAt),
                                  style: AppTypography.label.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                            _NotificationCard(
                              notification: notification,
                              icon: _getNotificationIcon(notification.type),
                              variant: _getNotificationVariant(
                                notification.type,
                              ),
                              actionLabel:
                                  _routeForNotification(notification) != null
                                      ? _actionLabelFor(notification)
                                      : null,
                              onTap: () => _handleNotificationTap(notification),
                              onReply: notification.canReply &&
                                      notification.senderId != null
                                  ? () => _openChatWithUser(
                                        notification.senderId!,
                                      )
                                  : null,
                            ),
                          ],
                        );
                      }),
                      if (state.isLoading)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xxxl),
                    ],
                  ),
                ),
    );
  }
}

class _NotificationsHero extends StatelessWidget {
  const _NotificationsHero({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      background: AppColors.primarySoft,
      borderColor: AppColors.primary.withValues(alpha: 0.12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unreadCount > 0
                      ? '$unreadCount unread updates'
                      : 'All caught up',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Track approvals, reminders, ticket changes and replies from organisers in one clean inbox.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.icon,
    required this.variant,
    required this.onTap,
    this.onReply,
    this.actionLabel,
  });

  final AppNotification notification;
  final IconData icon;
  final StatusChipVariant variant;
  final VoidCallback onTap;
  final VoidCallback? onReply;
  // Label for the primary CTA button. When null, the card is informational
  // only — no deep-link action is available for this notification type.
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final timeLabel = DateFormat('h:mm a').format(notification.createdAt);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      background: isUnread ? AppColors.primarySoft : AppColors.surface,
      borderColor: isUnread
          ? AppColors.primary.withValues(alpha: 0.14)
          : AppColors.divider,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: switch (variant) {
                    StatusChipVariant.success => AppColors.successLight,
                    StatusChipVariant.warning => AppColors.warningLight,
                    StatusChipVariant.danger => AppColors.errorLight,
                    StatusChipVariant.info => AppColors.infoLight,
                    StatusChipVariant.primary => AppColors.primarySoft,
                    StatusChipVariant.neutral => AppColors.neutral100,
                  },
                  borderRadius: AppRadius.allMd,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: _iconColorFor(variant)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.h4.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        if (isUnread)
                          const StatusChip(
                            label: 'New',
                            variant: StatusChipVariant.primary,
                            compact: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      notification.body,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                timeLabel,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const Spacer(),
              if (actionLabel != null)
                AppButton(
                  label: actionLabel!,
                  icon: Icons.arrow_forward_rounded,
                  variant: AppButtonVariant.tonal,
                  onPressed: onTap,
                ),
              if (onReply != null) ...[
                if (actionLabel != null) const SizedBox(width: AppSpacing.sm),
                AppButton(
                  label: 'Reply',
                  icon: Icons.reply_rounded,
                  variant: AppButtonVariant.secondary,
                  onPressed: onReply,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _iconColorFor(StatusChipVariant variant) {
    switch (variant) {
      case StatusChipVariant.success:
        return AppColors.success;
      case StatusChipVariant.warning:
        return AppColors.warning;
      case StatusChipVariant.danger:
        return AppColors.error;
      case StatusChipVariant.info:
        return AppColors.info;
      case StatusChipVariant.primary:
        return AppColors.primary;
      case StatusChipVariant.neutral:
        return AppColors.neutral700;
    }
  }
}

enum _TransferChoice { accept, decline }
