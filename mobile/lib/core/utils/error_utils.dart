import 'package:dio/dio.dart';

/// Utility class for extracting user-friendly error messages from exceptions
class ErrorUtils {
  ErrorUtils._();

  /// Extracts a user-friendly error message from various exception types.
  ///
  /// This function attempts to:
  /// 1. Parse error messages from DioException response body
  /// 2. Match common error patterns for localized messages
  /// 3. Provide a generic fallback message
  static String extractMessage(dynamic error, {String? fallback}) {
    if (error is DioException) {
      return _extractFromDioException(error, fallback: fallback);
    }

    // Check for common patterns in error string
    final errorStr = error.toString().toLowerCase();
    return _matchCommonPatterns(errorStr) ??
        fallback ??
        'An error occurred. Please try again.';
  }

  static String _extractFromDioException(DioException error, {String? fallback}) {
    // Try to get the message from the response body
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      // Backend returns error in 'message' field
      if (responseData.containsKey('message')) {
        return responseData['message'] as String;
      }
      // Or 'error' field
      if (responseData.containsKey('error')) {
        return responseData['error'] as String;
      }
    }

    // Check for common patterns
    final errorStr = error.toString().toLowerCase();
    final patternMatch = _matchCommonPatterns(errorStr);
    if (patternMatch != null) {
      return patternMatch;
    }

    // Handle specific status codes
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'Invalid request. Please check your input.';
        case 401:
          return 'Session expired. Please log in again.';
        case 403:
          return 'You do not have permission to perform this action.';
        case 404:
          return 'The requested resource was not found.';
        case 409:
          return 'A conflict occurred. The item may already exist.';
        case 422:
          return 'Invalid data provided. Please check your input.';
        case 429:
          return 'Too many requests. Please wait a moment and try again.';
        case 500:
          return 'Server error. Please try again later.';
        case 502:
        case 503:
        case 504:
          return 'Service temporarily unavailable. Please try again later.';
      }
    }

    // Handle connection errors
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please check your internet connection.';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to server. Please check your internet connection.';
    }

    return fallback ?? 'An error occurred. Please try again.';
  }

  /// Match common error message patterns and return user-friendly messages
  static String? _matchCommonPatterns(String errorStr) {
    if (errorStr.contains('already registered')) {
      return 'You have already registered for this event.';
    }
    if (errorStr.contains('not open for registration')) {
      return 'This event is not open for registration.';
    }
    if (errorStr.contains('full capacity')) {
      return 'This event is at full capacity.';
    }
    if (errorStr.contains('already exists')) {
      return 'This item already exists.';
    }
    if (errorStr.contains('not found')) {
      return 'The requested item was not found.';
    }
    if (errorStr.contains('unauthorized') || errorStr.contains('not authorized')) {
      return 'You are not authorized to perform this action.';
    }
    if (errorStr.contains('invalid credentials') || errorStr.contains('invalid email or password')) {
      return 'Invalid email or password.';
    }
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }
    return null;
  }
}
