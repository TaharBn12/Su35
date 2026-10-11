import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/failures/app_failure.dart';
import '../../../core/failures/error_mapper.dart';
import '../domain/app_user.dart';
import '../domain/sign_up_result.dart';
import '../domain/user_role.dart';

/// كل تعاملات المصادقة مع Supabase Auth تمر من هنا.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// هل توجد جلسة محفوظة محليًا؟ (تُستخدم عند الإقلاع لاستعادة الدخول)
  bool get hasActiveSession => _client.auth.currentSession != null;

  /// بثّ تغيّرات المصادقة (دخول/خروج/تحديث رمز/تحديث بيانات المستخدم).
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  AppUser? currentAuthUser() {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    return AppUser.fromAuthUser(id: user.id, email: user.email);
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = response.user;
      if (user == null) {
        throw const AppFailure(
          kind: FailureKind.auth,
          message: 'تسجيل الدخول لم يُعد بيانات المستخدم',
        );
      }
      return AppUser.fromAuthUser(id: user.id, email: user.email);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, dynamic>{
          'display_name': displayName.trim(),
          'role': role.dbValue,
        },
      );
      final User? user = response.user;
      final bool needsConfirmation = response.session == null;
      return SignUpResult(
        user: user == null
            ? null
            : AppUser.fromAuthUser(id: user.id, email: user.email),
        needsEmailConfirmation: needsConfirmation,
      );
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }
}
