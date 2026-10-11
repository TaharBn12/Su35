import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/failures/app_failure.dart';
import '../../../core/failures/error_mapper.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../data/auth_repository.dart';
import '../data/profile_repository.dart';
import '../domain/app_user.dart';
import '../domain/sign_up_result.dart';
import '../domain/user_role.dart';
import 'app_auth_state.dart';

/// أدوات المصادقة (يُستبدل العميل بسهولة في الاختبارات).
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
  (Ref ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>(
  (Ref ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);

/// حالة المصادقة العامة — تُبنى عند الإقلاع وتستمع لكل أحداث Supabase Auth.
final NotifierProvider<AuthController, AppAuthState> authControllerProvider =
    NotifierProvider<AuthController, AppAuthState>(AuthController.new);

/// المستخدم الحالي كقيمة مباشرة (للقراءة فقط في الواجهات).
final Provider<AppUser?> currentUserProvider = Provider<AppUser?>(
  (Ref ref) => ref.watch(authControllerProvider).user,
);

/// يدير الجلسة: استعادة الدخول، تسجيل الدخول/الخروج، إنشاء حساب، استعادة كلمة المرور.
///
/// ملاحظة معمارية: الحالة متزامنة (`Notifier`) لا `AsyncNotifier` — لأن الراوتر
/// يحتاج قرارًا فوريًا: «مُصادَق أم لا»، بينما حالات التحميل داخل الشاشات محلية.
class AuthController extends Notifier<AppAuthState> {
  @override
  AppAuthState build() {
    final AuthRepository authRepository = ref.watch(authRepositoryProvider);

    final StreamSubscription<AuthState> subscription =
        authRepository.authStateChanges.listen(_onAuthEvent);
    ref.onDispose(() {
      unawaited(subscription.cancel());
    });

    final AppUser? existing = authRepository.currentAuthUser();
    if (existing == null) {
      return const AppAuthState.unauthenticated();
    }

    // توجد جلسة محفوظة: نحمّل الملف الشخصي ثم نؤكد الدخول.
    unawaited(_loadProfile(existing));
    return const AppAuthState.initializing();
  }

  void _onAuthEvent(AuthState event) {
    if (!ref.mounted) {
      return;
    }

    if (event.event == AuthChangeEvent.signedOut || event.session == null) {
      state = const AppAuthState.unauthenticated();
      return;
    }

    final User? user = event.session?.user;
    if (user == null) {
      state = const AppAuthState.unauthenticated();
      return;
    }

    final AppUser base = AppUser.fromAuthUser(id: user.id, email: user.email);

    if (event.event == AuthChangeEvent.signedIn ||
        event.event == AuthChangeEvent.userUpdated ||
        state.isInitializing) {
      unawaited(_loadProfile(base));
    }
  }

  /// تحميل الملف الشخصي مع إبقاء المستخدم داخل التطبيق عند فشل الشبكة.
  Future<void> _loadProfile(AppUser base) async {
    try {
      final AppUser profile =
          await ref.read(profileRepositoryProvider).fetchProfile(base);
      if (!ref.mounted) {
        return;
      }
      state = AppAuthState.authenticated(profile);
    } catch (error, stackTrace) {
      if (!ref.mounted) {
        return;
      }
      final AppFailure failure = ErrorMapper.map(error, stackTrace);
      state = AppAuthState.authenticated(base, failure: failure);
    }
  }

  /// تسجيل الدخول — يرمي [AppFailure] عند الفشل لتتعامل معه الشاشة.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final AuthRepository repository = ref.read(authRepositoryProvider);
    await repository.signIn(email: email, password: password);
    final AppUser? user = repository.currentAuthUser();
    if (user != null) {
      await _loadProfile(user);
    }
  }

  /// إنشاء حساب — يُعيد نتيجة تُبيّن إن كان تأكيد البريد مطلوبًا.
  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    final SignUpResult result =
        await ref.read(authRepositoryProvider).signUp(
              email: email,
              password: password,
              displayName: displayName,
              role: role,
            );

    if (!result.needsEmailConfirmation && result.user != null) {
      await _loadProfile(result.user!);
    }
    return result;
  }

  Future<void> sendPasswordResetEmail(String email) =>
      ref.read(authRepositoryProvider).sendPasswordResetEmail(email);

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (!ref.mounted) {
      return;
    }
    state = const AppAuthState.unauthenticated();
  }

  /// إعادة تحميل الملف الشخصي يدويًا (زر إعادة المحاولة في الإعدادات).
  Future<void> refreshProfile() async {
    final AppUser? current = state.user;
    if (current == null) {
      return;
    }
    await _loadProfile(current);
  }
}
