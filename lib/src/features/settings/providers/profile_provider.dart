import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/supabase_profiles_repository.dart';
import '../../../data/supabase_providers.dart';
import '../../auth/providers/auth_providers.dart';

/// The signed-in user's profile row (`public.profiles`).
///
/// Rebuilds automatically when the session changes (sign in / sign out), and
/// falls back to the data available in `auth.users` when the profile row is not
/// readable yet.
final profileProvider =
    AsyncNotifierProvider.autoDispose<ProfileNotifier, AppUser?>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;

    final client = ref.watch(supabaseClientProvider);
    final repository = SupabaseProfilesRepository(client);

    try {
      final profile = await repository.fetchProfile(userId);
      if (profile != null) return profile;
    } on AppFailure {
      // Fall through to the auth-user fallback below.
    }

    final authUser = client.auth.currentUser;
    if (authUser == null) return null;
    return AppUser.fromAuthUser(authUser);
  }

  /// Updates the profile row and refreshes the local state.
  Future<void> updateProfile({
    String? fullName,
    String? avatarUrl,
    String? themeMode,
    String? locale,
  }) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) throw const AppFailure('error.sessionExpired');

    final repository = SupabaseProfilesRepository(
      ref.read(supabaseClientProvider),
    );
    final updated = await repository.updateProfile(
      userId,
      fullName: fullName,
      avatarUrl: avatarUrl,
      themeMode: themeMode,
      locale: locale,
    );
    state = AsyncData<AppUser?>(updated);
  }

  /// Re-reads the profile from the server (pull-to-refresh).
  Future<void> refresh() async {
    state = const AsyncLoading<AppUser?>();
    state = await AsyncValue<AppUser?>.guard(build);
  }
}
