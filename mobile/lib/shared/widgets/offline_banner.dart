import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';

/// Widget hiển thị banner khi offline
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);

    return Column(
      children: [
        // Offline banner
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: connectivityState.isOffline ? 32 : 0,
          child: connectivityState.isOffline
              ? Material(
                  color: Colors.red.shade700,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'You are offline. Some features may be limited.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Main content
        Expanded(child: child),
      ],
    );
  }
}

/// Mixin để thêm offline awareness vào các screens
mixin OfflineAwareMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
  }

  void _checkInitialConnectivity() {
    final state = ref.read(connectivityProvider);
    _wasOffline = state.isOffline;
  }

  /// Override này trong screen để refresh data khi online trở lại
  void onBackOnline() {
    // Override trong subclass để refresh data
  }

  void listenToConnectivityChanges() {
    ref.listen<ConnectivityState>(connectivityProvider, (previous, next) {
      if (_wasOffline && next.isOnline) {
        // Vừa online trở lại
        onBackOnline();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Back online! Syncing data...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      _wasOffline = next.isOffline;
    });
  }
}
