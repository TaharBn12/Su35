import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/failures/error_mapper.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';

/// قراءة وتحديث جدول profiles (الاسم، الصفة المهنية، القاعدة، اللغة...).
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  /// يجلب الملف الشخصي ويدمجه مع بيانات المصادقة.
  /// إذا لم يكن الصف موجودًا بعد (مثلًا لم يكتمل المُشغّل) تُعاد البيانات الأساسية.
  Future<AppUser> fetchProfile(AppUser base) async {
    try {
      final dynamic response = await _client
          .from('profiles')
          .select()
          .eq('user_id', base.id)
          .maybeSingle();

      if (response == null) {
        return base;
      }
      return base.mergeProfile(response as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<AppUser> updateProfile({
    required AppUser current,
    String? displayName,
    UserRole? role,
    String? licenseNumber,
    String? homeBaseIcao,
  }) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'id': current.id,
        'user_id': current.id,
        if (displayName != null) 'display_name': displayName.trim(),
        if (role != null) 'role': role.dbValue,
        if (licenseNumber != null)
          'license_number': licenseNumber.trim().isEmpty ? null : licenseNumber.trim(),
        if (homeBaseIcao != null)
          'home_base_icao':
              homeBaseIcao.trim().isEmpty ? null : homeBaseIcao.trim().toUpperCase(),
      };

      final dynamic response = await _client
          .from('profiles')
          .upsert(payload, onConflict: 'user_id')
          .select()
          .single();

      return current.mergeProfile(response as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }
}
