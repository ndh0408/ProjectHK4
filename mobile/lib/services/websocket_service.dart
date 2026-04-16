import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../core/constants/api_constants.dart';
import '../core/storage/secure_storage.dart';
import '../features/auth/domain/auth_state.dart';
import '../features/auth/providers/auth_provider.dart';

enum ChatEventType {
  newMessage,
  messageDeleted,
  typing,
  read,
  online,
  offline,
}

class ChatEvent {
  final ChatEventType type;
  final String? conversationId;
  final Map<String, dynamic>? message;
  final String? userId;
  final String? userName;
  final bool? isOnline;
  final DateTime? lastSeen;

  ChatEvent({
    required this.type,
    this.conversationId,
    this.message,
    this.userId,
    this.userName,
    this.isOnline,
    this.lastSeen,
  });

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String?;
    ChatEventType type;
    switch (typeStr) {
      case 'NEW_MESSAGE':
        type = ChatEventType.newMessage;
        break;
      case 'MESSAGE_DELETED':
        type = ChatEventType.messageDeleted;
        break;
      case 'TYPING':
        type = ChatEventType.typing;
        break;
      case 'READ':
        type = ChatEventType.read;
        break;
      case 'ONLINE':
        type = ChatEventType.online;
        break;
      case 'OFFLINE':
        type = ChatEventType.offline;
        break;
      default:
        type = ChatEventType.newMessage;
    }

    return ChatEvent(
      type: type,
      conversationId: json['conversationId'] as String?,
      message: json['message'] as Map<String, dynamic>?,
      userId: json['userId'] as String?,
      userName: json['userName'] as String?,
      isOnline: json['isOnline'] as bool?,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
    );
  }
}

class WebSocketService {
  StompClient? _stompClient;
  final List<StompUnsubscribe> _subscriptions = [];
  bool _isConnected = false;
  String? _authToken;
  String? _userEmail;

  final _eventController = StreamController<ChatEvent>.broadcast();
  Stream<ChatEvent> get eventStream => _eventController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final _typingUsers = <String, Map<String, DateTime>>{};
  final _onlineUsers = <String, bool>{};

  bool get isConnected => _isConnected;
  Map<String, bool> get onlineUsers => Map.unmodifiable(_onlineUsers);

  void connect(String token, {String? userEmail}) {
    if (_isConnected && _authToken == token) return;

    _authToken = token;
    _userEmail = userEmail;
    disconnect();

    final wsUrl = ApiConstants.wsBaseUrl;

    final stompConfig = kIsWeb
        ? StompConfig.sockJS(
            url: wsUrl,
            onConnect: _onConnect,
            onDisconnect: _onDisconnect,
            onWebSocketError: _onError,
            onStompError: _onStompError,
            stompConnectHeaders: {
              'Authorization': 'Bearer $token',
            },
            webSocketConnectHeaders: {
              'Authorization': 'Bearer $token',
            },
            reconnectDelay: const Duration(seconds: 5),
          )
        : StompConfig(
            url: wsUrl,
            onConnect: _onConnect,
            onDisconnect: _onDisconnect,
            onWebSocketError: _onError,
            onStompError: _onStompError,
            stompConnectHeaders: {
              'Authorization': 'Bearer $token',
            },
            webSocketConnectHeaders: {
              'Authorization': 'Bearer $token',
            },
            reconnectDelay: const Duration(seconds: 5),
          );

    _stompClient = StompClient(config: stompConfig);
    _stompClient!.activate();
  }

  void _onConnect(StompFrame frame) {
    _isConnected = true;
    _connectionController.add(true);

    _subscribeToPresence();

    // Auto-subscribe to user queue for global message notifications
    if (_userEmail != null) {
      subscribeToUserQueue(_userEmail!);
    }
  }

  void _onDisconnect(StompFrame frame) {
    _isConnected = false;
    _connectionController.add(false);
    _clearSubscriptions();
  }

  void _onError(dynamic error) {
    _isConnected = false;
    _connectionController.add(false);
  }

  void _onStompError(StompFrame frame) {
    _isConnected = false;
    _connectionController.add(false);
  }

