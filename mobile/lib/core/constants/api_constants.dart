import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

abstract final class ApiConstants {
  static String get _host {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }

  static String get baseUrl => 'http://$_host:8080/api';
  // Spring endpoint is registered with .withSockJS(), and both notification
  // and chat clients use SockJS transport. The client therefore expects the
  // HTTP endpoint base rather than a raw ws:// URL.
  static String get wsBaseUrl => 'http://$_host:8080/ws';
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';

  static const String events = '/events/upcoming';
  static const String categories = '/categories';
}

abstract final class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String user = 'user_data';
}
