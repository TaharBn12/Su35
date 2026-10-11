import 'package:flutter/material.dart';

/// إعدادات الواجهة المحلية: الوضع الليلي + اللغة (عربي/إنجليزي).
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('ar'),
  });

  final ThemeMode themeMode;
  final Locale locale;

  bool get isArabic => locale.languageCode == 'ar';

  AppSettings copyWith({ThemeMode? themeMode, Locale? locale}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        locale: locale ?? this.locale,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.themeMode == themeMode &&
          other.locale.languageCode == locale.languageCode;

  @override
  int get hashCode => Object.hash(themeMode, locale.languageCode);
}