  void _subscribeToPresence() {
    if (_stompClient == null || !_isConnected) return;

    final sub = _stompClient!.subscribe(
      destination: '/topic/presence',
      callback: (frame) {
        if (frame.body != null) {
          final event = ChatEvent.fromJson(json.decode(frame.body!));
          _handlePresenceEvent(event);
          _eventController.add(event);
        }
      },
    );
    _subscriptions.add(sub);
  }

  void subscribeToConversation(String conversationId) {
    if (_stompClient == null || !_isConnected) return;

    final sub = _stompClient!.subscribe(
      destination: '/topic/conversation.$conversationId',
      callback: (frame) {
        if (frame.body != null) {
          final event = ChatEvent.fromJson(json.decode(frame.body!));
          _handleChatEvent(event, conversationId);
          _eventController.add(event);
        }
      },
    );
    _subscriptions.add(sub);
  }

  void subscribeToUserQueue(String userEmail) {
    if (_stompClient == null || !_isConnected) return;

    final sub = _stompClient!.subscribe(
      destination: '/user/$userEmail/queue/messages',
      callback: (frame) {
        if (frame.body != null) {
          final event = ChatEvent.fromJson(json.decode(frame.body!));
          _eventController.add(event);
        }
      },
    );
    _subscriptions.add(sub);
  }

  void _handlePresenceEvent(ChatEvent event) {
    if (event.userId != null) {
      if (event.type == ChatEventType.online) {
        _onlineUsers[event.userId!] = true;
      } else if (event.type == ChatEventType.offline) {
        _onlineUsers[event.userId!] = false;
      }
    }
  }

  void _handleChatEvent(ChatEvent event, String conversationId) {
    if (event.type == ChatEventType.typing && event.userId != null) {
      _typingUsers[conversationId] ??= {};
      _typingUsers[conversationId]![event.userId!] = DateTime.now();

      Future.delayed(const Duration(seconds: 3), () {
        final lastTyping = _typingUsers[conversationId]?[event.userId!];
        if (lastTyping != null &&
            DateTime.now().difference(lastTyping).inSeconds >= 3) {
          _typingUsers[conversationId]?.remove(event.userId!);
        }
      });
    }
  }

  void sendTyping(String conversationId) {
    if (_stompClient == null || !_isConnected) return;

    _stompClient!.send(
      destination: '/app/chat/$conversationId/typing',
      body: '',
    );
  }

  void sendRead(String conversationId) {
    if (_stompClient == null || !_isConnected) return;

    _stompClient!.send(
      destination: '/app/chat/$conversationId/read',
      body: '',
    );
  }

  List<String> getTypingUsers(String conversationId) {
    final typingMap = _typingUsers[conversationId];
    if (typingMap == null) return [];

    final now = DateTime.now();
    return typingMap.entries
        .where((e) => now.difference(e.value).inSeconds < 3)
        .map((e) => e.key)
        .toList();
  }

  bool isUserOnline(String userId) {
    return _onlineUsers[userId] ?? false;
  }

  void _clearSubscriptions() {
    for (final unsub in _subscriptions) {
      unsub();
    }
    _subscriptions.clear();
  }

  void disconnect() {
    _clearSubscriptions();
    _stompClient?.deactivate();
    _stompClient = null;
    _isConnected = false;
    _typingUsers.clear();
    _onlineUsers.clear();
  }

  void dispose() {
    disconnect();
    _eventController.close();
    _connectionController.close();
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  final storage = ref.watch(secureStorageProvider);

  ref.listen(authProvider, (previous, next) async {
    if (next is Authenticated) {
      final token = await storage.read(key: StorageKeys.accessToken);
      if (token != null) {
        service.connect(token, userEmail: next.user.email);
      }
    } else {
      service.disconnect();
    }
  }, fireImmediately: true);

  Future.microtask(() async {
    final authState = ref.read(authProvider);
    final token = await storage.read(key: StorageKeys.accessToken);
    if (token != null) {
      final email = authState is Authenticated ? authState.user.email : null;
      service.connect(token, userEmail: email);
    }
  });

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final chatEventStreamProvider = StreamProvider<ChatEvent>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.eventStream;
});

final wsConnectionStatusProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(webSocketServiceProvider);
  return service.connectionStream;
});

final userOnlineStatusProvider = Provider.family<bool, String>((ref, userId) {
  final service = ref.watch(webSocketServiceProvider);
  return service.isUserOnline(userId);
});
