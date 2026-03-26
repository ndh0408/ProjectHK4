import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider for offline cache service
final offlineCacheProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService();
});

/// Service để cache data cho offline mode
class OfflineCacheService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Cache keys
  static const String _userProfileKey = 'cached_user_profile';
  static const String _upcomingEventsKey = 'cached_upcoming_events';
  static const String _myRegistrationsKey = 'cached_my_registrations';
  static const String _categoriesKey = 'cached_categories';
  static const String _citiesKey = 'cached_cities';
  static const String _lastSyncKey = 'last_sync_timestamp';

  // Cache durations
  static const Duration _defaultCacheDuration = Duration(hours: 24);

  /// Cache user profile
  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    await _cacheData(_userProfileKey, profile);
  }

  /// Get cached user profile
  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    return _getCachedData(_userProfileKey);
  }

  /// Cache upcoming events
  Future<void> cacheUpcomingEvents(List<Map<String, dynamic>> events) async {
    await _cacheData(_upcomingEventsKey, {'events': events});
  }

  /// Get cached upcoming events
  Future<List<Map<String, dynamic>>?> getCachedUpcomingEvents() async {
    final data = await _getCachedData(_upcomingEventsKey);
    if (data != null && data['events'] != null) {
      return List<Map<String, dynamic>>.from(data['events']);
    }
    return null;
  }

  /// Cache my registrations
  Future<void> cacheMyRegistrations(List<Map<String, dynamic>> registrations) async {
    await _cacheData(_myRegistrationsKey, {'registrations': registrations});
  }

  /// Get cached registrations
  Future<List<Map<String, dynamic>>?> getCachedMyRegistrations() async {
    final data = await _getCachedData(_myRegistrationsKey);
    if (data != null && data['registrations'] != null) {
      return List<Map<String, dynamic>>.from(data['registrations']);
    }
    return null;
  }

  /// Cache categories
  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    await _cacheData(_categoriesKey, {'categories': categories});
  }

  /// Get cached categories
  Future<List<Map<String, dynamic>>?> getCachedCategories() async {
    final data = await _getCachedData(_categoriesKey);
    if (data != null && data['categories'] != null) {
      return List<Map<String, dynamic>>.from(data['categories']);
    }
    return null;
  }

  /// Cache cities
  Future<void> cacheCities(List<Map<String, dynamic>> cities) async {
    await _cacheData(_citiesKey, {'cities': cities});
  }

  /// Get cached cities
  Future<List<Map<String, dynamic>>?> getCachedCities() async {
    final data = await _getCachedData(_citiesKey);
    if (data != null && data['cities'] != null) {
      return List<Map<String, dynamic>>.from(data['cities']);
    }
    return null;
  }

  /// Get last sync timestamp
  Future<DateTime?> getLastSyncTime() async {
    final timestamp = await _storage.read(key: _lastSyncKey);
    if (timestamp != null) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  /// Update last sync timestamp
  Future<void> updateLastSyncTime() async {
    await _storage.write(key: _lastSyncKey, value: DateTime.now().toIso8601String());
  }

  /// Check if cache is stale
  Future<bool> isCacheStale({Duration? maxAge}) async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    final age = DateTime.now().difference(lastSync);
    return age > (maxAge ?? _defaultCacheDuration);
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    await _storage.delete(key: _userProfileKey);
    await _storage.delete(key: _upcomingEventsKey);
    await _storage.delete(key: _myRegistrationsKey);
    await _storage.delete(key: _categoriesKey);
    await _storage.delete(key: _citiesKey);
    await _storage.delete(key: _lastSyncKey);
  }

  /// Generic cache data method
  Future<void> _cacheData(String key, Map<String, dynamic> data) async {
    final cacheEntry = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _storage.write(key: key, value: jsonEncode(cacheEntry));
  }

  /// Generic get cached data method
  Future<Map<String, dynamic>?> _getCachedData(String key) async {
    final cached = await _storage.read(key: key);
    if (cached != null) {
      try {
        final cacheEntry = jsonDecode(cached) as Map<String, dynamic>;
        return cacheEntry['data'] as Map<String, dynamic>?;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
