import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/l10n/app_localizations.dart';

import '../../../../core/config/theme.dart';
import '../../../../services/api_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../chat/presentation/screens/conversations_screen.dart';

// Notifier for unread notification count - allows immediate updates
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

// Use autoDispose to ensure state is cleared when user changes
final unreadNotificationCountProvider =
    StateNotifierProvider.autoDispose<UnreadCountNotifier, AsyncValue<int>>(
        (ref) {
  // Watch current user to refresh when user changes
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
    // Main tabs
    if (route == '/home') return 0;
    if (route == '/explore') return 1;
    if (route == '/my-events') return 2;
    if (route == '/notifications') return 3;
    if (route == '/profile') return 4;

    // Explore related pages - keep Explore tab selected
    if (route.startsWith('/search') ||
        route.startsWith('/categories') ||
        route.startsWith('/cities') ||
        route.startsWith('/organisers') ||
        route.startsWith('/events')) return 1;

    // My Events related pages - keep My Events tab selected
    if (route.startsWith('/ticket')) return 2;

    // Alerts related pages - keep Alerts tab selected
    if (route.startsWith('/chat')) return 3;

    // For other pages (event detail, organiser profile, speaker events),
    // keep the current index to avoid tab jumping
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unreadNotifications = ref.watch(unreadNotificationCountProvider);
    final unreadMessages = ref.watch(unreadMessageCountProvider);

    // Combine both counts for the badge
    final totalUnread = (unreadNotifications.valueOrNull ?? 0) +
        (unreadMessages.valueOrNull ?? 0);

    return Scaffold(
      body: widget.child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/create-event'),
        backgroundColor: AppColors.primary,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textLight,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 12,
            ),
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
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_outlined),
                    if (totalUnread > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            totalUnread > 99 ? '99+' : totalUnread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                activeIcon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_rounded),
                    if (totalUnread > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            totalUnread > 99 ? '99+' : totalUnread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
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
