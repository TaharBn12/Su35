import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth operations used by the UI. Returns `null` instead of throwing when a
/// "session was removed" event arrives, so callers can stay simple.
abstract interface class AuthRepository {
  /// Emits every auth transition (sign in, token refresh, sign out, ...).
  Stream<AuthState> authStateChanges();

  /// Synchronous snapshot of the persisted session (may be `null`).
  Session? readCurrentSession();

  /// `true` when the current session's email has been confirmed.
  bool isEmailConfirmed();

  Future<void> signIn({required String email, required String password});

  /// Returns `true` when the user is signed in immediately (i.e. email
  /// confirmation is disabled in the Supabase project). Returns `false` when a
  /// confirmation email was sent and the user must verify first.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();
}
