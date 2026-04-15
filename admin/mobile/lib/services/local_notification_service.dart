import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_notification_service_stub.dart'
    if (dart.library.io) 'local_notification_service_mobile.dart';

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
