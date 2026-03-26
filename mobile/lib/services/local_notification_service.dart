import 'dart:convert';

import 'package:flutter/foundation.dart';

// Conditional imports
import 'local_notification_service_stub.dart'
    if (dart.library.io) 'local_notification_service_mobile.dart';

/// Abstract class for local notification service
/// Platform-specific implementations are in:
/// - local_notification_service_mobile.dart (Android/iOS)
/// - local_notification_service_stub.dart (Web fallback)
abstract class LocalNotificationService {
  factory LocalNotificationService() => createLocalNotificationService();

  Future<void> initialize();
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  });
}
