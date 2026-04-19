import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/utils/calendar_utils.dart';
import '../../../../core/utils/error_utils.dart';
import '../../../../services/api_service.dart';
import '../../../../shared/models/event.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../home/providers/events_provider.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../explore/presentation/providers/comparison_provider.dart';
import 'contact_host_screen.dart';
import 'payment_screen.dart';
import 'registration_form_screen.dart';
import '../../../../shared/models/registration.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/models/ticket_type.dart';
import '../widgets/ticket_tier_picker.dart';
import '../../../home/presentation/widgets/similar_events_section.dart';

final eventDetailProvider =
    FutureProvider.family.autoDispose<Event, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getEventById(eventId);
});

final registrationStatusProvider =
    FutureProvider.family.autoDispose<RegistrationStatus, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  return api.getRegistrationStatus(eventId);
});

final eventReviewsProvider =
    FutureProvider.family.autoDispose<List<Review>, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  final response = await api.getEventReviews(eventId, size: 3);
  return response.content;
});

final canReviewProvider =
    FutureProvider.family.autoDispose<bool, String>((ref, eventId) async {
  final api = ref.watch(apiServiceProvider);
  return api.canReview(eventId);
});

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(apiServiceProvider).trackEventView(widget.eventId);
    });
  }

  Future<void> _register(Event event) async {
    TicketType? selectedTier;
    int selectedQty = 1;

    final visibleTiers = event.visibleTicketTypes;
    if (visibleTiers.isNotEmpty) {
      final result = await showTicketTierPicker(
        context: context,
        tiers: visibleTiers,
      );
      if (result == null) return;
      selectedTier = result.tier;
      selectedQty = result.quantity;
    }

    if (event.hasRegistrationQuestions) {
      final isFree = selectedTier != null
          ? selectedTier.isFree
          : (event.ticketPrice ?? 0) <= 0;
      final unitPrice = selectedTier?.price ?? event.ticketPrice;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => RegistrationFormScreen(
            eventId: widget.eventId,
            eventTitle: event.title,
            isFree: isFree,
            ticketPrice: unitPrice,
            ticketTypeId: selectedTier?.id,
            ticketTypeName: selectedTier?.name,
            quantity: selectedQty,
          ),
        ),
      );

      if (result == true) {
        _refreshData();
      }
    } else {
      _showConfirmRegistrationDialog(event, tier: selectedTier, quantity: selectedQty);
    }
  }

  void _showConfirmRegistrationDialog(Event event, {TicketType? tier, int quantity = 1}) {
    final l10n = AppLocalizations.of(context)!;
    final money = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final unit = tier?.price ?? event.ticketPrice ?? 0;
    final total = unit * quantity;
    final isFree = tier?.isFree ?? ((event.ticketPrice ?? 0) <= 0);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmRegistration),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.isFull
                  ? 'This event is full. Do you want to join the waitlist for "${event.title}"?'
                  : 'Do you want to register for "${event.title}"?',
            ),
            if (tier != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ticket', style: TextStyle(color: Colors.grey)),
                  Text(tier.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Quantity', style: TextStyle(color: Colors.grey)),
                  Text('$quantity'),
                ],
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    isFree ? 'FREE' : money.format(total),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performRegistration(event, tier: tier, quantity: quantity);
            },
            child: Text(event.isFull ? l10n.joinWaitlist : l10n.register),
          ),
        ],
      ),
    );
  }

  Future<void> _performRegistration(Event event, {TicketType? tier, int quantity = 1}) async {
    setState(() => _isRegistering = true);

    try {
      final api = ref.read(apiServiceProvider);
      final registration = await api.registerForEvent(
        widget.eventId,
        ticketTypeId: tier?.id,
        quantity: quantity,
      );

      final unitPrice = tier?.price ?? event.ticketPrice ?? 0;
      final totalAmount = unitPrice * quantity;
      final isFree = tier != null ? tier.isFree : unitPrice <= 0;
      if (!isFree) {
        if (!mounted) return;
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentScreen(
              registrationId: registration.id,
              eventTitle: event.title,
              amount: totalAmount,
              tierName: tier?.name,
              unitPrice: unitPrice,
              quantity: quantity,
            ),
          ),
        );

        if (result == true) {
          _refreshData();
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(event.isFull
                  ? l10n.addedToWaitlistSuccessfully
                  : l10n.successfullyRegistered),
              backgroundColor: AppColors.success,
            ),
          );
          _refreshData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.extractMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegistering = false);
      }
    }
  }

  void _refreshData() {
    ref.invalidate(eventDetailProvider(widget.eventId));
    ref.invalidate(registrationStatusProvider(widget.eventId));
    ref.invalidate(myFutureEventsProvider);
    ref.invalidate(pickedForYouEventsProvider);
    ref.invalidate(myFutureRegistrationsProvider);
  }

  Future<void> _openMaps(Event event) async {
    String query = event.address ?? event.location;
    if (event.latitude != null && event.longitude != null) {
      query = '${event.latitude},${event.longitude}';
    }
    final encodedAddress = Uri.encodeComponent(query);
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$encodedAddress',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _share(Event event) async {
    final eventUrl = 'https://luma.com/${event.title.replaceAll(' ', '')}';

    await Share.share(
      eventUrl,
      subject: event.title,
    );
  }

  Future<void> _addToCalendar(Event event) async {
    final l10n = AppLocalizations.of(context)!;
    final success = await CalendarUtils.addToGoogleCalendar(event);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.couldNotOpenCalendar),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _navigateToContact(Event event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactHostScreen(
          eventId: event.id,
          eventTitle: event.title,
          organiserName: event.organiserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvent = ref.watch(selectedEventProvider);

    if (selectedEvent == null) {
      final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

      return eventAsync.when(
        data: _buildEventDetail,
        loading: () => Scaffold(
          appBar: AppBar(),
          body: const LoadingState(message: 'Loading event...'),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorState(
            message: ErrorUtils.extractMessage(e),
            onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
          ),
        ),
      );
    }

    return _buildEventDetail(selectedEvent);
  }

  Widget _buildEventDetail(Event event) {
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final isNearlyFull = event.isAlmostFull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            actions: [
              _CompareButton(eventId: event.id),
              _BookmarkButton(eventId: event.id),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  event.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: event.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            child: const Icon(
                              Icons.event,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.event,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  if (event.isFull || isNearlyFull)
                    Positioned(
                      top: 100,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: event.isFull
                              ? AppColors.warning
                              : AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              event.isFull
                                  ? Icons.hourglass_top
                                  : Icons.local_fire_department,
                              size: 16,
                              color: AppColors.textOnPrimary,
                            ),
                            const SizedBox(width: 4),
                            Builder(
                              builder: (context) {
                                final l10n = AppLocalizations.of(context)!;
                                return Text(
                                  event.isFull ? l10n.waitlist.toUpperCase() : l10n.almostFull.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.textOnPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () =>
                        context.push('/organiser/${event.organiserId}'),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.1),
                            child: Text(
                              event.organiserName.isNotEmpty
                                  ? event.organiserName[0].toUpperCase()
                                  : 'O',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.organiserName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Builder(
                                  builder: (context) {
                                    final l10n = AppLocalizations.of(context)!;
                                    return Text(
                                      '${l10n.eventOrganiser} • ${l10n.tapToViewProfile}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.category?.name ?? 'Event',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: (event.ticketPrice ?? 0) > 0
                              ? AppColors.warning.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (event.ticketPrice ?? 0) > 0
                              ? '\$${event.price.toStringAsFixed(0)}'
                              : AppLocalizations.of(context)!.free.toUpperCase(),
                          style: TextStyle(
                            color: (event.ticketPrice ?? 0) > 0
                                ? AppColors.warning
                                : AppColors.success,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),

                  const SizedBox(height: 16),

                  _InfoRow(
                    icon: Icons.calendar_today,
                    title: AppLocalizations.of(context)!.date,
                    subtitle: dateFormat.format(event.startDate),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.access_time,
                    title: AppLocalizations.of(context)!.time,
                    subtitle:
                        '${timeFormat.format(event.startDate)} - ${timeFormat.format(event.endDate)}',
                  ),

                  if (event.registrationDeadline != null) ...[
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: event.isRegistrationClosed
                          ? Icons.lock_clock
                          : Icons.timer_outlined,
                      title: 'Registration Deadline',
                      subtitle: event.isRegistrationClosed
                          ? 'Closed on ${dateFormat.format(event.registrationDeadline!)}'
                          : '${dateFormat.format(event.registrationDeadline!)} at ${timeFormat.format(event.registrationDeadline!)}',
                    ),
                  ],

                  const SizedBox(height: 12),

                  InkWell(
                    onTap: () => _addToCalendar(event),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.addToCalendar,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (event.isRecurring) ...[
                    const SizedBox(height: 16),
                    _buildRecurringInfoSection(context, event),
                  ],

                  const SizedBox(height: 24),

                  Consumer(
                    builder: (context, ref, _) {
                      final currentUser = ref.watch(currentUserProvider);
                      final isOrganiser = currentUser != null && event.organiserId == currentUser.id;

                      if (isOrganiser) {
                        return _buildOrganiserActions(event);
                      }

                      final regStatusAsync = ref.watch(registrationStatusProvider(widget.eventId));

                      return regStatusAsync.when(
                        data: (regStatus) {
                          final l10n = AppLocalizations.of(context)!;
                          if (regStatus.isRegistered) {
                            Color statusColor;
                            IconData statusIcon;
                            String statusTitle;

                            if (regStatus.requiresPayment) {
                              statusColor = AppColors.warning;
                              statusIcon = Icons.payment;
                              statusTitle = l10n.paymentRequired;
                            } else if (regStatus.isOnWaitingList) {
                              statusColor = AppColors.primary;
                              statusIcon = Icons.access_time;
                              statusTitle = regStatus.waitingListPosition != null
                                  ? '${l10n.waitlist} #${regStatus.waitingListPosition}'
                                  : l10n.onWaitingList;
                            } else if (regStatus.status == RegistrationStatusEnum.pending) {
                              statusColor = AppColors.warning;
                              statusIcon = Icons.hourglass_empty;
                              statusTitle = l10n.pendingApproval;
                            } else if (regStatus.status == RegistrationStatusEnum.rejected) {
                              statusColor = AppColors.error;
                              statusIcon = Icons.cancel;
                              statusTitle = l10n.registrationRejected;
                            } else {
                              statusColor = AppColors.success;
                              statusIcon = Icons.check_circle;
                              statusTitle = l10n.youAreRegistered;
                            }

                            final needsPayment = regStatus.requiresPayment;

                            return Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: statusColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        statusIcon,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              statusTitle,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                            Text(
                                              regStatus.statusMessage ?? 'Registration confirmed',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: statusColor.withValues(alpha: 0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (needsPayment && regStatus.registrationId != null) ...[
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final result = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PaymentScreen(
                                              registrationId: regStatus.registrationId!,
                                              eventTitle: regStatus.eventTitle ?? event.title,
                                              amount: regStatus.ticketPrice ?? 0,
                                            ),
                                          ),
                                        );
                                        if (result == true) {
                                          _refreshData();
                                        }
                                      },
                                      icon: const Icon(Icons.payment),
                                      label: Text('Pay \$${regStatus.ticketPrice?.toStringAsFixed(2) ?? '0.00'}'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.chat_bubble_outline,
                                        label: AppLocalizations.of(context)!.contact,
                                        color: AppColors.primary,
                                        onTap: () => _navigateToContact(event),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.share,
                                        label: AppLocalizations.of(context)!.share,
                                        color: AppColors.secondary,
                                        onTap: () => _share(event),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          if (!event.canRegister && event.registrationStatusMessage != null) {
                            return Column(
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.textSecondary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        event.isEventEnded
                                            ? Icons.event_busy
                                            : event.isRegistrationClosed
                                                ? Icons.lock_clock
                                                : Icons.block,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          event.registrationStatusMessage!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.chat_bubble_outline,
                                        label: AppLocalizations.of(context)!.contact,
                                        color: AppColors.primary,
                                        onTap: () => _navigateToContact(event),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _ActionButton(
                                        icon: Icons.share,
                                        label: AppLocalizations.of(context)!.share,
                                        color: AppColors.secondary,
                                        onTap: () => _share(event),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  icon: event.isFull
                                      ? Icons.hourglass_top
                                      : Icons.how_to_reg,
                                  label: event.isFull ? AppLocalizations.of(context)!.waitlist : AppLocalizations.of(context)!.register,
                                  color: event.isFull
                                      ? AppColors.warning
                                      : AppColors.success,
                                  onTap: _isRegistering ? null : () => _register(event),
                                  isLoading: _isRegistering,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.chat_bubble_outline,
                                  label: AppLocalizations.of(context)!.contact,
                                  color: AppColors.primary,
                                  onTap: () => _navigateToContact(event),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.share,
                                  label: AppLocalizations.of(context)!.share,
                                  color: AppColors.secondary,
                                  onTap: () => _share(event),
                                ),
                              ),
                            ],
                          );
                        },
                        loading: () => Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.how_to_reg,
                                label: AppLocalizations.of(context)!.register,
                                color: AppColors.success,
                                onTap: null,
                                isLoading: true,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.chat_bubble_outline,
                                label: AppLocalizations.of(context)!.contact,
                                color: AppColors.primary,
                                onTap: () => _navigateToContact(event),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.share,
                                label: AppLocalizations.of(context)!.share,
                                color: AppColors.secondary,
                                onTap: () => _share(event),
                              ),
                            ),
                          ],
                        ),
                        error: (_, __) => Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: event.isFull
                                    ? Icons.hourglass_top
                                    : Icons.how_to_reg,
                                label: event.isFull ? AppLocalizations.of(context)!.waitlist : AppLocalizations.of(context)!.register,
                                color: event.isFull
                                    ? AppColors.warning
                                    : AppColors.success,
                                onTap: _isRegistering ? null : () => _register(event),
                                isLoading: _isRegistering,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.chat_bubble_outline,
                                label: AppLocalizations.of(context)!.contact,
                                color: AppColors.primary,
                                onTap: () => _navigateToContact(event),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.share,
                                label: AppLocalizations.of(context)!.share,
                                color: AppColors.secondary,
                                onTap: () => _share(event),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  InkWell(
                    onTap: () => _openMaps(event),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            child: Stack(
                              children: [
                                if (event.latitude != null && event.longitude != null)
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(12),
                                    ),
                                    child: AbsorbPointer(
                                      child: FlutterMap(
                                        options: MapOptions(
                                          initialCenter: LatLng(
                                            event.latitude!,
                                            event.longitude!,
                                          ),
                                          initialZoom: 15,
                                          interactionOptions: const InteractionOptions(
                                            flags: InteractiveFlag.none,
                                          ),
                                        ),
                                        children: [
                                          TileLayer(
                                            urlTemplate:
                                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                            userAgentPackageName: 'com.luma.mobile',
                                          ),
                                          MarkerLayer(
                                            markers: [
                                              Marker(
                                                point: LatLng(
                                                  event.latitude!,
                                                  event.longitude!,
                                                ),
                                                width: 40,
                                                height: 40,
                                                child: const Icon(
                                                  Icons.location_on,
                                                  color: AppColors.primary,
                                                  size: 40,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  _buildMapPlaceholder(),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.textPrimary
                                              .withValues(alpha: 0.1),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.open_in_new,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          AppLocalizations.of(context)!.openMaps,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primary.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event.location,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (event.address != null)
                                        Text(
                                          event.address!,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    AppLocalizations.of(context)!.aboutThisEvent,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  MarkdownBody(
                    data: event.description ?? '',
                    selectable: true,
                    styleSheet: MarkdownStyleSheet(
                      p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                      h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      listBullet: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                      blockSpacing: 12,
                    ),
                    onTapLink: (text, href, title) {
                      if (href != null) {
                        launchUrl(Uri.parse(href));
                      }
                    },
                  ),

                  if (event.visibleTicketTypes.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Ticket Types',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...event.visibleTicketTypes.map((tier) => _TierSummaryCard(tier: tier)),
                  ],

                  if (event.speakers != null && event.speakers!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      AppLocalizations.of(context)!.speakers,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ...event.speakers!.map((speaker) => InkWell(
                          onTap: () {
                            context.push(
                              '/speaker-events',
                              extra: {
                                'speakerName': speaker.name,
                                'speakerTitle': speaker.title,
                                'speakerImageUrl': speaker.imageUrl,
                                'speakerBio': speaker.bio,
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      AppColors.secondary.withValues(alpha: 0.1),
                                  backgroundImage: speaker.imageUrl != null
                                      ? CachedNetworkImageProvider(
                                          speaker.imageUrl!)
                                      : null,
                                  child: speaker.imageUrl == null
                                      ? Text(
                                          speaker.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        speaker.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (speaker.title != null)
                                        Text(
                                          speaker.title!,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                        ),
                                      Text(
                                        AppLocalizations.of(context)!.tapToSeeEvents,
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/event/${event.id}/polls',
                            extra: {'eventTitle': event.title},
                          ),
                          icon: const Icon(Icons.poll, size: 18),
                          label: const Text('Live Polls'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/event/${event.id}/schedule',
                            extra: {'eventTitle': event.title},
                          ),
                          icon: const Icon(Icons.calendar_month, size: 18),
                          label: const Text('Schedule'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _ReviewsSection(
                    event: event,
                    onWriteReview: () async {
                      final result = await context.push<bool>(
                        '/event/${event.id}/write-review',
                        extra: {'eventTitle': event.title},
                      );
                      if (result == true) {
                        _refreshData();
                        ref.invalidate(eventReviewsProvider(event.id));
                      }
                    },
                  ),

                  const SizedBox(height: 32),

                  SimilarEventsSection(eventId: event.id),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrganiserActions(Event event) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.admin_panel_settings,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.youAreTheOrganiser,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Status: ${event.status.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.people,
                label: AppLocalizations.of(context)!.registrations,
                color: AppColors.primary,
                onTap: () => context.push('/event-registrations/${widget.eventId}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.edit,
                label: AppLocalizations.of(context)!.editEvent,
                color: AppColors.secondary,
                onTap: () async {
                  final result = await context.push<bool>('/edit-event/${widget.eventId}');
                  if (result == true) {
                    _refreshData();
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionButton(
                icon: Icons.share,
                label: AppLocalizations.of(context)!.share,
                color: AppColors.success,
                onTap: () => _share(event),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecurringInfoSection(BuildContext context, Event event) {
    String recurrenceLabel;
    switch (event.recurrenceType) {
      case RecurrenceType.daily:
        recurrenceLabel = 'Daily';
        break;
      case RecurrenceType.weekly:
        recurrenceLabel = 'Weekly';
        break;
      case RecurrenceType.biweekly:
        recurrenceLabel = 'Biweekly';
        break;
      case RecurrenceType.monthly:
        recurrenceLabel = 'Monthly';
        break;
      default:
        recurrenceLabel = 'Recurring';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.repeat_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recurring Event',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      recurrenceLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${event.occurrenceIndex ?? 1}/${event.totalOccurrences}',
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (event.recurrenceType == RecurrenceType.weekly &&
              event.recurrenceDaysOfWeek != null &&
              event.recurrenceDaysOfWeek!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: event.recurrenceDaysOfWeek!.map((day) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getDayName(day),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if (event.recurrenceEndDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.event_busy,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Ends: ${DateFormat('MMM dd, yyyy').format(event.recurrenceEndDate!)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getDayName(String day) {
    switch (day.toUpperCase()) {
      case 'MON':
      case 'MONDAY':
        return 'Mon';
      case 'TUE':
      case 'TUESDAY':
        return 'Tue';
      case 'WED':
      case 'WEDNESDAY':
        return 'Wed';
      case 'THU':
      case 'THURSDAY':
        return 'Thu';
      case 'FRI':
      case 'FRIDAY':
        return 'Fri';
      case 'SAT':
      case 'SATURDAY':
        return 'Sat';
      case 'SUN':
      case 'SUNDAY':
        return 'Sun';
      default:
        return day;
    }
  }

  Widget _buildMapPlaceholder() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.map_outlined,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tapToOpenInMaps,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            if (isLoading)
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            else
              Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({
    required this.event,
    required this.onWriteReview,
  });

  final Event event;
  final VoidCallback onWriteReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final reviewsAsync = ref.watch(eventReviewsProvider(event.id));
    final canReviewAsync = ref.watch(canReviewProvider(event.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.reviews,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (event.averageRating != null && event.reviewCount > 0)
              Row(
                children: [
                    const Icon(Icons.star, color: AppColors.warning, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    event.averageRating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '(${event.reviewCount})',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),

        canReviewAsync.when(
          data: (canReview) {
            if (canReview) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onWriteReview,
                    icon: const Icon(Icons.rate_review),
                    label: Text(l10n.writeReview),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        reviewsAsync.when(
          data: (reviews) {
            if (reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noReviews,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.noReviewsSubtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                ...reviews.map((review) => _ReviewCard(review: review)),
                if (event.reviewCount > 3)
                  TextButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => DraggableScrollableSheet(
                          initialChildSize: 0.7,
                          maxChildSize: 0.9,
                          minChildSize: 0.4,
                          expand: false,
                          builder: (context, scrollController) => _AllReviewsSheet(
                            eventId: event.id,
                            scrollController: scrollController,
                          ),
                        ),
                      );
                    },
                    child: Text(l10n.seeAllReviews),
                  ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: review.userAvatarUrl != null
                    ? CachedNetworkImageProvider(review.userAvatarUrl!)
                    : null,
                child: review.userAvatarUrl == null
                    ? Text(
                        (review.userName ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName ?? 'Anonymous',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < review.rating
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: AppColors.warning,
                          );
                        }),
                        const SizedBox(width: 8),
                        if (review.createdAt != null)
                          Text(
                            _formatDate(review.createdAt!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment!,
              style: const TextStyle(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

class _CompareButton extends ConsumerWidget {
  const _CompareButton({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectedEventsForComparisonProvider);
    final isSelected = selectedIds.contains(eventId);
    final canAdd = selectedIds.length < 4;

    return IconButton(
      icon: Icon(
        Icons.compare_arrows,
        color: isSelected
            ? AppColors.primary
            : AppColors.textOnPrimary,
      ),
      style: IconButton.styleFrom(
        backgroundColor: isSelected
            ? AppColors.primary.withValues(alpha: 0.2)
            : AppColors.textPrimary.withValues(alpha: 0.3),
      ),
      onPressed: () {
        final notifier = ref.read(selectedEventsForComparisonProvider.notifier);
        
        if (isSelected) {
          notifier.removeEventId(eventId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Removed from comparison'),
              backgroundColor: AppColors.textSecondary,
              duration: const Duration(seconds: 1),
            ),
          );
        } else if (canAdd) {
          notifier.addEventId(eventId);
          final newCount = selectedIds.length + 1;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to comparison ($newCount/4)'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 1),
              action: newCount >= 2
                  ? SnackBarAction(
                      label: 'Compare',
                      textColor: AppColors.textOnPrimary,
                      onPressed: () {
                        context.push(
                          '/compare-events',
                          extra: {'eventIds': selectedIds + [eventId]},
                        );
                      },
                    )
                  : null,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Maximum 4 events for comparison'),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
    );
  }
}

class _BookmarkButton extends ConsumerWidget {
  const _BookmarkButton({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkNotifierProvider);
    final isBookmarked = bookmarks.contains(eventId);
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      icon: Icon(
        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
        color: isBookmarked ? AppColors.primary : AppColors.textOnPrimary,
      ),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.textPrimary.withValues(alpha: 0.3),
      ),
      onPressed: () async {
        final result = await ref.read(bookmarkNotifierProvider.notifier).toggle(eventId);
        if (context.mounted) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(result ? l10n.addedToSaved : l10n.removedFromSaved),
              backgroundColor: result ? AppColors.success : AppColors.textSecondary,
              duration: const Duration(milliseconds: 1500),
              behavior: SnackBarBehavior.floating,
              action: result
                  ? SnackBarAction(
                      label: l10n.viewAll,
                      textColor: AppColors.textOnPrimary,
                      onPressed: () => context.push('/saved-events'),
                    )
                  : null,
            ),
          );
        }
      },
    );
  }
}

class _AllReviewsSheet extends ConsumerStatefulWidget {
  const _AllReviewsSheet({required this.eventId, required this.scrollController});
  final String eventId;
  final ScrollController scrollController;

  @override
  ConsumerState<_AllReviewsSheet> createState() => _AllReviewsSheetState();
}

class _AllReviewsSheetState extends ConsumerState<_AllReviewsSheet> {
  List<Review> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final api = ref.read(apiServiceProvider);
      final response = await api.getEventReviews(widget.eventId, size: 50);
      if (mounted) {
        setState(() {
          _reviews = response.content;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l10n.seeAllReviews,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _reviews.isEmpty
                  ? Center(child: Text(l10n.noReviews))
                  : ListView.builder(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _reviews.length,
                      itemBuilder: (context, index) =>
                          _ReviewCard(review: _reviews[index]),
                    ),
        ),
      ],
    );
  }
}

class _TierSummaryCard extends StatelessWidget {
  const _TierSummaryCard({required this.tier});
  final TicketType tier;

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final enabled = !tier.isSoldOut && tier.availableQuantity > 0;

    final Color statusColor = enabled ? AppColors.success : AppColors.error;
    final String? statusLabel = enabled ? null : 'Sold out';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: enabled ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tier.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                tier.isFree ? 'FREE' : money.format(tier.price),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: tier.isFree ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          if ((tier.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tier.description!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                tier.isSoldOut
                    ? 'Sold out'
                    : '${tier.availableQuantity} / ${tier.quantity} left',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 12),
              Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Max ${tier.maxPerOrder}/order',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          if (statusLabel != null) ...[
            const SizedBox(height: 6),
            Text(
              statusLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ],
        ],
      ),
    );
  }
}
