import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../shared/models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  );
});

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

class RegisterRequest {
  const RegisterRequest({
    required this.email,
    required this.password,
    this.fullName,
    this.phone,
  });

  final String email;
  final String password;
  final String? fullName;
  final String? phone;

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        if (fullName != null) 'fullName': fullName,
        if (phone != null) 'phone': phone,
      };
}

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Backend wraps response in {"success":true,"data":{...}}
    final data = json['data'] as Map<String, dynamic>? ?? json;
    print('=== LoginResponse.fromJson ===');
    print('accessToken: ${data['accessToken']}');
    print('refreshToken: ${data['refreshToken']}');
    print('user: ${data['user']}');
    return LoginResponse(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      user: User.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String refreshToken;
  final User user;
}

class AuthRepository {
  AuthRepository(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final SecureStorageService _storage;

  Future<User> login(LoginRequest request) async {
    try {
      final response = await _apiClient.post<LoginResponse>(
        ApiConstants.login,
        data: request.toJson(),
        fromJson: LoginResponse.fromJson,
      );

      await _storage.write(
        key: StorageKeys.accessToken,
        value: response.accessToken,
      );
      await _storage.write(
        key: StorageKeys.refreshToken,
        value: response.refreshToken,
      );
      await _storage.write(
        key: StorageKeys.user,
        value: jsonEncode(response.user.toJson()),
      );

      return response.user;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String message = 'Login failed. Please check your credentials.';
      if (responseData is Map<String, dynamic>) {
        message = responseData['message'] as String? ?? message;
      }
      throw AuthException(message);
    }
  }

  Future<User> register(RegisterRequest request) async {
    try {
      final response = await _apiClient.post<LoginResponse>(
        ApiConstants.register,
        data: request.toJson(),
        fromJson: LoginResponse.fromJson,
      );

      await _storage.write(
        key: StorageKeys.accessToken,
        value: response.accessToken,
      );
      await _storage.write(
        key: StorageKeys.refreshToken,
        value: response.refreshToken,
      );
      await _storage.write(
        key: StorageKeys.user,
        value: jsonEncode(response.user.toJson()),
      );

      return response.user;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String message = 'Registration failed. Please try again.';
      if (responseData is Map<String, dynamic>) {
        message = responseData['message'] as String? ?? message;
      }
      throw AuthException(message);
    }
  }

  Future<void> sendOtp(String phone) async {
    try {
      await _apiClient.post<void>(
        '/auth/send-otp',
        queryParameters: {'phone': phone},
      );
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String message = 'Failed to send OTP. Please try again.';
      if (responseData is Map<String, dynamic>) {
        message = responseData['message'] as String? ?? message;
      }
      throw AuthException(message);
    }
  }

  /// Verify OTP code. Returns a map with 'verified' boolean and 'message' string.
  /// Note: This is a mock implementation - backend doesn't return user/tokens for OTP verification
  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/verify-otp',
        queryParameters: {'phone': phone, 'otp': code},
      );
      return response;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String message = 'Invalid OTP code. Please try again.';
      if (responseData is Map<String, dynamic>) {
        message = responseData['message'] as String? ?? message;
      }
      throw AuthException(message);
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.post<void>(ApiConstants.logout);
    } catch (_) {
      // Ignore logout API errors
    } finally {
      await _storage.deleteAll();
    }
  }

  Future<User?> getCurrentUser() async {
    final userJson = await _storage.read(key: StorageKeys.user);
    if (userJson == null) return null;

    try {
      final userData = jsonDecode(userJson) as Map<String, dynamic>;
      return User.fromJson(userData);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    return token != null && token.isNotEmpty;
  }

  Future<String?> getAccessToken() async {
    return _storage.read(key: StorageKeys.accessToken);
  }

  Future<User> googleAuth(String idToken) async {
    try {
      final response = await _apiClient.post<LoginResponse>(
        '/auth/google',
        data: {'idToken': idToken},
        fromJson: LoginResponse.fromJson,
      );

      await _storage.write(
        key: StorageKeys.accessToken,
        value: response.accessToken,
      );
      await _storage.write(
        key: StorageKeys.refreshToken,
        value: response.refreshToken,
      );
      await _storage.write(
        key: StorageKeys.user,
        value: jsonEncode(response.user.toJson()),
      );

      return response.user;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String message = 'Google authentication failed. Please try again.';
      if (responseData is Map<String, dynamic>) {
        message = responseData['message'] as String? ?? message;
      }
      throw AuthException(message);
    }
  }

  /// Google auth using access token (for Web platform where idToken is not available)
  Future<User> googleAuthWithAccessToken({
    required String accessToken,
    required String email,
    String? fullName,
    String? avatarUrl,
  }) async {
    try {
      final response = await _apiClient.post<LoginResponse>(
        '/auth/google',
        data: {
          'accessToken': accessToken,
          'email': email,
          'fullName': fullName,
          'avatarUrl': avatarUrl,
        },
        fromJson: LoginResponse.fromJson,
      );

      await _storage.write(
        key: StorageKeys.accessToken,
        value: response.accessToken,
      );
      await _storage.write(
        key: StorageKeys.refreshToken,
        value: response.refreshToken,
      );
      await _storage.write(
        key: StorageKeys.user,
        value: jsonEncode(response.user.toJson()),
      );

      return response.user;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      String message = 'Google authentication failed. Please try again.';
      if (responseData is Map<String, dynamic>) {
        message = responseData['message'] as String? ?? message;
      }
      throw AuthException(message);
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
