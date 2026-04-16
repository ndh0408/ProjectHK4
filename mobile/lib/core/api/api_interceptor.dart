import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage, this._dio);

  final SecureStorageService _storage;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: StorageKeys.accessToken);
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
        return false;
      }

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
            return true;
          }
        }
      }
    } catch (_) {
      // Token refresh failed silently - user will be redirected to login
    }
    return false;
  }

  Future<Response<dynamic>?> _retryRequest(RequestOptions options) async {
    try {
      final token = await _storage.read(key: StorageKeys.accessToken);
      options.headers['Authorization'] = 'Bearer $token';

      return await _dio.fetch<dynamic>(options);
    } catch (_) {
      return null;
    }
  }
}
