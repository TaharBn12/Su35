import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localizations.dart';

/// Immutable UI preferences.
///
/// Persisted locally with `shared_preferences` (instant, works offline) and
/// mirrored to `profiles.theme_mode` / `profiles.locale` in Stage C so the
/// preferences follow the user across devices.
class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = AppLocalizations.english,
    this.loaded = false,
  });

  final ThemeMode themeMode;
  final Locale locale;

  /// `false` until the persisted values have been read (avoids a flash of the
  /// wrong theme / language on cold start).
  final bool loaded;

  bool get isRtl => locale.languageCode == 'ar';

  SettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    bool? loaded,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SettingsState &&
      other.themeMode == themeMode &&
      other.locale == locale &&
      other.loaded == loaded;

  @override
  int get hashCode => Object.hash(themeMode, locale, loaded);

  @override
  String toString() =>
      'SettingsState(theme: $themeMode, locale: $locale, loaded: $loaded)';
}

class SettingsController extends Notifier<SettingsState> {
  static const String _themeKey = 'settings.theme_mode';
  static const String _localeKey = 'settings.locale';

  SharedPreferences? _prefs;

  /// Kept as a field (instead of reading `state`) so mutations never race with
  /// a provider rebuild.
  SettingsState _current = const SettingsState();

  @override
  SettingsState build() {
    // Load once per app process; subsequent rebuilds keep the current value.
    unawaited(_load());
    return _current;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;

      final themeName = prefs.getString(_themeKey);
      final themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == themeName,
        orElse: () => ThemeMode.system,
      );

      final code = prefs.getString(_localeKey);
      final locale = AppLocalizations.supportedLocales.firstWhere(
        (supported) => supported.languageCode == code,
        orElse: () => AppLocalizations.english,
      );

      _current = SettingsState(
        themeMode: themeMode,
        locale: locale,
        loaded: true,
      );
      if (ref.mounted) state = _current;
    } catch (_) {
      // Preferences are a nice-to-have: never block the app on them.
      _current = const SettingsState(loaded: true);
      if (ref.mounted) state = _current;
    }
  }

  /// Called from `main()` before `runApp` so the very first frame already has
  /// the right theme and language.
  Future<void> preload() async {
    await _load();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _current.themeMode) return;
    _current = _current.copyWith(themeMode: mode);
    state = _current;
    await _prefs?.setString(_themeKey, mode.name);
  }

  Future<void> setLocale(Locale locale) async {
    if (locale.languageCode == _current.locale.languageCode) return;
    _current = _current.copyWith(locale: locale);
    state = _current;
    await _prefs?.setString(_localeKey, locale.languageCode);
  }

  Future<void> toggleTheme() async {
    final next = _current.themeMode == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }
}

/// Notifier provider (kept alive for the whole app lifetime).
final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

/// The value only - what most widgets need.
final settingsProvider = Provider<SettingsState>(
  (ref) => ref.watch(settingsControllerProvider),
);

final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(settingsProvider).themeMode,
);

final localeProvider = Provider<Locale>(
  (ref) => ref.watch(settingsProvider).locale,
);
