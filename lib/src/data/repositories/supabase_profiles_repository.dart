import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../models/app_user.dart';

/// Reads and updates the `public.profiles` row of the signed-in user.
abstract interface class ProfilesRepository {
  /// Returns the profile row, or `null` when it does not exist yet
  /// (e.g. the signup trigger has not committed).
  Future<AppUser?> fetchProfile(String userId);

  Future<AppUser> updateProfile(
    String userId, {
    String? fullName,
    String? avatarUrl,
    String? themeMode,
    String? locale,
  });
}

class SupabaseProfilesRepository implements ProfilesRepository {
  SupabaseProfilesRepository(this._client);

  final SupabaseClient _client;

  SupabaseQuery get _profiles => _client.from(AppConstants.profilesTable);

  @override
  Future<AppUser?> fetchProfile(String userId) async {
    try {
      final row =
          await _profiles.select().eq('id', userId).maybeSingle();
      if (row == null) return null;
      return AppUser.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<AppUser> updateProfile(
    String userId, {
    String? fullName,
    String? avatarUrl,
    String? themeMode,
    String? locale,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (fullName != null) 'full_name': fullName.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (themeMode != null) 'theme_mode': themeMode,
        if (locale != null) 'locale': locale,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final row =
          await _profiles.update(patch).eq('id', userId).select().single();
      return AppUser.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }
}
