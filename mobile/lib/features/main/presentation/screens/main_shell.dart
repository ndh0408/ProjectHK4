import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/design_tokens/design_tokens.dart';
import '../../../../services/api_service.dart';
import '../../../../services/websocket_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/presentation/screens/conversations_screen.dart';

class UnreadCountNotifier extends StateNotifier<AsyncValue<int>> {
  UnreadCountNotifier(this._api, {bool isLoggedIn = false})
      : super(const AsyncValue.data(0)) {
    if (isLoggedIn) {
      loadCount();
    }
  }

  final ApiService _api;

  Future<void> loadCount() async {
    try {
      final response = await _api.getNotifications(page: 0, size: 100);
      final count = response.content.where((n) => !n.isRead).length;
      if (mounted) {
        state = AsyncValue.data(count);
      }
    } catch (e) {
      if (mounted) {
        state = const AsyncValue.data(0);
      }
    }
  }

  void decrement() {
    state.whenData((count) {
      if (count > 0) {
        state = AsyncValue.data(count - 1);
      }
    });
  }

  void setZero() {
    state = const AsyncValue.data(0);
  }

  void refresh() {
    loadCount();
  }
}

final unreadNotificationCountProvider =
    StateNotifierProvider.autoDispose<UnreadCountNotifier, AsyncValue<int>>(
        (ref) {
  final user = ref.watch(currentUserProvider);
  final api = ref.watch(apiServiceProvider);
  return UnreadCountNotifier(api, isLoggedIn: user != null);
});

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final List<String> _routes = [
    '/home',
    '/explore',
    '/my-events',
    '/notifications',
    '/profile',
  ];

  void _onItemTapped(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
      context.go(_routes[index]);
    }
  }

  int _getIndexFromRoute(String route) {
    if (route == '/home') return 0;
    if (route == '/explore') return 1;
    if (route == '/my-events') return 2;
    if (route == '/notifications') return 3;
    if (route == '/profile') return 4;

    if (route.startsWith('/search') ||
        route.startsWith('/categories') ||
        route.startsWith('/cities') ||
        route.startsWith('/organisers') ||
        route.startsWith('/events')) return 1;

    if (route.startsWith('/ticket')) return 2;

    if (route.startsWith('/chat')) return 3;

    return _currentIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.toString();
    final newIndex = _getIndexFromRoute(location);
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  Widget _buildBadge(int count) {
    if (count <= 0) return const SizedBox.shrink();
    return Positioned(
      right: -8,
      top: -6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppRadius.allPill,
          border: Border.all(color: AppColors.surface, width: 1.5),
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: AppTypography.caption.copyWith(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, {int badge = 0}) => Stack(
        clipBehavior: Clip.none,
        children: [Icon(icon), _buildBadge(badge)],
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final unreadMessages = ref.watch(unreadMessageCountProvider);

    ref.listen<AsyncValue<ChatEvent>>(chatEventStreamProvider, (previous, next) {
      next.whenData((event) {
        if (event.type == ChatEventType.newMessage) {
          ref.read(unreadMessageCountProvider.notifier).loadCount();
        }
      });
    });

    final totalUnread = (unreadNotifications.valueOrNull ?? 0) +
        (unreadMessages.valueOrNull ?? 0);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: AppColors.divider, width: 1),
          ),
          boxShadow: AppShadows.sm,
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home_rounded),
                label: l10n.home,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.explore_outlined),
                activeIcon: const Icon(Icons.explore_rounded),
                label: l10n.explore,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.calendar_today_outlined),
                activeIcon: const Icon(Icons.calendar_today_rounded),
                label: l10n.myEvents,
              ),
              BottomNavigationBarItem(
                icon: _navIcon(Icons.notifications_outlined, badge: totalUnread),
                activeIcon: _navIcon(Icons.notifications_rounded, badge: totalUnread),
                label: l10n.alerts,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person_rounded),
                label: l10n.profile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
