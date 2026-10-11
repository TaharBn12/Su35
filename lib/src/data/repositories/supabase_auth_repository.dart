import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

/// Supabase implementation of [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;

  @override
  Session? readCurrentSession() => _auth.currentSession;

  @override
  bool isEmailConfirmed() => _auth.currentUser?.emailConfirmedAt != null;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: <String, dynamic>{'full_name': fullName.trim()},
    );
    // When "Confirm email" is ON in Supabase Auth settings, `session` is null
    // and the user must click the link in the email before signing in.
    return response.session != null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  @override
  Future<void> signOut() async {
    // `global` also revokes the refresh tokens on the server. If the account
    // is already gone this call can throw - that is fine, we still want the
    // local session cleared, so fall back to a local sign out.
    try {
      await _auth.signOut(scope: SignOutScope.global);
    } on AuthException catch (_) {
      await _auth.signOut(scope: SignOutScope.local);
    }
  }
}


