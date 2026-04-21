import 'dart:async';
import 'dart:convert';

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
  bool _isConnected = false;
  String? _authToken;

  // Intent: conversations this client wants real-time updates for.
  // Survives reconnects so we can resubscribe after a dropped connection.
  final Set<String> _desiredConversations = {};
  // Live subscription handles; cleared on disconnect (connection is dead).
  final Map<String, StompUnsubscribe> _conversationSubs = {};
  StompUnsubscribe? _presenceSub;
  StompUnsubscribe? _userQueueSub;

  final _eventController = StreamController<ChatEvent>.broadcast();
  Stream<ChatEvent> get eventStream => _eventController.stream;

  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  final _typingUsers = <String, Map<String, DateTime>>{};
  final _onlineUsers = <String, bool>{};

  bool get isConnected => _isConnected;
  Map<String, bool> get onlineUsers => Map.unmodifiable(_onlineUsers);

  void connect(String token) {
    if (_isConnected && _authToken == token) return;

    _authToken = token;
    disconnect(keepDesired: true);

    final wsUrl = ApiConstants.wsBaseUrl;

    final stompConfig = StompConfig.sockJS(
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

    _subscribePresence();
    _subscribeUserQueue();

    // Replay all previously-desired conversation subscriptions
    for (final conversationId in _desiredConversations) {
      _subscribeConversationInternal(conversationId);
    }
  }

  void _onDisconnect(StompFrame frame) {
    _isConnected = false;
    _connectionController.add(false);
    // Stomp connection is dead — drop handles so we don't try to unsubscribe
    // on the next reconnect. _desiredConversations stays intact for replay.
    _conversationSubs.clear();
    _presenceSub = null;
    _userQueueSub = null;
  }

  void _onError(dynamic error) {
    _isConnected = false;
    _connectionController.add(false);
  }

  void _onStompError(StompFrame frame) {
    _isConnected = false;
    _connectionController.add(false);
  }

  void _subscribePresence() {
    if (_stompClient == null || !_isConnected) return;
    _presenceSub?.call();
    _presenceSub = _stompClient!.subscribe(
      destination: '/topic/presence',
      callback: (frame) {
        if (frame.body != null) {
          final event = ChatEvent.fromJson(json.decode(frame.body!));
          _handlePresenceEvent(event);
          _eventController.add(event);
        }
      },
    );
  }

  void _subscribeUserQueue() {
    if (_stompClient == null || !_isConnected) return;
    _userQueueSub?.call();
    // Spring user destinations: client subscribes to /user/queue/... and
    // Spring resolves the authenticated principal from the STOMP session.
    // Do NOT include the username in the path — the server sends via
    // convertAndSendToUser(email, "/queue/messages", ...), which routes
    // internally to /queue/messages-user<sessionId>.
    _userQueueSub = _stompClient!.subscribe(
      destination: '/user/queue/messages',
      callback: (frame) {
        if (frame.body != null) {
          final event = ChatEvent.fromJson(json.decode(frame.body!));
          // If this conversation already has a topic subscription the same
          // event will arrive from /topic/conversation.$id.  Skip the
          // duplicate here so listeners never see it twice.
          if (event.conversationId != null &&
              _conversationSubs.containsKey(event.conversationId) &&
              (event.type == ChatEventType.newMessage ||
               event.type == ChatEventType.messageDeleted)) {
            return;
          }
          _eventController.add(event);
        }
      },
    );
  }

  void subscribeToConversation(String conversationId) {
    _desiredConversations.add(conversationId);
    _subscribeConversationInternal(conversationId);
  }

  void _subscribeConversationInternal(String conversationId) {
    if (_stompClient == null || !_isConnected) return;
    if (_conversationSubs.containsKey(conversationId)) return;

    final unsub = _stompClient!.subscribe(
      destination: '/topic/conversation.$conversationId',
      callback: (frame) {
        if (frame.body != null) {
          final event = ChatEvent.fromJson(json.decode(frame.body!));
          _handleChatEvent(event, conversationId);
          _eventController.add(event);
        }
      },
    );
    _conversationSubs[conversationId] = unsub;
  }

  void unsubscribeFromConversation(String conversationId) {
    _desiredConversations.remove(conversationId);
    final unsub = _conversationSubs.remove(conversationId);
    unsub?.call();
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

  void disconnect({bool keepDesired = false}) {
    _conversationSubs.clear();
    _presenceSub = null;
    _userQueueSub = null;
    _stompClient?.deactivate();
    _stompClient = null;
    _isConnected = false;
    _typingUsers.clear();
    _onlineUsers.clear();
    if (!keepDesired) {
      _desiredConversations.clear();
    }
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
        service.connect(token);
      }
    } else {
      service.disconnect();
    }
  }, fireImmediately: true);

  Future.microtask(() async {
    final token = await storage.read(key: StorageKeys.accessToken);
    if (token != null) {
      service.connect(token);
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

// Re-evaluates whenever any chat event arrives (which includes ONLINE/OFFLINE),
// so widgets watching it get live rebuilds when presence changes.
final userOnlineStatusProvider = Provider.family<bool, String>((ref, userId) {
  ref.watch(chatEventStreamProvider);
  final service = ref.watch(webSocketServiceProvider);
  return service.isUserOnline(userId);
});
