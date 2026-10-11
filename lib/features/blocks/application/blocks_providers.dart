import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/attachment_repository.dart';
import '../data/block_repository.dart';
import '../domain/attachment.dart';
import '../domain/block.dart';

final Provider<BlockRepository> blockRepositoryProvider =
    Provider<BlockRepository>(
  (Ref ref) => BlockRepository(ref.watch(supabaseClientProvider)),
);

final Provider<AttachmentRepository> attachmentRepositoryProvider =
    Provider<AttachmentRepository>(
  (Ref ref) => AttachmentRepository(ref.watch(supabaseClientProvider)),
);

/// كتل صفحة معيّنة — تُستخدم في المعاينة وفي التصدير، ويُبطلها محرّر الكتل بعد
/// كل حفظ حتى تبقى المعاينة محدّثة.
final pageBlocksProvider = FutureProvider.family<List<NoteBlock>, String>(
  (Ref ref, String pageId) =>
      ref.watch(blockRepositoryProvider).fetchBlocks(pageId),
  retry: (int retryCount, Object error) => null,
);

/// مرفقات الصفحة (لعرض قسم المرفقات في شاشة التفاصيل).
final pageAttachmentsProvider = FutureProvider.family<List<Attachment>, String>(
  (Ref ref, String pageId) =>
      ref.watch(attachmentRepositoryProvider).fetchByPage(pageId),
  retry: (int retryCount, Object error) => null,
);
