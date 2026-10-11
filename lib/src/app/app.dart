import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/settings/providers/settings_provider.dart';
import '../router/app_router.dart';

/// Root widget: wires theme, localization (with RTL) and the router.
class AvnotesApp extends ConsumerWidget {
  const AvnotesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(goRouterProvider);

    // `main()` preloads the persisted settings, so this is only a safety net
    // (e.g. when the widget is used in a test without preloading).
    if (!settings.loaded) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => context.t.get('app.name'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildLight(),
      darkTheme: AppTheme.buildDark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Keep the text scale sane on large-accessibility settings.
        final scale = MediaQuery.textScalerOf(context).clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.3,
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}

/// The observers installed on the root `ProviderContainer` (see `main.dart`).
const List<ProviderObserver> appProviderObservers = <ProviderObserver>[
  AppProviderObserver(),
];

/// Logs provider transitions in debug builds only.
///
/// Riverpod 3 signature: the provider is carried by [ProviderObserverContext].
class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    assert(() {
      debugPrint(
        '[riverpod] ${context.provider.runtimeType}: '
        '${previousValue.runtimeType} -> ${newValue.runtimeType}',
      );
      return true;
    }());
  }

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    assert(() {
      debugPrint('[riverpod] ${context.provider.runtimeType} failed: $error');
      return true;
    }());
  }
}
