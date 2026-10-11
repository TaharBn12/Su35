import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/aviation_data.dart';
import '../../../core/failures/app_failure.dart';
import '../../../core/failures/error_mapper.dart';
import '../domain/notebook.dart';

/// كل استعلامات جدول notebooks (+ عرض الإحصاءات) من هنا.
class NotebookRepository {
  NotebookRepository(this._client);

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

  /// يجلب الدفاتر مرتّبة (المثبّتة أولًا، ثم ترتيب المستخدم، ثم الأحدث تعديلًا)
  /// مع عدد الصفحات من العرض `notebook_page_counts`.
  Future<List<Notebook>> fetchNotebooks() async {
    try {
      final dynamic notebooksRaw = await _client
          .from('notebooks')
          .select()
          .order('is_favorite', ascending: false)
          .order('sort_order', ascending: true)
          .order('updated_at', ascending: false);

      final dynamic countsRaw =
          await _client.from('notebook_page_counts').select();

      final List<Map<String, dynamic>> notebooks =
          (notebooksRaw as List<dynamic>).cast<Map<String, dynamic>>();
      final List<Map<String, dynamic>> counts =
          (countsRaw as List<dynamic>).cast<Map<String, dynamic>>();

      final Map<String, int> pagesByNotebook = <String, int>{};
      final Map<String, DateTime?> lastUpdateByNotebook =
          <String, DateTime?>{};
      for (final Map<String, dynamic> row in counts) {
        final String? notebookId = row['notebook_id'] as String?;
        if (notebookId == null) {
          continue;
        }
        pagesByNotebook[notebookId] =
            (row['pages_count'] as num?)?.toInt() ?? 0;
        lastUpdateByNotebook[notebookId] =
            row['last_page_update'] == null
                ? null
                : DateTime.tryParse(row['last_page_update'] as String)
                    ?.toLocal();
      }

      return notebooks
          .map(
            (Map<String, dynamic> row) => Notebook.fromRow(
              row,
              pagesCount: pagesByNotebook[row['id'] as String? ?? ''] ?? 0,
              lastPageUpdate: lastUpdateByNotebook[row['id'] as String? ?? ''],
            ),
          )
          .toList(growable: false);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<Notebook> createNotebook({
    required String title,
    String? description,
    String? icon,
    String? color,
    String? aircraftType,
    bool isFavorite = false,
    int sortOrder = 100,
  }) async {
    try {
      final Notebook draft = Notebook(
        id: '',
        title: title,
        description: description,
        icon: icon ?? AviationData.defaultNotebookIcon,
        color: color ?? AviationData.defaultNotebookColor,
        aircraftType: aircraftType,
        isFavorite: isFavorite,
        sortOrder: sortOrder,
      );

      final dynamic row = await _client
          .from('notebooks')
          .insert(draft.toInsertPayload(_requireUserId()))
          .select()
          .single();

      return Notebook.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<Notebook> updateNotebook({
    required String id,
    String? title,
    String? description,
    String? icon,
    String? color,
    String? aircraftType,
    bool? isFavorite,
    bool? isArchived,
    int? sortOrder,
  }) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        if (title != null) 'title': title.trim(),
        if (description != null)
          'description': description.trim().isEmpty ? null : description.trim(),
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (aircraftType != null)
          'aircraft_type':
              aircraftType.trim().isEmpty ? null : aircraftType.trim(),
        if (isFavorite != null) 'is_favorite': isFavorite,
        if (isArchived != null) 'is_archived': isArchived,
        if (sortOrder != null) 'sort_order': sortOrder,
      };

      final dynamic row = await _client
          .from('notebooks')
          .update(payload)
          .eq('id', id)
          .select()
          .single();

      return Notebook.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// حذف الدفتر (تُحذف معه الصفحات والكتل تلقائيًا عبر ON DELETE CASCADE).
  Future<void> deleteNotebook(String id) async {
    try {
      await _client.from('notebooks').delete().eq('id', id);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }
}
