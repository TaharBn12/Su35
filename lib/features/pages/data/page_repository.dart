import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/failures/app_failure.dart';
import '../../../core/failures/error_mapper.dart';
import '../../../core/utils/app_date.dart';
import '../domain/note_page.dart';

/// كل استعلامات جدول pages.
class PageRepository {
  PageRepository(this._client);

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

  /// كل صفحات الدفتر (مسطّحة) — تُبنى الشجرة في الواجهة.
  Future<List<NotePage>> fetchPages(String notebookId) async {
    try {
      final dynamic rows = await _client
          .from('pages')
          .select()
          .eq('notebook_id', notebookId)
          .order('sort_order', ascending: true)
          .order('updated_at', ascending: false);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NotePage.fromRow)
          .toList(growable: false);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<NotePage> fetchPage(String pageId) async {
    try {
      final dynamic row = await _client
          .from('pages')
          .select()
          .eq('id', pageId)
          .maybeSingle();

      if (row == null) {
        throw const AppFailure(
          kind: FailureKind.notFound,
          message: 'الصفحة غير موجودة / Page not found',
        );
      }
      return NotePage.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<NotePage> createPage({
    required String notebookId,
    required String title,
    String? parentPageId,
    String? icon,
    String? summary,
    String? templateKey,
    String? aircraftType,
    String? tailNumber,
    String? ataChapter,
    String? airportIcao,
    DateTime? flightDate,
    bool isFavorite = false,
    int sortOrder = 100,
  }) async {
    try {
      final NotePage draft = NotePage(
        id: '',
        notebookId: notebookId,
        parentPageId: parentPageId,
        title: title,
        icon: icon,
        summary: summary,
        templateKey: templateKey,
        aircraftType: aircraftType,
        tailNumber: tailNumber,
        ataChapter: ataChapter,
        airportIcao: airportIcao,
        flightDate: flightDate,
        isFavorite: isFavorite,
        sortOrder: sortOrder,
      );

      final dynamic row = await _client
          .from('pages')
          .insert(draft.toInsertPayload(_requireUserId()))
          .select()
          .single();

      return NotePage.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// تحديث الصفحة. القيم الفارغة (null) تمسح الحقل في قاعدة البيانات.
  Future<NotePage> updatePage({
    required String pageId,
    required String title,
    String? icon,
    String? summary,
    String? aircraftType,
    String? tailNumber,
    String? ataChapter,
    String? airportIcao,
    DateTime? flightDate,
    bool? isFavorite,
    bool? isArchived,
  }) async {
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'title': title.trim(),
        'icon': icon,
        'summary': summary,
        'aircraft_type': aircraftType,
        'tail_number': tailNumber,
        'ata_chapter': ataChapter,
        'airport_icao': airportIcao,
        // يُرسل بصيغة yyyy-MM-dd لعمود DATE
        'flight_date': AppDate.toDateOnly(flightDate),
        if (isFavorite != null) 'is_favorite': isFavorite,
        if (isArchived != null) 'is_archived': isArchived,
      };

      final dynamic row = await _client
          .from('pages')
          .update(payload)
          .eq('id', pageId)
          .select()
          .single();

      return NotePage.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  Future<NotePage> setFavorite(String pageId, bool isFavorite) async {
    try {
      final dynamic row = await _client
          .from('pages')
          .update(<String, dynamic>{'is_favorite': isFavorite})
          .eq('id', pageId)
          .select()
          .single();

      return NotePage.fromRow(row as Map<String, dynamic>);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }

  /// حذف صفحة — تُحذف الصفحات الفرعية والكتل معها عبر ON DELETE CASCADE.
  Future<void> deletePage(String pageId) async {
    try {
      await _client.from('pages').delete().eq('id', pageId);
    } catch (error, stackTrace) {
      throw ErrorMapper.map(error, stackTrace);
    }
  }
}
