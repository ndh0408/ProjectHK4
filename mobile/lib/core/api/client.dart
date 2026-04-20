import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'api_interceptor.dart';

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(storage, dio),
    LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ),
  ]);

  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio);
});

class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Dio get dio => _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    if (fromJson != null && response.data != null) {
      return fromJson(response.data!);
    }
    return response.data as T;
  }

  Future<List<T>> getList<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      path,
      queryParameters: queryParameters,
    );
    if (response.data != null) {
      return response.data!
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    if (fromJson != null && response.data != null) {
      return fromJson(response.data!);
    }
    return response.data as T;
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    if (fromJson != null && response.data != null) {
      return fromJson(response.data!);
    }
    return response.data as T;
  }

  Future<void> delete(String path) async {
    await _dio.delete<void>(path);
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
    );
    if (fromJson != null && response.data != null) {
      return fromJson(response.data!);
    }
    return response.data as T;
  }

  Future<Response<T>> getRaw<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<T> postMultipart<T>(
    String path, {
    required FormData data,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );
    if (fromJson != null && response.data != null) {
      return fromJson(response.data!);
    }
    return response.data as T;
  }

  Future<List<int>> downloadBytes(String path) async {
    final response = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  String get baseUrl => _dio.options.baseUrl;
}
