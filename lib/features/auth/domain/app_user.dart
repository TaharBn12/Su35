import 'package:flutter/foundation.dart';

import '../../../core/utils/app_date.dart';
import 'user_role.dart';

/// مستخدم التطبيق = مستخدم Supabase Auth + صف الملف الشخصي (profiles).
@immutable
class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.role = UserRole.pilot,
    this.avatarUrl,
    this.licenseNumber,
    this.homeBaseIcao,
    this.memberSince,
  });

  final String id;
  final String? email;
  final String? displayName;
  final UserRole role;
  final String? avatarUrl;
  final String? licenseNumber;
  final String? homeBaseIcao;
  final DateTime? memberSince;

  /// اسم مختصر للعرض داخل الترحيب والقوائم.
  String get displayLabel {
    final String name = (displayName ?? '').trim();
    if (name.isNotEmpty) {
      return name;
    }
    final String mail = (email ?? '').trim();
    if (mail.contains('@')) {
      return mail.split('@').first;
    }
    return mail.isEmpty ? '—' : mail;
  }

  /// حالة أساسية من مستخدم Auth قبل تحميل الملف الشخصي.
  factory AppUser.fromAuthUser({required String id, String? email}) =>
      AppUser(id: id, email: email);

  /// بناء النموذج من صف جدول profiles.
  factory AppUser.fromProfileRow(Map<String, dynamic> row) {
    return AppUser(
      id: (row['user_id'] as String?) ?? (row['id'] as String?) ?? '',
      email: row['email'] as String?,
      displayName: row['display_name'] as String?,
      role: userRoleFromDb(row['role']),
      avatarUrl: row['avatar_url'] as String?,
      licenseNumber: row['license_number'] as String?,
      homeBaseIcao: row['home_base_icao'] as String?,
      memberSince: AppDate.tryParse(row['created_at']),
    );
  }

  /// دمج صف الملف الشخصي مع بيانات المصادقة (الملف الشخصي أولوية في الاسم).
  AppUser mergeProfile(Map<String, dynamic> row) {
    final AppUser profile = AppUser.fromProfileRow(row);
    return copyWith(
      id: profile.id.isEmpty ? id : profile.id,
      email: profile.email ?? email,
      displayName: profile.displayName ?? displayName,
      role: profile.role,
      avatarUrl: profile.avatarUrl ?? avatarUrl,
      licenseNumber: profile.licenseNumber ?? licenseNumber,
      homeBaseIcao: profile.homeBaseIcao ?? homeBaseIcao,
      memberSince: profile.memberSince ?? memberSince,
    );
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    UserRole? role,
    String? avatarUrl,
    String? licenseNumber,
    String? homeBaseIcao,
    DateTime? memberSince,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      homeBaseIcao: homeBaseIcao ?? this.homeBaseIcao,
      memberSince: memberSince ?? this.memberSince,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName &&
          other.role == role &&
          other.avatarUrl == avatarUrl &&
          other.licenseNumber == licenseNumber &&
          other.homeBaseIcao == homeBaseIcao &&
          other.memberSince == memberSince;

  @override
  int get hashCode => Object.hash(
        id,
        email,
        displayName,
        role,
        avatarUrl,
        licenseNumber,
        homeBaseIcao,
        memberSince,
      );
}
