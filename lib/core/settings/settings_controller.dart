import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

/// إعدادات الواجهة (الوضع الليلي + اللغة) مع حفظها محليًا عبر
/// shared_preferences — فلا تفقد عند إغلاق التطبيق.
final NotifierProvider<SettingsController, AppSettings>
    settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  static const String themeKey = 'su35.settings.theme_mode';
  static const String localeKey = 'su35.settings.locale';

  SharedPreferences? _preferences;

  @override
  AppSettings build() {
    unawaited(_restoreFromDisk());
    return AppSettings(locale: _deviceOrDefaultLocale());
  }

  Future<void> _restoreFromDisk() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _preferences = prefs;
      final String? theme = prefs.getString(themeKey);
      final String? locale = prefs.getString(localeKey);

      if (!ref.mounted) {
        return;
      }
      state = AppSettings(
        themeMode: _parseThemeMode(theme) ?? ThemeMode.system,
        locale: _parseLocale(locale) ?? _deviceOrDefaultLocale(),
      );
    } catch (_) {
      // تعذّر قراءة التخزين المحلي — نستمر بالإعدادات الافتراضية بلا إزعاج المستخدم.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    try {
      await _preferences?.setString(themeKey, mode.name);
    } catch (_) {
      // فشل الحفظ المحلي لا يمنع تغيير الوضع في الجلسة الحالية.
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    try {
      await _preferences?.setString(localeKey, locale.languageCode);
    } catch (_) {
      // كما أعلاه.
    }
  }

  /// لغة الجهاز إن كانت عربية أو إنجليزية، وإلا العربية افتراضيًا.
  static Locale _deviceOrDefaultLocale() {
    final String code = PlatformDispatcher.instance.locale.languageCode;
    if (code == 'en') {
      return const Locale('en');
    }
    return const Locale('ar');
  }

  static ThemeMode? _parseThemeMode(String? value) {
    if (value == ThemeMode.light.name) {
      return ThemeMode.light;
    }
    if (value == ThemeMode.dark.name) {
      return ThemeMode.dark;
    }
    if (value == ThemeMode.system.name) {
      return ThemeMode.system;
    }
    return null;
  }

  static Locale? _parseLocale(String? value) {
    if (value == 'ar') {
      return const Locale('ar');
    }
    if (value == 'en') {
      return const Locale('en');
    }
    return null;
  }
}
