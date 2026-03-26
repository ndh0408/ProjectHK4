import 'package:flutter/foundation.dart';
import 'local_notification_service.dart';

/// Stub implementation for Web platform
LocalNotificationService createLocalNotificationService() => _WebNotificationService();

class _WebNotificationService implements LocalNotificationService {
  @override
  Future<void> initialize() async {
    debugPrint('LocalNotificationService: Web platform - local notifications not supported');
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Web doesn't support local notifications in the same way
    debugPrint('Web notification: $title - $body');
  }
}
