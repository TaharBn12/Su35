import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/app_auth_state.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/blocks/presentation/screens/block_editor_screen.dart';
import '../../features/notebooks/presentation/screens/notebooks_screen.dart';
import '../../features/pages/presentation/screens/notebook_pages_screen.dart';
import '../../features/pages/presentation/screens/page_detail_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../widgets/not_found_screen.dart';
import 'app_routes.dart';

/// راوتر التطبيق:
///  • يمنع الوصول لشاشات الداخل بدون جلسة (redirect).
///  • يحوّل المستخدم المسجَّل بعيدًا عن شاشات الدخول.
///  • يعيد التقييم كلما تغيّرت حالة المصادقة عبر [refreshListenable].
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> authSignal = ValueNotifier<int>(0);
  ref.onDispose(authSignal.dispose);

  ref.listen<AppAuthState>(
    authControllerProvider,
    (AppAuthState? previous, AppAuthState next) {
      if (previous?.status != next.status) {
        authSignal.value = authSignal.value + 1;
      }
    },
  );

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authSignal,
    redirect: (BuildContext context, GoRouterState state) {
      final AppAuthState auth = ref.read(authControllerProvider);
      final String location = state.matchedLocation;
      final bool onAuthRoute = AppRoutes.isAuthRoute(location);
      final bool onSplash = location == AppRoutes.splash;

      // 1) لا نعرف بعد إن كانت هناك جلسة صالحة
      if (auth.isInitializing) {
        return onSplash ? null : AppRoutes.splash;
      }

      // 2) لا جلسة → شاشات الدخول فقط
      if (!auth.isAuthenticated) {
        return onAuthRoute ? null : AppRoutes.signIn;
      }

      // 3) جلسة صالحة → لا معنى لشاشات الدخول أو الإقلاع
      if (onAuthRoute || onSplash) {
        return AppRoutes.notebooks;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.splash,
        builder: (BuildContext context, GoRouterState state) =>
            const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (BuildContext context, GoRouterState state) =>
            const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (BuildContext context, GoRouterState state) =>
            const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (BuildContext context, GoRouterState state) =>
            const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.notebooks,
        builder: (BuildContext context, GoRouterState state) =>
            const NotebooksScreen(),
      ),
      GoRoute(
        path: AppRoutes.notebookPages,
        builder: (BuildContext context, GoRouterState state) =>
            NotebookPagesScreen(
          notebookId: state.pathParameters['notebookId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.page,
        builder: (BuildContext context, GoRouterState state) => PageDetailScreen(
          pageId: state.pathParameters['pageId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.pageEditor,
        builder: (BuildContext context, GoRouterState state) =>
            BlockEditorScreen(
          pageId: state.pathParameters['pageId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) =>
        const NotFoundScreen(),
  );
});
