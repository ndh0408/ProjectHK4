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
    final data = json['data'] as Map<String, dynamic>? ?? json;
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

class VerifyOtpRequest {
  const VerifyOtpRequest({required this.email, required this.otp});
  final String email;
  final String otp;
  Map<String, dynamic> toJson() => {'email': email, 'otp': otp};
}

enum QrLoginChallengeStatus {
  pending,
  approved,
  expired,
  consumed;

  static QrLoginChallengeStatus fromWire(String value) {
    switch (value.toUpperCase()) {
      case 'APPROVED':
        return QrLoginChallengeStatus.approved;
      case 'EXPIRED':
        return QrLoginChallengeStatus.expired;
      case 'CONSUMED':
        return QrLoginChallengeStatus.consumed;
      case 'PENDING':
      default:
        return QrLoginChallengeStatus.pending;
    }
  }
}

class QrLoginChallenge {
  const QrLoginChallenge({
    required this.challengeId,
    required this.qrData,
    required this.pollingToken,
    required this.expiresAt,
    required this.expiresInSeconds,
  });

  factory QrLoginChallenge.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return QrLoginChallenge(
      challengeId: data['challengeId'] as String,
      qrData: data['qrData'] as String,
      pollingToken: data['pollingToken'] as String,
      expiresAt: DateTime.parse(data['expiresAt'] as String),
      expiresInSeconds: (data['expiresInSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  final String challengeId;
  final String qrData;
  final String pollingToken;
  final DateTime expiresAt;
  final int expiresInSeconds;
}

class QrLoginStatus {
  const QrLoginStatus({
    required this.challengeId,
    required this.status,
    required this.expiresAt,
    required this.expiresInSeconds,
    this.approvedByName,
    this.approvedAt,
  });

  factory QrLoginStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    return QrLoginStatus(
      challengeId: data['challengeId'] as String,
      status: QrLoginChallengeStatus.fromWire(
        data['status'] as String? ?? 'PENDING',
      ),
      expiresAt: DateTime.parse(data['expiresAt'] as String),
      expiresInSeconds: (data['expiresInSeconds'] as num?)?.toInt() ?? 0,
      approvedByName: data['approvedByName'] as String?,
      approvedAt: data['approvedAt'] != null
          ? DateTime.parse(data['approvedAt'] as String)
          : null,
    );
  }

  final String challengeId;
  final QrLoginChallengeStatus status;
  final DateTime expiresAt;
  final int expiresInSeconds;
  final String? approvedByName;
  final DateTime? approvedAt;
}

/// Sealed result of a `/auth/register` or `/auth/login` call. The backend
/// now returns EITHER a JWT pair (verified user) OR a pending-verification
/// envelope when the email still needs OTP confirmation.
sealed class AuthResult {
  const AuthResult();
}

class AuthSuccess extends AuthResult {
  const AuthSuccess(this.user);
  final User user;
}

class AuthPendingVerification extends AuthResult {
  const AuthPendingVerification(
      {required this.email, required this.otpExpiresInSeconds});
  final String email;
  final int otpExpiresInSeconds;
}

class AuthRepository {
  AuthRepository(this._apiClient, this._storage);

  final ApiClient _apiClient;
  final SecureStorageService _storage;

  /// Persist tokens + user JSON after a successful auth exchange.
  Future<void> _persistSession(LoginResponse response) async {
    await _storage.write(
        key: StorageKeys.accessToken, value: response.accessToken);
    await _storage.write(
        key: StorageKeys.refreshToken, value: response.refreshToken);
    await _storage.write(
      key: StorageKeys.user,
      value: jsonEncode(response.user.toJson()),
    );
  }

  /// Backend may respond with EITHER a JWT pair (verified) OR a pending
  /// verification envelope. `fromJson` on the Dio wrapper is synchronous,
  /// so we receive the raw map here and await persistence explicitly.
  Future<AuthResult> _exchange(String path, Map<String, dynamic> body) async {
    final raw = await _apiClient.post<Map<String, dynamic>>(
      path,
      data: body,
    );
    final data = (raw['data'] as Map<String, dynamic>?) ?? raw;
    if (data['accessToken'] != null) {
      final response = LoginResponse.fromJson(raw);
      await _persistSession(response);
      return AuthSuccess(response.user);
    }
    return AuthPendingVerification(
      email: data['email'] as String? ?? '',
      otpExpiresInSeconds:
          (data['otpExpiresInSeconds'] as num?)?.toInt() ?? 600,
    );
  }

  Future<AuthResult> login(LoginRequest request) async {
    try {
      return await _exchange(ApiConstants.login, request.toJson());
    } on DioException catch (e) {
      throw AuthException(
          _extractMessage(e, 'Login failed. Please check your credentials.'));
    }
  }

  Future<AuthResult> register(RegisterRequest request) async {
    try {
      return await _exchange(ApiConstants.register, request.toJson());
    } on DioException catch (e) {
      throw AuthException(
          _extractMessage(e, 'Registration failed. Please try again.'));
    }
  }

  Future<User> verifyOtp(VerifyOtpRequest request) async {
    try {
      final result = await _exchange(ApiConstants.verifyOtp, request.toJson());
      if (result is AuthSuccess) {
        return result.user;
      }
      throw const AuthException(
          'Verification did not return a session. Please try again.');
    } on DioException catch (e) {
      throw AuthException(
          _extractMessage(e, 'Invalid or expired verification code.'));
    }
  }

  Future<void> resendOtp(String email) async {
    try {
      await _apiClient.post<void>(
        ApiConstants.resendOtp,
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw AuthException(
          _extractMessage(e, 'Could not resend verification code.'));
    }
  }

  String _extractMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final msg = data['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return fallback;
  }

  Future<void> logout() async {
    try {
      await _apiClient.post<void>(ApiConstants.logout);
    } catch (_) {
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

  Future<QrLoginChallenge> createQrLoginChallenge() async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.qrLoginChallenge,
      );
      return QrLoginChallenge.fromJson(response);
    } on DioException catch (e) {
      throw AuthException(
        _extractMessage(e, 'Could not create a QR login request.'),
      );
    }
  }

  Future<QrLoginStatus> getQrLoginStatus({
    required String challengeId,
    required String pollingToken,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConstants.qrLoginChallenge}/$challengeId',
        queryParameters: {'pollingToken': pollingToken},
      );
      return QrLoginStatus.fromJson(response);
    } on DioException catch (e) {
      throw AuthException(
        _extractMessage(e, 'Could not check the QR login status.'),
      );
    }
  }

  Future<User> exchangeQrLoginChallenge({
    required String challengeId,
    required String pollingToken,
  }) async {
    try {
      final raw = await _apiClient.post<Map<String, dynamic>>(
        '${ApiConstants.qrLoginChallenge}/$challengeId/exchange',
        queryParameters: {'pollingToken': pollingToken},
      );
      final response = LoginResponse.fromJson(raw);
      await _persistSession(response);
      return response.user;
    } on DioException catch (e) {
      throw AuthException(
        _extractMessage(e, 'Could not complete QR login.'),
      );
    }
  }

  Future<void> approveQrLoginChallenge({
    required String challengeId,
    required String approvalCode,
  }) async {
    try {
      await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.qrLoginApprove,
        data: {
          'challengeId': challengeId,
          'approvalCode': approvalCode,
        },
      );
    } on DioException catch (e) {
      throw AuthException(
        _extractMessage(e, 'Could not approve the web login request.'),
      );
    }
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
