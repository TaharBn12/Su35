import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../models/notebook.dart';
import 'notebooks_repository.dart';

/// Supabase (PostgREST) implementation of [NotebooksRepository].
///
/// Row Level Security guarantees a user only ever sees their own rows, so the
/// queries below intentionally do *not* filter on `user_id` when reading - the
/// database does it for us. Writes send `user_id` explicitly so the RLS
/// `WITH CHECK` policy is satisfied even if `auth.uid()` is evaluated early.
class SupabaseNotebooksRepository implements NotebooksRepository {
  SupabaseNotebooksRepository(this._client);

  final SupabaseClient _client;

  SupabaseQuery get _table =>
      _client.from(AppConstants.notebooksTable);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw const AppFailure('error.sessionExpired');
    }
    return id;
  }

  @override
  Future<List<Notebook>> fetchNotebooks() async {
    try {
      final rows = await _table
          .select()
          .eq('is_archived', false)
          .order('position', ascending: true)
          .order('created_at', ascending: false);
      return Notebook.listFromJson(rows);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<Notebook> createNotebook({
    required String name,
    String? icon,
    String? color,
    String? description,
  }) async {
    try {
      final position = await _nextPosition();
      final draft = Notebook(
        id: '',
        userId: _userId,
        name: name.trim(),
        icon: icon ?? AppConstants.defaultNotebookIcon,
        color: color ?? AppConstants.defaultNotebookColor,
        description: description,
        position: position,
      );
      final row = await _table.insert(draft.toInsertJson()).select().single();
      return Notebook.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<Notebook> renameNotebook(String notebookId, String name) =>
      updateNotebook(notebookId, name: name);

  @override
  Future<Notebook> updateNotebook(
    String notebookId, {
    String? name,
    String? icon,
    String? color,
    String? description,
    bool? isArchived,
    int? position,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (name != null) 'name': name.trim(),
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
        if (description != null) 'description': description.trim(),
        if (isArchived != null) 'is_archived': isArchived,
        if (position != null) 'position': position,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final row = await _table
          .update(patch)
          .eq('id', notebookId)
          .select()
          .single();
      return Notebook.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<void> deleteNotebook(String notebookId) async {
    try {
      // `pages`, `blocks`, `page_tags` and `attachments` cascade from here.
      await _table.delete().eq('id', notebookId);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  Future<int> _nextPosition() async {
    try {
      final rows = await _table
          .select('position')
          .order('position', ascending: false)
          .limit(1);
      final list = Notebook.listFromJson(rows);
      if (list.isEmpty) return 0;
      return list.first.position + 1;
    } catch (_) {
      // Positioning is cosmetic - never block a create because of it.
      return 0;
    }
  }
}


