import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/utils/responsive.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityState = ref.watch(connectivityProvider);
    final bannerHeight = Responsive.value(context, mobile: 36.0, tablet: 40.0);
    final bannerIconSize = Responsive.iconSize(context, base: 16);
    final bannerFontSize = Responsive.value(context, mobile: 12.0, tablet: 13.0);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: connectivityState.isOffline ? bannerHeight : 0,
          child: connectivityState.isOffline
              ? Material(
                  color: colorScheme.error,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.horizontalPadding(context),
                        vertical: Responsive.spacing(context, base: 6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: bannerIconSize,
                          ),
                          SizedBox(width: Responsive.spacing(context)),
                          Flexible(
                            child: Text(
                              'You are offline. Some features may be limited.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: bannerFontSize,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}

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

  void onBackOnline() {
  }

  void listenToConnectivityChanges() {
    ref.listen<ConnectivityState>(connectivityProvider, (previous, next) {
      if (_wasOffline && next.isOnline) {
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
