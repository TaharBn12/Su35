import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the single Supabase client that was initialised in `main.dart`.
///
/// Everything downstream (repositories, notifiers) depends on this provider
/// instead of touching `Supabase.instance` directly, which keeps the data layer
/// testable: in a `ProviderScope` you can simply
/// `overrideWith((ref) => fakeClient)`.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  if (!Supabase.isInitialized) {
    throw StateError(
      'Supabase.initialize() was not awaited before the ProviderScope was '
      'created. Check main().',
    );
  }
  return Supabase.instance.client;
});

/// Convenience provider for `client.auth`.
final supabaseAuthProvider = Provider<GoTrueClient>(
  (ref) => ref.watch(supabaseClientProvider).auth,
);

/// Convenience provider for `client.storage`.
final supabaseStorageProvider = Provider<SupabaseStorageClient>(
  (ref) => ref.watch(supabaseClientProvider).storage,
);
