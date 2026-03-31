import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import '../storage/secure_storage.dart';

const String _localeKey = 'app_locale';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier(ref);
});

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier(this._ref) : super(null) {
    _loadLocale();
  }

  final Ref _ref;

  Future<void> _loadLocale() async {
    final storage = _ref.read(secureStorageProvider);
    final savedLocale = await storage.read(key: _localeKey);
    if (savedLocale != null) {
      state = Locale(savedLocale);
    } else {
      final deviceLocale = PlatformDispatcher.instance.locale;
      if (deviceLocale.languageCode == 'vi') {
        state = const Locale('vi');
      } else {
        state = const Locale('en');
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    final storage = _ref.read(secureStorageProvider);
    await storage.write(key: _localeKey, value: locale.languageCode);
    state = locale;
  }

  Future<void> setEnglish() async {
    await setLocale(const Locale('en'));
  }

  Future<void> setVietnamese() async {
    await setLocale(const Locale('vi'));
  }
}
