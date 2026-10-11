import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/app_failure.dart';
import '../models/page_block.dart';
import 'blocks_repository.dart';

/// Supabase implementation of [BlocksRepository].
class SupabaseBlocksRepository implements BlocksRepository {
  SupabaseBlocksRepository(this._client);

  final SupabaseClient _client;

  SupabaseQuery get _blocks => _client.from(AppConstants.blocksTable);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AppFailure('error.sessionExpired');
    return id;
  }

  @override
  Future<List<PageBlock>> fetchBlocks(String pageId) async {
    try {
      final rows = await _blocks
          .select()
          .eq('page_id', pageId)
          .order('position', ascending: true)
          .order('created_at', ascending: true);
      return PageBlock.listFromJson(rows);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<PageBlock> createBlock({
    required String pageId,
    required String type,
    String? content,
    Map<String, dynamic>? props,
    bool? isChecked,
    String? language,
    String? parentBlockId,
    int? position,
  }) async {
    try {
      final effectivePosition = position ?? await _nextPosition(pageId);
      final payload = <String, dynamic>{
        'user_id': _userId,
        'page_id': pageId,
        if (parentBlockId != null) 'parent_block_id': parentBlockId,
        'type': type,
        if (content != null) 'content': content,
        if (props != null) 'props': props,
        if (isChecked != null) 'is_checked': isChecked,
        if (language != null) 'language': language,
        'position': effectivePosition,
      };
      final row = await _blocks.insert(payload).select().single();
      return PageBlock.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<PageBlock> updateBlock(
    String blockId, {
    String? type,
    String? content,
    Map<String, dynamic>? props,
    bool? isChecked,
    String? language,
    int? position,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (type != null) 'type': type,
        if (content != null) 'content': content,
        if (props != null) 'props': props,
        if (isChecked != null) 'is_checked': isChecked,
        if (language != null) 'language': language,
        if (position != null) 'position': position,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      final row =
          await _blocks.update(patch).eq('id', blockId).select().single();
      return PageBlock.fromJson(row);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    try {
      await _blocks.delete().eq('id', blockId);
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  @override
  Future<void> replaceBlocks(String pageId, List<PageBlock> blocks) async {
    try {
      await _blocks.delete().eq('page_id', pageId);
      if (blocks.isEmpty) return;
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        rows.add(
          <String, dynamic>{
            'user_id': _userId,
            'page_id': pageId,
            if (block.parentBlockId != null)
              'parent_block_id': block.parentBlockId,
            'type': block.type,
            'content': block.content,
            if (block.props != null) 'props': block.props,
            if (block.isChecked != null) 'is_checked': block.isChecked,
            if (block.language != null) 'language': block.language,
            'position': i,
          },
        );
      }
      await _blocks.insert(rows);
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw toAppFailure(error);
    }
  }

  Future<int> _nextPosition(String pageId) async {
    try {
      final rows = await _blocks
          .select('position')
          .eq('page_id', pageId)
          .order('position', ascending: false)
          .limit(1);
      final list = PageBlock.listFromJson(rows);
      if (list.isEmpty) return 0;
      return list.first.position + 1;
    } catch (_) {
      return 0;
    }
  }
}
