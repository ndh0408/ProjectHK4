import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'api_service.dart';
import 'local_notification_service.dart';

/// FCM wiring. Splits cleanly by lifecycle stage:
///
///   1. `initializeFirebase()` — call once at app boot before runApp so the
///      background message handler can resolve FirebaseApp even when the
///      Dart VM is cold-started for a message.
///   2. `registerCurrentDeviceToken(api)` — call right after auth succeeds so
///      the backend knows which device belongs to which user. Also listens
///      for token rotations and re-registers.
///   3. `unregisterOnLogout(api)` — call on logout so old tokens don't keep
///      receiving the previous user's notifications.
///
/// All methods are no-ops if Firebase init fails (no google-services file
/// checked in yet) — the app still runs with WebSocket-only notifications.
class PushNotificationService {
  PushNotificationService(this._localNotifications);

  final LocalNotificationService _localNotifications;
  bool _firebaseReady = false;
  String? _lastRegisteredToken;

  static bool _backgroundHandlerRegistered = false;

  /// Top-level entrypoint for Firebase + permission setup. Safe to call again.
  Future<void> initialize() async {
    if (_firebaseReady) return;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase init failed — push disabled: $e');
      return;
    }

    if (!_backgroundHandlerRegistered) {
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
      _backgroundHandlerRegistered = true;
    }

    await _requestPermission();

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  Future<void> _requestPermission() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (Platform.isAndroid) {
      // Android 13+ needs POST_NOTIFICATIONS runtime permission.
      await Permission.notification.request();
    }
  }

  Future<void> registerCurrentDeviceToken(ApiService api) async {
    if (!_firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _pushTokenToBackend(api, token);

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await _pushTokenToBackend(api, newToken);
        } catch (e) {
          debugPrint('FCM token refresh upload failed: $e');
        }
      });
    } catch (e) {
      debugPrint('registerCurrentDeviceToken failed: $e');
    }
  }

  Future<void> _pushTokenToBackend(ApiService api, String token) async {
    if (token == _lastRegisteredToken) return;
    await api.registerDeviceToken(
      token: token,
      platform: _platformName(),
    );
    _lastRegisteredToken = token;
    debugPrint('Registered FCM token with backend');
  }

  Future<void> unregisterOnLogout(ApiService api) async {
    if (!_firebaseReady) return;
    try {
      final token = _lastRegisteredToken
          ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await api.unregisterDeviceToken(token);
      }
      // Drop the local token so the next user starts clean.
      await FirebaseMessaging.instance.deleteToken();
      _lastRegisteredToken = null;
    } catch (e) {
      debugPrint('unregisterOnLogout failed: $e');
    }
  }

  String _platformName() {
    if (kIsWeb) return 'WEB';
    if (Platform.isIOS) return 'IOS';
    return 'ANDROID';
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    final payload = message.data.isNotEmpty ? jsonEncode(message.data) : null;
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: notif.title ?? 'LUMA',
      body: notif.body ?? '',
      payload: payload,
    );
  }
}

/// Must be a top-level function — FCM re-enters the Dart VM with a fresh
/// isolate for background messages and can only dispatch to statics.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('Background FCM: ${message.messageId}');
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  return PushNotificationService(LocalNotificationService());
});
