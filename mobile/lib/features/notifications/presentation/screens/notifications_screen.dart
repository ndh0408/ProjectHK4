import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../services/notification_service.dart'
    show notificationStreamProvider;
import '../../../../shared/models/notification.dart';
import '../../../../shared/models/event_buddy.dart';
import '../../../../shared/models/conversation.dart';
import '../../../../shared/widgets/app_components.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../main/presentation/screens/main_shell.dart';

final notificationsProvider = StateNotifierProvider.autoDispose<
    NotificationsNotifier, NotificationsState>((ref) {
  final user = ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  final notifier = NotificationsNotifier(api, ref, isLoggedIn: user != null);

  final subscription = ref.listen<AsyncValue<AppNotification>>(
    notificationStreamProvider,
    (previous, next) {
      next.whenData((notification) {
        notifier.addNotification(notification);
      });
    },
  );

  ref.onDispose(() {
    subscription.close();
  });

  return notifier;
});

final eventBuddiesProvider =
    StateNotifierProvider.autoDispose<EventBuddiesNotifier, EventBuddiesState>(
        (ref) {
  final user = ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  return EventBuddiesNotifier(api, isLoggedIn: user != null);
});

class EventBuddiesState {
  const EventBuddiesState({
    this.buddies = const [],
    this.isLoading = false,
    this.error,
    this.selectedBuddies = const [],
    this.searchQuery = '',
    this.filterEventId,
  });

  final List<EventBuddy> buddies;
  final bool isLoading;
  final String? error;
  final List<EventBuddy> selectedBuddies;
  final String searchQuery;
  final String? filterEventId;

  List<EventBuddy> get filteredBuddies {
    var result = buddies;

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      result = result
          .where((buddy) => buddy.fullName.toLowerCase().contains(query))
          .toList();
    }

    if (filterEventId != null) {
      result = result
          .where((buddy) =>
              buddy.sharedEvents?.any((e) => e.eventId == filterEventId) ??
              false)
          .toList();
    }

    return result;
  }

  List<SharedEventInfo> get uniqueEvents {
    final eventsMap = <String, SharedEventInfo>{};
    for (final buddy in buddies) {
      if (buddy.sharedEvents != null) {
        for (final event in buddy.sharedEvents!) {
          eventsMap[event.eventId] = event;
        }
      }
    }
    return eventsMap.values.toList()
      ..sort((a, b) => (b.eventDate ?? DateTime.now())
          .compareTo(a.eventDate ?? DateTime.now()));
  }

  EventBuddiesState copyWith({
    List<EventBuddy>? buddies,
    bool? isLoading,
    String? error,
    List<EventBuddy>? selectedBuddies,
    String? searchQuery,
    String? filterEventId,
    bool clearFilter = false,
  }) {
    return EventBuddiesState(
      buddies: buddies ?? this.buddies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedBuddies: selectedBuddies ?? this.selectedBuddies,
      searchQuery: searchQuery ?? this.searchQuery,
      filterEventId: clearFilter ? null : (filterEventId ?? this.filterEventId),
    );
  }
}

class EventBuddiesNotifier extends StateNotifier<EventBuddiesState> {
  EventBuddiesNotifier(this._api, {this.isLoggedIn = false})
      : super(const EventBuddiesState());

  final ApiService _api;
  final bool isLoggedIn;

