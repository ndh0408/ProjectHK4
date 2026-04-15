import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final offlineCacheProvider = Provider<OfflineCacheService>((ref) {
  return OfflineCacheService();
});

class OfflineCacheService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _userProfileKey = 'cached_user_profile';
  static const String _upcomingEventsKey = 'cached_upcoming_events';
  static const String _myRegistrationsKey = 'cached_my_registrations';
  static const String _categoriesKey = 'cached_categories';
  static const String _citiesKey = 'cached_cities';
  static const String _lastSyncKey = 'last_sync_timestamp';

  static const Duration _defaultCacheDuration = Duration(hours: 24);

  Future<void> cacheUserProfile(Map<String, dynamic> profile) async {
    await _cacheData(_userProfileKey, profile);
  }

  Future<Map<String, dynamic>?> getCachedUserProfile() async {
    return _getCachedData(_userProfileKey);
  }

  Future<void> cacheUpcomingEvents(List<Map<String, dynamic>> events) async {
    await _cacheData(_upcomingEventsKey, {'events': events});
  }

  Future<List<Map<String, dynamic>>?> getCachedUpcomingEvents() async {
    final data = await _getCachedData(_upcomingEventsKey);
    if (data != null && data['events'] != null) {
      return List<Map<String, dynamic>>.from(data['events']);
    }
    return null;
  }

  Future<void> cacheMyRegistrations(List<Map<String, dynamic>> registrations) async {
    await _cacheData(_myRegistrationsKey, {'registrations': registrations});
  }

  Future<List<Map<String, dynamic>>?> getCachedMyRegistrations() async {
    final data = await _getCachedData(_myRegistrationsKey);
    if (data != null && data['registrations'] != null) {
      return List<Map<String, dynamic>>.from(data['registrations']);
    }
    return null;
  }

  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    await _cacheData(_categoriesKey, {'categories': categories});
  }

  Future<List<Map<String, dynamic>>?> getCachedCategories() async {
    final data = await _getCachedData(_categoriesKey);
    if (data != null && data['categories'] != null) {
      return List<Map<String, dynamic>>.from(data['categories']);
    }
    return null;
  }

  Future<void> cacheCities(List<Map<String, dynamic>> cities) async {
    await _cacheData(_citiesKey, {'cities': cities});
  }

  Future<List<Map<String, dynamic>>?> getCachedCities() async {
    final data = await _getCachedData(_citiesKey);
    if (data != null && data['cities'] != null) {
      return List<Map<String, dynamic>>.from(data['cities']);
    }
    return null;
  }

  Future<DateTime?> getLastSyncTime() async {
    final timestamp = await _storage.read(key: _lastSyncKey);
    if (timestamp != null) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  Future<void> updateLastSyncTime() async {
    await _storage.write(key: _lastSyncKey, value: DateTime.now().toIso8601String());
  }

  Future<bool> isCacheStale({Duration? maxAge}) async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;

    final age = DateTime.now().difference(lastSync);
    return age > (maxAge ?? _defaultCacheDuration);
  }

  Future<void> clearCache() async {
    await _storage.delete(key: _userProfileKey);
    await _storage.delete(key: _upcomingEventsKey);
    await _storage.delete(key: _myRegistrationsKey);
    await _storage.delete(key: _categoriesKey);
    await _storage.delete(key: _citiesKey);
    await _storage.delete(key: _lastSyncKey);
  }

  Future<void> _cacheData(String key, Map<String, dynamic> data) async {
    final cacheEntry = {
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _storage.write(key: key, value: jsonEncode(cacheEntry));
  }

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
