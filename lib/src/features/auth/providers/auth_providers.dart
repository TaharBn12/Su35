import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/supabase_auth_repository.dart';
import '../../../data/supabase_providers.dart';

/// Where the user stands with respect to authentication.
sealed class AuthStatus {
  const AuthStatus();
}

/// Still restoring the persisted session (app cold start).
class AuthUnknown extends AuthStatus {
  const AuthUnknown();
}

class AuthSignedOut extends AuthStatus {
  const AuthSignedOut();
}

class AuthSignedIn extends AuthStatus {
  const AuthSignedIn(this.userId);

  final String userId;
}

/// The single auth repository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Raw Supabase auth events.
///
/// `supabase_flutter` already replays the persisted session as the first
/// `initialSession` event, so watching this provider is enough to know whether
/// somebody is signed in - including right after a cold start.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges();
});

/// The current session (synchronously seeded from the persisted one, then kept
/// up to date by the auth stream).
final currentSessionProvider = Provider<Session?>((ref) {
  // Riverpod 3: `AsyncValue.value` is nullable (the old `valueOrNull`).
  final authState = ref.watch(authStateChangesProvider).value;
  if (authState != null) return authState.session;
  return ref.watch(authRepositoryProvider).readCurrentSession();
});

/// Id of the signed-in user, or `null`.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentSessionProvider)?.user.id;
});

/// Derived, UI-friendly auth status used by the router's `redirect`.
final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  // Still loading (or the stream failed): treat as unknown so the splash screen
  // stays up instead of flashing the login screen.
  if (authState.isLoading || !authState.hasValue) {
    final persisted = ref.watch(authRepositoryProvider).readCurrentSession();
    if (persisted != null) return AuthSignedIn(persisted.user.id);
    if (authState.hasError) return const AuthSignedOut();
    return const AuthUnknown();
  }

  final session = authState.requireValue.session;
  if (session == null) return const AuthSignedOut();
  return AuthSignedIn(session.user.id);
});
