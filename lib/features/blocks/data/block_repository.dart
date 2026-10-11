import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/failures/app_failure.dart';
import '../../../core/failures/error_mapper.dart';
import '../domain/block.dart';
import '../domain/block_content.dart';

/// كل استعلامات جدول `blocks` من هنا.
///
/// الأعمدة `text_content` و `search_vector` مولّدة في قاعدة البيانات، ويحدّثها
/// المُشغّل `trg_refresh_page_content_text` تلقائيًا بعد أي تغيير على الكتل،
/// ثم يُحدَّث `pages.search_vector` وبذلك تعمل صفحة البحث بلا كود إضافي.
class BlockRepository {
  BlockRepository(this._client);

  final SupabaseClient _client;

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

  /// كتل الصفحة مرتّبة كما ستُعرض تمامًا (sort_order ثم زمن الإنشاء).
  Future<List<NoteBlock>> fetchBlocks(String pageId) async {
    try {
      final dynamic rows = await _client
          .from('blocks')
          .select()
          .eq('page_id', pageId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NoteBlock.fromRow)
          .toList(growable: false);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<NoteBlock> createBlock({
    required String pageId,
    required BlockType type,
    Map<String, dynamic>? content,
    required double sortOrder,
    String? parentBlockId,
  }) async {
    try {
      final NoteBlock draft = NoteBlock(
        id: '',
        pageId: pageId,
        parentBlockId: parentBlockId,
        type: type,
        content: content ?? type.defaultContent,
        sortOrder: sortOrder,
      );

      final dynamic row = await _client
          .from('blocks')
          .insert(draft.toInsertPayload(_requireUserId()))
          .select()
          .single();

      return NoteBlock.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// تحديث محتوى الكتلة (ونوعها وترتيبها عند الحاجة).
  Future<NoteBlock> updateBlock({
    required String blockId,
    Map<String, dynamic>? content,
    BlockType? type,
    double? sortOrder,
    String? parentBlockId,
  }) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        if (content != null) 'content': content,
        if (type != null) 'type': type.dbValue,
        if (sortOrder != null) 'sort_order': sortOrder,
        if (parentBlockId != null) 'parent_block_id': parentBlockId,
      };
      if (payload.isEmpty) {
        throw const AppFailure(
          kind: FailureKind.validation,
          message: 'لا توجد حقول للتحديث / Nothing to update',
        );
      }

      final dynamic row = await _client
          .from('blocks')
          .update(payload)
          .eq('id', blockId)
          .select()
          .single();

      return NoteBlock.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<void> deleteBlock(String blockId) async {
    try {
      await _client.from('blocks').delete().eq('id', blockId);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// تبديل ترتيب كتلتين (سطران فقط، بلا إعادة ترقيم كامل).
  Future<void> swapSortOrders(NoteBlock first, NoteBlock second) async {
    try {
      await _client
          .from('blocks')
          .update(<String, dynamic>{'sort_order': second.sortOrder})
          .eq('id', first.id);
      await _client
          .from('blocks')
          .update(<String, dynamic>{'sort_order': first.sortOrder})
          .eq('id', second.id);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// حذف كل كتل صفحة (يُستخدم عند تفريغ المحتوى).
  Future<void> deleteAllForPage(String pageId) async {
    try {
      await _client.from('blocks').delete().eq('page_id', pageId);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// ترتيب كتلة جديدة = آخر ترتيب + 1000 (يُمرَّر عادةً من محرّر الكتل).
  static double nextSortOrder(List<NoteBlock> blocks) {
    double max = 0;
    for (final NoteBlock block in blocks) {
      if (block.sortOrder > max) {
        max = block.sortOrder;
      }
    }
    return max + 1000;
  }

  /// نوع كتلة من نص مخزَّن (للاستخدام في الاختبارات/الأدوات).
  static BlockType typeOf(NoteBlock block) => BlockType.fromDb(block.type.dbValue);

  /// محتوى كتلة نصية جديدة من نص خام (يُستخدم في القوالب — المرحلة ج).
  static Map<String, dynamic> textContent(String text) =>
      RichTextData.fromPlainText(text).toJson();
}
