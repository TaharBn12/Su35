import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/validators.dart';
import '../models/page.dart';
import 'pages_repository.dart';

/// Supabase implementation of [PagesRepository].
class SupabasePagesRepository implements PagesRepository {
  SupabasePagesRepository(this._client);

  final SupabaseClient _client;

  SupabaseQuery get _pages => _client.from(AppConstants.pagesTable);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppFailure('error.sessionExpired');
    return id;
  }

  @override
  Future<List<NotePage>> fetchPages({required String notebookId}) async {
    try {
      final rows = await _pages
          .select()
          .eq('notebook_id', notebookId)
          .eq('is_archived', false)
          .order('parent_page_id', ascending: true, nullsFirst: true)
          .order('position', ascending: true)
          .order('created_at', ascending: true);
      return NotePage.listFromJson(rows);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<NotePage> fetchPage(String pageId) async {
    try {
      final row = await _pages.select().eq('id', pageId).single();
      return NotePage.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<List<NotePage>> fetchChildPages(String parentPageId) async {
    try {
      final rows = await _pages
          .select()
          .eq('parent_page_id', parentPageId)
          .eq('is_archived', false)
          .order('position', ascending: true)
          .order('created_at', ascending: true);
      return NotePage.listFromJson(rows);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<List<NotePage>> fetchRecentPages({int limit = 10}) async {
    try {
      final rows = await _pages
          .select()
          .eq('is_archived', false)
          .order('updated_at', ascending: false)
          .limit(limit);
      return NotePage.listFromJson(rows);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<NotePage> createPage({
    required String notebookId,
    required String title,
    String? parentPageId,
    String? templateKey,
    String? aircraftType,
    String? registration,
    String? ataChapter,
    String? airportIcao,
    String? departureIcao,
    String? arrivalIcao,
    DateTime? flightDate,
    String? icon,
  }) async {
    try {
      final position = await _nextPosition(
        notebookId: notebookId,
        parentPageId: parentPageId,
      );
      final payload = <String, dynamic>{
        'user_id': _userId,
        'notebook_id': notebookId,
        if (parentPageId != null) 'parent_page_id': parentPageId,
        'title': title.trim().isEmpty ? 'Untitled' : title.trim(),
        'icon': icon ?? AppConstants.defaultPageIcon,
        if (templateKey != null && templateKey.isNotEmpty)
          'template_key': templateKey,
        if (aircraftType != null && aircraftType.isNotEmpty)
          'aircraft_type': aircraftType.trim().toUpperCase(),
        if (registration != null && registration.isNotEmpty)
          'registration': registration.trim().toUpperCase(),
        if (ataChapter != null && ataChapter.isNotEmpty)
          'ata_chapter': Validators.normalizeAta(ataChapter),
        if (airportIcao != null && airportIcao.isNotEmpty)
          'airport_icao': airportIcao.trim().toUpperCase(),
        if (departureIcao != null && departureIcao.isNotEmpty)
          'departure_icao': departureIcao.trim().toUpperCase(),
        if (arrivalIcao != null && arrivalIcao.isNotEmpty)
          'arrival_icao': arrivalIcao.trim().toUpperCase(),
        if (flightDate != null) 'flight_date': flightDate.toIso8601String(),
        'position': position,
      };

      final row = await _pages.insert(payload).select().single();
      final created = NotePage.fromJson(row);

      // A template seeds its blocks through the `seed_template_blocks`
      // database trigger, so nothing else to do here.
      return created;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<NotePage> updatePage(
    String pageId, {
    String? title,
    String? icon,
    String? summary,
    String? aircraftType,
    String? registration,
    String? ataChapter,
    String? airportIcao,
    String? departureIcao,
    String? arrivalIcao,
    DateTime? flightDate,
    bool? isFavorite,
    bool? isArchived,
    int? position,
    Set<String> clearFields = const <String>{},
  }) async {
    try {
      final patch = <String, dynamic>{
        if (title != null) 'title': title.trim(),
        if (icon != null) 'icon': icon,
        if (summary != null) 'summary': summary.trim(),
        if (aircraftType != null)
          'aircraft_type': _nullableUpper(aircraftType),
        if (registration != null) 'registration': _nullableUpper(registration),
        if (ataChapter != null)
          'ata_chapter': Validators.normalizeAta(ataChapter),
        if (airportIcao != null) 'airport_icao': _nullableUpper(airportIcao),
        if (departureIcao != null)
          'departure_icao': _nullableUpper(departureIcao),
        if (arrivalIcao != null) 'arrival_icao': _nullableUpper(arrivalIcao),
        if (flightDate != null) 'flight_date': flightDate.toIso8601String(),
        // Explicit clears win over the "leave untouched" semantics above.
        for (final column in clearFields) column: null,
        if (isFavorite != null) 'is_favorite': isFavorite,
        if (isArchived != null) 'is_archived': isArchived,
        if (position != null) 'position': position,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final row = await _pages.update(patch).eq('id', pageId).select().single();
      return NotePage.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<void> movePage(String pageId, {String? newParentId}) async {
    try {
      await _pages
          .update(<String, dynamic>{
            'parent_page_id': newParentId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', pageId);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<void> deletePage(String pageId) async {
    try {
      // Sub-pages, blocks, page_tags and attachment rows cascade from here.
      await _pages.delete().eq('id', pageId);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<List<PageSearchResult>> searchPages({
    required String query,
    String? aircraftType,
    String? ataChapter,
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <PageSearchResult>[];
    try {
      final rows = await _client.rpc<List<dynamic>>(
        AppConstants.searchPagesFunction,
        params: <String, dynamic>{
          'p_query': trimmed,
          if (aircraftType != null && aircraftType.isNotEmpty)
            'p_aircraft_type': aircraftType.trim().toUpperCase(),
          if (ataChapter != null && ataChapter.isNotEmpty)
            'p_ata_chapter': Validators.normalizeAta(ataChapter),
          'p_limit': limit,
        },
      );
      final results = <PageSearchResult>[];
      for (final raw in asMapList(rows)) {
        final pageJson = asMap(raw['page']);
        if (pageJson.isEmpty) continue;
        results.add(
          PageSearchResult(
            page: NotePage.fromJson(pageJson),
            rank: asInt(raw['rank']).toDouble(),
            snippet: asString(raw['snippet']),
          ),
        );
      }
      return results;
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  /// Empty strings are stored as NULL so the CHECK constraints
  /// (`char_length(col) > 0`) hold and the UI can tell "unset" from "set".
  static String? _nullableUpper(String value) {
    final trimmed = value.trim().toUpperCase();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<int> _nextPosition({
    required String notebookId,
    String? parentPageId,
  }) async {
    try {
      var query = _pages.select('position').eq('notebook_id', notebookId);
      query = parentPageId == null
          ? query.isFilter('parent_page_id', null)
          : query.eq('parent_page_id', parentPageId);
      final rows = await query.order('position', ascending: false).limit(1);
      final list = NotePage.listFromJson(rows);
      if (list.isEmpty) return 0;
      return list.first.position + 1;
    } catch (_) {
      return 0;
    }
  }
}
