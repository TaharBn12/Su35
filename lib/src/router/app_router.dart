import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../data/models/notebook.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/auth/screens/auth_screen.dart';
import '../features/notebooks/screens/home_screen.dart';
import '../features/pages/screens/page_viewer_screen.dart';
import '../features/pages/screens/pages_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/widgets/app_logo.dart';
import '../shared/widgets/async_state_view.dart';

/// All route paths in one place.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/splash';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String settings = '/settings';

  /// `/notebooks/:notebookId`
  static String notebook(String notebookId) => '/notebooks/$notebookId';

  /// `/notebooks/:notebookId/pages/:pageId`
  static String pageViewer(String pageId, String notebookId) =>
      '/notebooks/$notebookId/pages/$pageId';

  /// Route names (for `context.goNamed`).
  static const String splashName = 'splash';
  static const String authName = 'auth';
  static const String homeName = 'home';
  static const String notebookName = 'notebook';
  static const String pageViewerName = 'page';
  static const String settingsName = 'settings';
}

/// Turns a stream (the Supabase auth stream) into a `Listenable` that go_router
/// can use to re-evaluate its `redirect`.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
          onError: (Object _) => notifyListeners(),
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// The single router instance, created once and kept alive.
///
/// It is read (not watched) from `main()` through a root `ProviderContainer`,
/// so a provider rebuild can never recreate the navigator.
final goRouterProvider = Provider<GoRouter>((ref) {
  // `read` (not `watch`): the router must be created exactly once, otherwise a
  // new auth event would rebuild the navigator and lose the back stack.
  final refreshStream = GoRouterRefreshStream(
    ref.read(authStateChangesProvider).stream,
  );
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final status = ref.read(authStatusProvider);
      final location = state.matchedLocation;

      final isAuthRoute = location == AppRoutes.auth;
      final isSplash = location == AppRoutes.splash;

      switch (status) {
        case AuthUnknown():
          // Still restoring the session: hold on the splash screen.
          return isSplash ? null : AppRoutes.splash;

        case AuthSignedOut():
          return isAuthRoute ? null : AppRoutes.auth;

        case AuthSignedIn():
          if (isSplash || isAuthRoute) return AppRoutes.home;
          return null;
      }
    },
    errorBuilder: (context, state) => RouteErrorScreen(state: state),
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        name: AppRoutes.authName,
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return AuthScreen(
            initialMode: mode == 'signup' ? AuthMode.signUp : AuthMode.signIn,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (context, state) => const HomeScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: ':notebookId',
            name: AppRoutes.notebookName,
            builder: (context, state) {
              final notebookId = state.pathParameters['notebookId'] ?? '';
              final extra = state.extra;
              return PagesScreen(
                notebookId: notebookId,
                notebook: extra is Notebook ? extra : null,
              );
            },
            routes: <RouteBase>[
              GoRoute(
                path: 'pages/:pageId',
                name: AppRoutes.pageViewerName,
                builder: (context, state) {
                  final notebookId = state.pathParameters['notebookId'] ?? '';
                  final pageId = state.pathParameters['pageId'] ?? '';
                  final extra = state.extra;
                  return PageViewerScreen(
                    pageId: pageId,
                    notebookId: notebookId,
                    initialPage: extra is PageViewerArgs ? extra.page : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});

/// Shown while Supabase restores the persisted session.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = context.t;
    final status = ref.watch(authStatusProvider);

    // If the auth stream failed we still give the user a way forward.
    final authError = ref.watch(authStateChangesProvider).error;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const AppLogo(size: 76),
              const SizedBox(height: 28),
              if (authError == null && status is AuthUnknown)
                Column(
                  children: <Widget>[
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.6),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      t.get('generic.loading'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                )
              else if (authError != null)
                ErrorStateView(
                  message: t.get('error.sessionExpired'),
                  technicalDetails: '$authError',
                  onRetry: () => ref.invalidate(authStateChangesProvider),
                  compact: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown for an unknown location or a route builder that threw.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({required this.state, super.key});

  final GoRouterState state;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final message = state.error?.toString();

    return Scaffold(
      appBar: AppBar(title: Text(t.get('error.routeNotFound'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.explore_off_rounded,
                size: 52,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                message == null
                    ? '${t.get('error.routeNotFound')}\n${state.uri}'
                    : '${t.get('error.generic')}\n$message',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => context.go(AppRoutes.home),
                icon: const Icon(Icons.home_rounded),
                label: Text(t.get('home.title')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
