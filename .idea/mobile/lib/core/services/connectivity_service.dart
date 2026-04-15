import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});

enum ConnectivityStatus {
  online,
  offline,
  checking,
}

class ConnectivityState {
  const ConnectivityState({
    required this.status,
    this.lastOnline,
  });

  final ConnectivityStatus status;
  final DateTime? lastOnline;

  bool get isOnline => status == ConnectivityStatus.online;
  bool get isOffline => status == ConnectivityStatus.offline;

  ConnectivityState copyWith({
    ConnectivityStatus? status,
    DateTime? lastOnline,
  }) {
    return ConnectivityState(
      status: status ?? this.status,
      lastOnline: lastOnline ?? this.lastOnline,
    );
  }
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  ConnectivityNotifier() : super(const ConnectivityState(status: ConnectivityStatus.checking)) {
    _init();
  }

  Timer? _periodicTimer;
  static const _checkInterval = Duration(seconds: 30);
  static const _timeout = Duration(seconds: 5);

  void _init() {
    _checkConnectivity();
    _periodicTimer = Timer.periodic(_checkInterval, (_) => _checkConnectivity());
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(_timeout);

      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        if (state.status != ConnectivityStatus.online) {
          state = ConnectivityState(
            status: ConnectivityStatus.online,
            lastOnline: DateTime.now(),
          );
        }
      } else {
        _setOffline();
      }
    } on SocketException catch (_) {
      _setOffline();
    } on TimeoutException catch (_) {
      _setOffline();
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      _setOffline();
    }
  }

  void _setOffline() {
    if (state.status != ConnectivityStatus.offline) {
      state = state.copyWith(status: ConnectivityStatus.offline);
    }
  }

  Future<void> checkNow() async {
    await _checkConnectivity();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
