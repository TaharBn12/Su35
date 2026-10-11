import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/failures/app_failure.dart';
import '../../../core/failures/error_mapper.dart';
import '../domain/attachment.dart';

/// رفع/قراءة/حذف المرفقات من bucket `attachments` + جدول `attachments`.
///
/// اصطلاح المسار الإلزامي (تتحقّق منه سياسات Storage):
///   `<user_id>/<page_id>/<uuid><extension>`
class AttachmentRepository {
  AttachmentRepository(this._client);

  final SupabaseClient _client;

  static const Uuid _uuid = Uuid();
  static const int _maxBytes = AppInfo.maxAttachmentBytes;

  String _requireUserId() {
    final String? id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppFailure(
        kind: FailureKind.auth,
        message: 'لا توجد جلسة نشطة / No active session',
      );
    }
    return id;
  }

  String bucket() => AppInfo.attachmentsBucket;

  /// رفع ملف جديد (صورة/PDF): تخزين + صف في `attachments`.
  Future<Attachment> upload({
    required String pageId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String? blockId,
    AttachmentKind? kind,
    int? width,
    int? height,
    String? caption,
    void Function(double progress)? onProgress,
  }) async {
    final String userId = _requireUserId();

    if (bytes.lengthInBytes > _maxBytes) {
      throw const AppFailure(
        kind: FailureKind.validation,
        message: 'الملف أكبر من الحد المسموح / File exceeds the size limit',
      );
    }

    final AttachmentKind resolvedKind = kind ??
        AttachmentKind.detect(fileName: fileName, mimeType: mimeType);

    final String extension = _extensionOf(fileName);
    final String storagePath = '$userId/$pageId/${_uuid.v4()}$extension';

    try {
      onProgress?.call(0.1);

      // نتيجة الرفع تُهمَل عن قصد: تختلف بين إصدارات المكتبة (String/UploadResponse)
      // والمصدر الموثوق للمسار هو ما نبنيه بأنفسنا.
      await _client.storage.from(bucket()).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType ?? _mimeFromExtension(extension),
              cacheControl: '3600',
              upsert: false,
            ),
          );

      onProgress?.call(0.7);

      final dynamic row = await _client
          .from('attachments')
          .insert(<String, dynamic>{
            'user_id': userId,
            'page_id': pageId,
            'block_id': blockId,
            'kind': resolvedKind.dbValue,
            'file_name': fileName,
            'storage_path': storagePath,
            'mime_type': mimeType,
            'size_bytes': bytes.lengthInBytes,
            'width': width,
            'height': height,
            'caption': caption,
          })
          .select()
          .single();

      onProgress?.call(1);

      return Attachment.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      // تنظيف: إن فشل إدخال الصف بعد نجاح الرفع نحذف الملف حتى لا يبقى يتيمًا.
      try {
        await _client.storage.from(bucket()).remove(<String>[storagePath]);
      } catch (_) {
        // تجاهل أخطاء التنظيف — الخطأ الأصلي هو الأهم للمستخدم.
      }
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// رابط موقّع مؤقت لعرض صورة أو فتح PDF (الـ bucket خاص).
  Future<String> createSignedUrl(String storagePath, {int expiresIn = 3600}) async {
    try {
      return await _client.storage.from(bucket()).createSignedUrl(
            storagePath,
            expiresIn,
          );
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// تنزيل بايتات الملف (يُستخدم لإدراج الصور داخل PDF المُصدَّر).
  Future<Uint8List> downloadBytes(String storagePath) async {
    try {
      return await _client.storage.from(bucket()).download(storagePath);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// حذف المرفق من التخزين ومن الجدول معًا.
  ///
  /// إن فشل حذف الملف من التخزين (مثلًا حُذف سابقًا) نُكمل حذف الصف حتى لا يبقى
  /// سجل يشير إلى ملف غير موجود.
  Future<void> delete({
    required String attachmentId,
    required String storagePath,
  }) async {
    try {
      await _client.storage.from(bucket()).remove(<String>[storagePath]);
    } catch (_) {
      // نتجاهل: الملف قد يكون محذوفًا بالفعل.
    }

    try {
      await _client.from('attachments').delete().eq('id', attachmentId);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<List<Attachment>> fetchByPage(String pageId) async {
    try {
      final dynamic rows = await _client
          .from('attachments')
          .select()
          .eq('page_id', pageId)
          .order('created_at', ascending: true);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Attachment.fromRow)
          .toList(growable: false);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  static String _extensionOf(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) {
      return '';
    }
    final String extension = fileName.substring(dot).toLowerCase();
    // حماية بسيطة من أسماء امتدادات غريبة
    return RegExp(r'^\.[a-z0-9]{1,6}$').hasMatch(extension) ? extension : '';
  }

  static String _mimeFromExtension(String extension) {
    switch (extension) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
      case '.heif':
        return 'image/heif';
      case '.pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}
