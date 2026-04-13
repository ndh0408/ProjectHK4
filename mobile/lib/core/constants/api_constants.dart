abstract final class ApiConstants {
  static const String baseUrl = 'http://localhost:8080/api';
  static const String wsBaseUrl = 'http://localhost:8080/ws';
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
