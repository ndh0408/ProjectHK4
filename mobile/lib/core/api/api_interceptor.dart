import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  final SecureStorageService _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: StorageKeys.accessToken);
    print(
        '=== AuthInterceptor: token=${token != null ? "${token.substring(0, 20)}..." : "NULL"} for ${options.path}');
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;

    if (statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        final retryResponse = await _retryRequest(err.requestOptions);
        if (retryResponse != null) {
          return handler.resolve(retryResponse);
        }
      }
    }

    if (statusCode == 403) {
      final path = err.requestOptions.path;
      final isUserEndpoint = path.contains('/user/') ||
          path.contains('/organiser/') ||
          path.contains('/admin/');

      if (isUserEndpoint) {
        final refreshed = await _tryRefreshToken();
        if (refreshed) {
          final retryResponse = await _retryRequest(err.requestOptions);
          if (retryResponse != null) {
            return handler.resolve(retryResponse);
          }
        }
      }
    }

    handler.next(err);
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _storage.read(key: StorageKeys.refreshToken);
      if (refreshToken == null) {
        print('=== No refresh token available');
        return false;
      }

      print('=== Trying to refresh token...');
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await dio.post<Map<String, dynamic>>(
        ApiConstants.refreshToken,
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final apiResponse = response.data!;
        final data = apiResponse['data'] as Map<String, dynamic>?;

        if (data != null) {
          final newAccessToken = data['accessToken'] as String?;
          final newRefreshToken = data['refreshToken'] as String?;

          if (newAccessToken != null && newRefreshToken != null) {
            await _storage.write(
              key: StorageKeys.accessToken,
              value: newAccessToken,
            );
            await _storage.write(
              key: StorageKeys.refreshToken,
              value: newRefreshToken,
            );
            print('=== Token refreshed successfully');
            return true;
          }
        }
      }
    } catch (e) {
      print('=== Refresh token failed: $e');
    }
    return false;
  }

  Future<Response<dynamic>?> _retryRequest(RequestOptions options) async {
    try {
      final token = await _storage.read(key: StorageKeys.accessToken);
      options.headers['Authorization'] = 'Bearer $token';

      final dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      return await dio.fetch<dynamic>(options);
    } catch (_) {
      return null;
    }
  }
}
