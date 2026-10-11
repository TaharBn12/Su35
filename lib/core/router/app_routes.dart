/// مسارات التطبيق في مكان واحد (تُستخدم مع go_router والتنقلات البرمجية).
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/splash';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';

  static const String notebooks = '/notebooks';
  static const String notebookPages = '/notebooks/:notebookId';
  static const String page = '/pages/:pageId';
  static const String settings = '/settings';

  static String notebookPagesPath(String notebookId) => '/notebooks/$notebookId';

  static String pagePath(String pageId) => '/pages/$pageId';

  /// مسارات المصادقة — يُسمح بعرضها بدون جلسة.
  static bool isAuthRoute(String location) =>
      location == signIn ||
      location == signUp ||
      location == forgotPassword;
}
