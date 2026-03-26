import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../core/storage/secure_storage.dart';
import '../core/constants/api_constants.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/main/presentation/screens/main_shell.dart';
import '../shared/models/notification.dart' as app;
import 'api_service.dart';
import 'local_notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});

final notificationServiceInitializerProvider = Provider<void>((ref) {
  final authState = ref.watch(authProvider);
  final notificationService = ref.read(notificationServiceProvider);

  if (authState is Authenticated) {
    Future.microtask(() async {
      await notificationService.initialize();
      notificationService.connect(authState.user.id);
      debugPrint('Notification service initialized for user: ${authState.user.id}');
    });
  } else if (authState is Unauthenticated) {
    Future.microtask(() {
      notificationService.disconnect();
      debugPrint('Notification service disconnected');
    });
  }
});

final notificationStreamProvider = StreamProvider<app.AppNotification>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.notificationStream;
});

class NotificationService {
  NotificationService(this._ref);

  final Ref _ref;
  StompClient? _stompClient;
  Timer? _pollingTimer;
  bool _isConnected = false;
  String? _userId;

  final _notificationController = StreamController<app.AppNotification>.broadcast();
  Stream<app.AppNotification> get notificationStream => _notificationController.stream;

  late final LocalNotificationService _localNotifications;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _localNotifications = LocalNotificationService();
    await _localNotifications.initialize();
    _initialized = true;
  }

  void connect(String userId) {
    _userId = userId;
    _connectStomp();
    _startPolling();
  }

  void disconnect() {
    _isConnected = false;
    _userId = null;
    _stompClient?.deactivate();
    _stompClient = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _connectStomp() async {
    if (_userId == null) return;

    if (kIsWeb) {
      debugPrint('WebSocket disabled on web platform, using polling only');
      return;
    }

    try {
      final storage = _ref.read(secureStorageProvider);
      final token = await storage.read(key: 'access_token');

      if (token == null) {
        debugPrint('No auth token available for WebSocket connection');
        return;
      }

      _stompClient = StompClient(
        config: StompConfig.sockJS(
          url: ApiConstants.wsBaseUrl,
          stompConnectHeaders: {
            'Authorization': 'Bearer $token',
          },
          webSocketConnectHeaders: {
            'Authorization': 'Bearer $token',
          },
          onConnect: _onStompConnected,
          onDisconnect: _onStompDisconnected,
          onStompError: _onStompError,
          onWebSocketError: _onWebSocketError,
          reconnectDelay: const Duration(seconds: 5),
        ),
      );

      _stompClient!.activate();
      debugPrint('STOMP client activating...');
    } catch (e) {
      debugPrint('STOMP connection error: $e');
    }
  }

  void _onStompConnected(StompFrame frame) {
    _isConnected = true;
    debugPrint('STOMP connected');

    _stompClient?.subscribe(
      destination: '/user/$_userId/queue/notifications',
      callback: _onNotificationReceived,
    );

    debugPrint('Subscribed to /user/$_userId/queue/notifications');
  }

  void _onStompDisconnected(StompFrame frame) {
    _isConnected = false;
    debugPrint('STOMP disconnected');
  }

  void _onStompError(StompFrame frame) {
    debugPrint('STOMP error: ${frame.body}');
    _isConnected = false;
  }

  void _onWebSocketError(dynamic error) {
    debugPrint('WebSocket error: $error');
    _isConnected = false;
  }

  void _onNotificationReceived(StompFrame frame) {
    try {
      if (frame.body == null) return;

      final data = jsonDecode(frame.body!) as Map<String, dynamic>;
      debugPrint('Notification received: $data');

      final notification = app.AppNotification.fromJson(data);
      _notificationController.add(notification);

      _ref.read(unreadNotificationCountProvider.notifier).refresh();

      _showLocalNotification(notification);
    } catch (e) {
      debugPrint('Error parsing notification: $e');
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isConnected) {
        _pollNotifications();
      }
    });
    _pollNotifications();
  }

  Future<void> _pollNotifications() async {
    try {
      _ref.read(unreadNotificationCountProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Error polling notifications: $e');
    }
  }

  Future<void> _showLocalNotification(app.AppNotification notification) async {
    if (!_initialized) return;

    final payload = jsonEncode({
      'id': notification.id,
      'type': notification.type,
      'relatedEventId': notification.relatedEventId,
    });

    await _localNotifications.show(
      id: notification.id.hashCode,
      title: notification.title,
      body: notification.body,
      payload: payload,
    );
  }

  Future<void> refreshUnreadCount() async {
    await _pollNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.markNotificationAsRead(notificationId);
      _ref.read(unreadNotificationCountProvider.notifier).decrement();
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.markAllNotificationsAsRead();
      _ref.read(unreadNotificationCountProvider.notifier).setZero();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  void dispose() {
    disconnect();
    _notificationController.close();
  }
}
