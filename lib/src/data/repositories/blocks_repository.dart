import '../models/page_block.dart';

/// Contract for page content blocks.
///
/// Stage A uses [fetchBlocks] for the read-only page viewer. Stage B adds the
/// rich-text editor and uses the write methods (kept here already so the
/// interface does not churn later).
abstract interface class BlocksRepository {
  Future<List<PageBlock>> fetchBlocks(String pageId);

  Future<PageBlock> createBlock({
    required String pageId,
    required String type,
    String? content,
    Map<String, dynamic>? props,
    bool? isChecked,
    String? language,
    String? parentBlockId,
    int? position,
  });

  Future<PageBlock> updateBlock(
    String blockId, {
    String? type,
    String? content,
    Map<String, dynamic>? props,
    bool? isChecked,
    String? language,
    int? position,
  });

  Future<void> deleteBlock(String blockId);

  /// Replaces the whole content of a page in one round trip (used by the
  /// editor's auto-save and by the offline sync in Stage D).
  Future<void> replaceBlocks(String pageId, List<PageBlock> blocks);
}
