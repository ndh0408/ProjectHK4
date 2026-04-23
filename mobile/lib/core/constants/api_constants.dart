import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class ApiConstants {
  static String get _host {
    // Allow override via .env — useful for physical devices where the
    // Android emulator alias 10.0.2.2 doesn't resolve. Set API_HOST to the
    // laptop's LAN IP, or to "localhost" when using `adb reverse tcp:8080`.
    final override = dotenv.maybeGet('API_HOST');
    if (override != null && override.isNotEmpty) return override;

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
  static const String verifyOtp = '/auth/verify-otp';
  static const String resendOtp = '/auth/resend-otp';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String qrLoginChallenge = '/auth/qr-login/challenge';
  static const String qrLoginApprove = '/auth/qr-login/approve';

  static const String events = '/events/upcoming';
  static const String categories = '/categories';
}

abstract final class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String user = 'user_data';
}
