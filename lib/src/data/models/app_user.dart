import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../core/utils/json_utils.dart';

/// Local representation of a row in the `public.profiles` table.
///
/// The row is created automatically by the `handle_new_user` trigger when a
/// user signs up, so the client only ever reads/updates it.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.avatarUrl,
    required this.themeMode,
    required this.locale,
    required this.isEmailVerified,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;

  /// `'system' | 'light' | 'dark'` - synced from `profiles.theme_mode`.
  final String themeMode;

  /// `'en' | 'ar'` - synced from `profiles.locale`.
  final String locale;

  final bool isEmailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: asString(json['id']),
      email: asNullableString(json['email']),
      fullName: asNullableString(json['full_name']),
      avatarUrl: asNullableString(json['avatar_url']),
      themeMode: asString(json['theme_mode'], fallback: 'system'),
      locale: asString(json['locale'], fallback: 'en'),
      isEmailVerified: asBool(json['is_email_verified']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  /// Builds a profile from the Supabase Auth [User] plus a (possibly absent)
  /// `profiles` row. Used when the DB round-trip failed but the session is
  /// valid, so the UI still has something to show.
  factory AppUser.fromAuthUser(User user, {Map<String, dynamic>? profile}) {
    final row = profile ?? const <String, dynamic>{};
    final metadata = asMap(user.userMetadata);
    final now = DateTime.now();
    return AppUser(
      id: user.id,
      email: user.email ?? asNullableString(row['email']),
      fullName: asNullableString(row['full_name']) ??
          asNullableString(metadata['full_name']) ??
          asNullableString(metadata['name']),
      avatarUrl: asNullableString(row['avatar_url']),
      themeMode: asString(row['theme_mode'], fallback: 'system'),
      locale: asString(row['locale'], fallback: 'en'),
      isEmailVerified: user.emailConfirmedAt != null,
      createdAt: asDateTime(row['created_at'], fallback: now),
      updatedAt: asDateTime(row['updated_at'], fallback: now),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'theme_mode': themeMode,
      'locale': locale,
      'is_email_verified': isEmailVerified,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// PATCH payload - only mutable profile columns.
  Map<String, dynamic> toUpdateJson() {
    return <String, dynamic>{
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'theme_mode': themeMode,
      'locale': locale,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  AppUser copyWith({
    String? fullName,
    String? avatarUrl,
    String? themeMode,
    String? locale,
    bool? isEmailVerified,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Best-effort display name: full name -> email local part -> short id.
  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail.split('@').first;
    return id.substring(0, id.length < 8 ? id.length : 8);
  }

  @override
  bool operator ==(Object other) =>
      other is AppUser &&
      other.id == id &&
      other.email == email &&
      other.fullName == fullName &&
      other.avatarUrl == avatarUrl &&
      other.themeMode == themeMode &&
      other.locale == locale &&
      other.isEmailVerified == isEmailVerified;

  @override
  int get hashCode => Object.hash(
        id,
        email,
        fullName,
        avatarUrl,
        themeMode,
        locale,
        isEmailVerified,
      );

  @override
  String toString() => 'AppUser($id, $email)';
}