  Future<void> loadBuddies() async {
    if (!isLoggedIn) return;
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final buddies = await _api.getEventBuddies();
      if (mounted) {
        state = state.copyWith(
          buddies: buddies,
          isLoading: false,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load event buddies',
        );
      }
    }
  }

  void toggleBuddySelection(EventBuddy buddy) {
    final isSelected =
        state.selectedBuddies.any((b) => b.userId == buddy.userId);
    if (isSelected) {
      state = state.copyWith(
        selectedBuddies: state.selectedBuddies
            .where((b) => b.userId != buddy.userId)
            .toList(),
      );
    } else {
      state = state.copyWith(
        selectedBuddies: [...state.selectedBuddies, buddy],
      );
    }
  }

  void clearSelection() {
    state = state.copyWith(selectedBuddies: []);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setEventFilter(String? eventId) {
    if (eventId == null) {
      state = state.copyWith(clearFilter: true);
    } else {
      state = state.copyWith(filterEventId: eventId);
    }
  }

  void clearFilters() {
    state = state.copyWith(searchQuery: '', clearFilter: true);
  }

  Future<void> refresh() async {
    await loadBuddies();
  }
}

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.hasMore = true,
    this.currentPage = 0,
  });

  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final bool hasMore;
  final int currentPage;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    bool? hasMore,
    int? currentPage,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._api, this._ref, {this.isLoggedIn = false})
      : super(const NotificationsState());

  final ApiService _api;
  final Ref _ref;
  final bool isLoggedIn;

  void addNotification(AppNotification notification) {
    final exists = state.notifications.any((n) => n.id == notification.id);
    if (exists) return;

    state = state.copyWith(
      notifications: [notification, ...state.notifications],
    );
    debugPrint('WebSocket: Added new notification ${notification.id}');
  }

  Future<void> loadNotifications({bool refresh = false}) async {
    debugPrint('=== loadNotifications called ===');
    debugPrint('isLoggedIn: $isLoggedIn');

    if (!isLoggedIn) {
      debugPrint('Not logged in, skipping load');
      return;
    }
    if (state.isLoading) {
      debugPrint('Already loading, skipping');
      return;
    }
    if (!refresh && !state.hasMore) {
      debugPrint('No more data to load');
      return;
    }

    final page = refresh ? 0 : state.currentPage;
    debugPrint('Loading page: $page');

    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _api.getNotifications(page: page);
      debugPrint('Got ${response.content.length} notifications');

      final newNotifications = refresh
          ? response.content
          : [...state.notifications, ...response.content];

      if (mounted) {
        state = state.copyWith(
          notifications: newNotifications,
          isLoading: false,
          hasMore: response.hasMore,
          currentPage: response.number + 1,
        );
        debugPrint(
            'State updated with ${newNotifications.length} notifications');
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load notifications',
        );
      }
    }
  }

  Future<bool> markAsRead(String id) async {
    try {
      await _api.markNotificationAsRead(id);
      state = state.copyWith(
        notifications: state.notifications.map((n) {
          if (n.id == id) {
            return n.copyWith(isRead: true);
          }
          return n;
        }).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      await _api.markAllNotificationsAsRead();
      state = state.copyWith(
        notifications:
            state.notifications.map((n) => n.copyWith(isRead: true)).toList(),
      );
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    await loadNotifications(refresh: true);
  }

  void removeNotificationsBySenderId(String senderId) {
    state = state.copyWith(
      notifications:
          state.notifications.where((n) => n.senderId != senderId).toList(),
    );
  }
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _unawaited(
      Future.microtask(() async {
        await ref
            .read(notificationsProvider.notifier)
            .loadNotifications(refresh: true);
        await ref.read(eventBuddiesProvider.notifier).loadBuddies();
      }),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _unawaited(ref.read(notificationsProvider.notifier).loadNotifications());
    }
  }

  void _unawaited(Future<void>? future) {}

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
    if (diff < 7) return '${diff} days ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'EVENT_APPROVED':
        return Icons.check_circle;
      case 'EVENT_REJECTED':
        return Icons.cancel;
      case 'REGISTRATION_APPROVED':
        return Icons.how_to_reg;
      case 'REGISTRATION_REJECTED':
        return Icons.person_off;
      case 'EVENT_REMINDER':
        return Icons.alarm;
      case 'EVENT_UPDATE':
        return Icons.update;
      case 'NEW_FOLLOWER':
        return Icons.person_add;
      case 'QUESTION_ANSWERED':
        return Icons.question_answer;
      case 'BROADCAST':
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'EVENT_APPROVED':
      case 'REGISTRATION_APPROVED':
        return AppColors.success;
      case 'EVENT_REJECTED':
      case 'REGISTRATION_REJECTED':
        return AppColors.error;
      case 'EVENT_REMINDER':
        return AppColors.warning;
      case 'NEW_FOLLOWER':
        return const Color(0xFF8B5CF6);
      case 'QUESTION_ANSWERED':
        return const Color(0xFF0EA5E9);
      case 'BROADCAST':
        return const Color(0xFFEAB308);
      default:
        return AppColors.primary;
    }
  }

  bool _shouldShowDateHeader(int index, List<AppNotification> notifications) {
    if (index == 0) return true;
    final current = notifications[index].createdAt;
    final previous = notifications[index - 1].createdAt;
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  Future<void> _startDirectChat(EventBuddy buddy) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final api = ref.read(apiServiceProvider);
      final conversation = await api.getDirectChat(buddy.userId);

      if (mounted) {
        Navigator.pop(context);
        context.push('/chat/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start chat: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showCreateGroupDialog() async {
    final selectedBuddies = ref.read(eventBuddiesProvider).selectedBuddies;
    if (selectedBuddies.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 2 buddies to create a group'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final groupNameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.group_add, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Create Group Chat'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                hintText: 'Enter group name...',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Text(
              'Members (${selectedBuddies.length})',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: selectedBuddies.length,
                itemBuilder: (context, index) {
                  final buddy = selectedBuddies[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          backgroundImage: buddy.avatarUrl != null
                              ? NetworkImage(buddy.avatarUrl!)
                              : null,
                          child: buddy.avatarUrl == null
                              ? Text(
                                  buddy.fullName.isNotEmpty
                                      ? buddy.fullName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 50,
                          child: Text(
                            buddy.fullName.split(' ').first,
                            style: const TextStyle(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (groupNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a group name'),
                  ),
                );
                return;
              }
              Navigator.pop(context, groupNameController.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _createGroupChat(result, selectedBuddies);
    }
  }

  Future<void> _createGroupChat(
      String groupName, List<EventBuddy> members) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final api = ref.read(apiServiceProvider);
      final conversation = await api.createGroupChat(
        name: groupName,
        participantIds: members.map((b) => b.userId).toList(),
      );

      ref.read(eventBuddiesProvider.notifier).clearSelection();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "$groupName" created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.push('/chat/${conversation.id}', extra: conversation);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create group: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationsProvider);
    final buddiesState = ref.watch(eventBuddiesProvider);
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final hasUnread = notificationState.notifications.any((n) => !n.isRead) ||
        unreadCountAsync.maybeWhen(
            data: (count) => count > 0, orElse: () => false);

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
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: AppRadius.allPill,
              ),
              child: const Icon(
                Icons.notifications_active,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LUMA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Online',
                        style: TextStyle(
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
        actions: [
          if (hasUnread && _tabController.index == 0)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: () async {
                final success = await ref
                    .read(notificationsProvider.notifier)
                    .markAllAsRead();
                if (success) {
                  ref.read(unreadNotificationCountProvider.notifier).setZero();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    ref
                        .read(unreadNotificationCountProvider.notifier)
                        .loadCount();
                  });
                }
              },
              icon: const Icon(Icons.done_all, size: 22),
              tooltip: 'Mark all as read',
            ),
          if (buddiesState.selectedBuddies.isNotEmpty &&
              _tabController.index == 1)
            IconButton(
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceVariant,
              ),
              onPressed: _showCreateGroupDialog,
              icon: Badge(
                label: Text('${buddiesState.selectedBuddies.length}'),
                child: const Icon(Icons.group_add, size: 22),
              ),
              tooltip: 'Create Group Chat',
            ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceVariant,
            ),
            onPressed: () {},
            icon: const Icon(Icons.more_vert, size: 22),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              0,
              AppSpacing.pageX,
              AppSpacing.md,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.allPill,
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications, size: 18),
                        const SizedBox(width: 6),
                        const Text('Notifications'),
                        if (hasUnread)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.brightness_1,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people, size: 18),
                        const SizedBox(width: 6),
                        const Text('Event Buddies'),
                        if (buddiesState.buddies.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              '${buddiesState.buddies.length}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notificationsProvider.notifier).refresh(),
                  child: notificationState.notifications.isEmpty &&
                          !notificationState.isLoading
                      ? _buildEmptyState()
                      : _buildChatMessages(notificationState),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
          _buildEventBuddiesTab(buddiesState),
        ],
      ),
    );
  }

  Widget _buildEventBuddiesTab(EventBuddiesState state) {
    if (state.isLoading && state.buddies.isEmpty) {
      return const LoadingState(message: 'Loading event buddies...');
    }

    if (state.error != null && state.buddies.isEmpty) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(eventBuddiesProvider.notifier).refresh(),
      );
    }

    if (state.buddies.isEmpty) {
      return EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No event buddies yet',
        subtitle:
            'Register for events to connect with attendees who share your interests.',
        actionLabel: 'Explore Events',
        onAction: () => context.go('/explore'),
      );
    }

    return Column(
      children: [
        if (state.selectedBuddies.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Row(
              children: [
                Text(
                  '${state.selectedBuddies.length} selected',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () =>
                      ref.read(eventBuddiesProvider.notifier).clearSelection(),
                  child: const Text('Clear'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: state.selectedBuddies.length >= 2
                      ? _showCreateGroupDialog
                      : null,
                  icon: const Icon(Icons.group_add, size: 18),
                  label: const Text('Create Group'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(eventBuddiesProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.buddies.length,
              itemBuilder: (context, index) {
                final buddy = state.buddies[index];
                final isSelected =
                    state.selectedBuddies.any((b) => b.userId == buddy.userId);
                return _BuddyTile(
                  buddy: buddy,
                  isSelected: isSelected,
                  onTap: () => _startDirectChat(buddy),
                  onLongPress: () => ref
                      .read(eventBuddiesProvider.notifier)
                      .toggleBuddySelection(buddy),
                  onSelect: () => ref
                      .read(eventBuddiesProvider.notifier)
                      .toggleBuddySelection(buddy),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      icon: Icons.notifications_none_rounded,
      title: 'No notifications yet',
      subtitle: 'Your notifications will appear here when there is activity.',
    );
  }

  Widget _buildChatMessages(NotificationsState state) {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: state.notifications.length + (state.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.notifications.length) {
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

        final notification = state.notifications[index];
        final showDateHeader =
            _shouldShowDateHeader(index, state.notifications);

        return Column(
          children: [
            if (showDateHeader) _buildDateHeader(notification.createdAt),
            _ChatMessageBubble(
              notification: notification,
              timeText: _formatTime(notification.createdAt),
              icon: _getNotificationIcon(notification.type),
              iconColor: _getNotificationColor(notification.type),
              onTap: () async {
                if (!notification.isRead) {
                  final success = await ref
                      .read(notificationsProvider.notifier)
                      .markAsRead(notification.id);
                  if (success) {
                    ref
                        .read(unreadNotificationCountProvider.notifier)
                        .decrement();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      ref
                          .read(unreadNotificationCountProvider.notifier)
                          .loadCount();
                    });
                  }
                }
                if (notification.relatedEventId != null) {
                  context.push('/event/${notification.relatedEventId}');
                }
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
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.divider,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Icon(Icons.emoji_emotions_outlined,
                color: AppColors.textLight, size: 26),
            const SizedBox(width: 16),
            Icon(Icons.image_outlined, color: AppColors.textLight, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(19),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Notifications are read-only',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.more_horiz, color: AppColors.textLight, size: 26),
          ],
        ),
      ),
    );
  }
}

class _BuddyTile extends StatelessWidget {
  const _BuddyTile({
    required this.buddy,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onSelect,
  });

  final EventBuddy buddy;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surface,
          border: Border(
            bottom: BorderSide(
              color: AppColors.divider,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onSelect,
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.textLight,
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.textOnPrimary,
                      )
                    : null,
              ),
            ),
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: buddy.avatarUrl != null
                      ? NetworkImage(buddy.avatarUrl!)
                      : null,
                  child: buddy.avatarUrl == null
                      ? Text(
                          buddy.fullName.isNotEmpty
                              ? buddy.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        '${buddy.sharedEventsCount}',
                        style: const TextStyle(
                          color: AppColors.textOnPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                  Text(
                    buddy.fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${buddy.sharedEventsCount} shared event${buddy.sharedEventsCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (buddy.sharedEvents != null &&
                      buddy.sharedEvents!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        buddy.sharedEvents!
                            .map((e) => e.eventTitle)
                            .take(2)
                            .join(', '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.notification,
    required this.timeText,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final AppNotification notification;
  final String timeText;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(18),
                        bottomRight: Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.textPrimary.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Flexible(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ..._buildMessageContent(notification.body),
                        if (notification.relatedEventId != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.open_in_new,
                                    size: 14, color: AppColors.primary),
                                const SizedBox(width: 5),
                                Text(
                                  'View Event',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                      if (notification.isRead) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.done_all,
                          size: 15,
                          color: const Color(0xFF0EA5E9),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 50),
        ],
      ),
    );
  }

  List<Widget> _buildMessageContent(String body) {
    if (body.contains('Q:') && body.contains('A:')) {
      final parts = body.split('\n\n');
      final widgets = <Widget>[];

      for (final part in parts) {
        if (part.startsWith('Q:')) {
          widgets.add(
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Your Question',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    part.substring(2).trim(),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          );
        } else if (part.startsWith('A:')) {
          widgets.add(
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline,
                          size: 14, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 4),
                      const Text(
                        'Answer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0EA5E9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    part.substring(2).trim(),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          );
        } else if (part.isNotEmpty) {
          widgets.add(
            Text(
              part,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          );
        }
      }

      return widgets;
    }

    return [
      Text(
        body,
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
      ),
    ];
  }
}
