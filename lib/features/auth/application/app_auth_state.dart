import 'package:flutter/foundation.dart';

import '../../../core/failures/app_failure.dart';
import '../domain/app_user.dart';

/// حالة المصادقة على مستوى التطبيق.
enum AppAuthStatus {
  /// ما زلنا نتحقق من الجلسة المحفوظة والملف الشخصي
  initializing,

  /// لا جلسة — تُعرض شاشات الدخول
  unauthenticated,

  /// جلسة صالحة — تُعرض شاشات التطبيق
  authenticated,
}

@immutable
class AppAuthState {
  const AppAuthState._({
    required this.status,
    this.user,
    this.failure,
  });

  const AppAuthState.initializing()
      : this._(status: AppAuthStatus.initializing);

  const AppAuthState.unauthenticated()
      : this._(status: AppAuthStatus.unauthenticated);

  const AppAuthState.authenticated(AppUser user, {AppFailure? failure})
      : this._(
          status: AppAuthStatus.authenticated,
          user: user,
          failure: failure,
        );

  final AppAuthStatus status;

  /// المستخدم الحالي (null قبل تسجيل الدخول).
  final AppUser? user;

  /// خطأ غير حاسم: المستخدم مُصادَق عليه لكن تعذّر تحميل ملفه الشخصي
  /// (مثل انقطاع الشبكة) — يُعرض في الإعدادات دون منع الاستخدام.
  final AppFailure? failure;

  bool get isAuthenticated => status == AppAuthStatus.authenticated;

  bool get isInitializing => status == AppAuthStatus.initializing;

  @override
  String toString() =>
      'AppAuthState(status: ${status.name}, user: ${user?.id}, failure: $failure)';
}
