import 'package:flutter/foundation.dart';
import 'local_notification_service.dart';

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
    debugPrint('Web notification: $title - $body');
  }
}
