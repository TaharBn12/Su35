import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/app_failure.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/l10n.dart';
import '../../../notebooks/application/notebooks_controller.dart';
import '../../../notebooks/domain/notebook.dart';
import '../../../pages/application/pages_providers.dart';
import '../../../pages/domain/note_page.dart';
import '../../application/block_editor_controller.dart';
import '../../application/blocks_providers.dart';
import '../../application/rich_text_registry.dart';
import '../../domain/block.dart';
import '../../export/pdf_export_sheet.dart';
import '../widgets/block_style.dart';
import '../widgets/block_tile.dart';
import '../widgets/block_type_sheet.dart';
import '../widgets/checklist_block_field.dart';
import '../widgets/media_block_field.dart';
import '../widgets/rich_text_block_field.dart';
import '../widgets/table_block_field.dart';
import '../widgets/text_block_fields.dart';

/// محرّر كتل الصفحة — الكتلة الأساسية في التطبيق (نمط Notion مبسّط).
///
/// • يقرأ الكتل من [pageBlocksProvider] مرة واحدة ثم يديرها محليًا عبر
///   [BlockEditorController] (حفظ تلقائي بعد توقّف الكتابة).
/// • كل كتلة نصية لها محرّر Quill مستقل، وشريط الأدوات أسفل الشاشة يتحكّم
///   بالكتلة المُركَّز عليها عبر [RichTextRegistry].
/// • التصدير إلى PDF يُفتح من شريط العنوان عبر [showPdfExportSheet].
class BlockEditorScreen extends ConsumerStatefulWidget {
  const BlockEditorScreen({super.key, required this.pageId});

  final String pageId;

  @override
  ConsumerState<BlockEditorScreen> createState() => _BlockEditorScreenState();
}

class _BlockEditorScreenState extends ConsumerState<BlockEditorScreen> {
  late final BlockEditorController _editor = BlockEditorController(
    repository: ref.read(blockRepositoryProvider),
    pageId: widget.pageId,
  );
  final RichTextRegistry _registry = RichTextRegistry();
  final ScrollController _scrollController = ScrollController();
  AppLifecycleListener? _lifecycle;

  /// آخر معرّف صفحة أُرفقت كتله (لمنع الإرفاق المتكرّر).
  String? _attachedPageId;

  @override
  void initState() {
    super.initState();
    _editor.addListener(_onEditorChanged);
    _registry.addListener(_onRegistryChanged);
    _lifecycle = AppLifecycleListener(
      onHide: () => _editor.flush(),
      onPause: () => _editor.flush(),
    );
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _editor.removeListener(_onEditorChanged);
    _registry.removeListener(_onRegistryChanged);
    _registry.dispose();
    _scrollController.dispose();
    _editor.dispose();
    super.dispose();
  }

  void _onEditorChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onRegistryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// إرفاق كتل الخادم بالمُتحكّم مرة واحدة لكل صفحة (بعد نجاح التحميل).
  void _attachIfNeeded(List<NoteBlock> blocks) {
    if (_attachedPageId == widget.pageId) {
      return;
    }
    _attachedPageId = widget.pageId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _editor.attach(blocks);
    });
  }

  void _invalidateBlocksProvider() {
    ref.invalidate(pageBlocksProvider(widget.pageId));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  إجراءات الكتل
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _addBlock({String? afterBlockId}) async {
    _registry.clearFocus();
    final BlockType? type = await showBlockTypeSheet(
      context,
      title: context.l10n.editorAddBlock,
    );
    if (type == null || !mounted) {
      return;
    }
    final NoteBlock? created =
        await _editor.addBlock(type, afterBlockId: afterBlockId);
    if (created == null) {
      if (mounted) {
        showAppFailureSnack(context, _editor.failure ?? AppFailure.unknown());
      }
      return;
    }
    _invalidateBlocksProvider();
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleAction(NoteBlock block, BlockAction action) async {
    switch (action) {
      case BlockAction.insertAfter:
        await _addBlock(afterBlockId: block.id);
      case BlockAction.moveUp:
        await _editor.moveUp(block.id);
      case BlockAction.moveDown:
        await _editor.moveDown(block.id);
      case BlockAction.changeType:
        await _changeType(block);
      case BlockAction.delete:
        await _deleteBlock(block);
    }
  }

  Future<void> _changeType(NoteBlock block) async {
    final BlockType? type = await showBlockTypeSheet(
      context,
      title: context.l10n.editorChangeType,
      current: block.type,
    );
    if (type == null || type == block.type || !mounted) {
      return;
    }

    final bool confirmed = await _confirm(
      title: context.l10n.editorChangeType,
      body: context.l10n.editorChangeTypeConfirmBody,
      confirmLabel: context.l10n.actionContinue,
    );
    if (!confirmed) {
      return;
    }

    await _editor.changeType(block.id, type);
    if (_editor.failure != null && mounted) {
      showAppFailureSnack(context, _editor.failure!);
    }
    _invalidateBlocksProvider();
  }

  Future<void> _deleteBlock(NoteBlock block) async {
    final bool confirmed = await _confirm(
      title: context.l10n.actionDelete,
      body: context.l10n.editorDeleteBlockConfirmBody,
      confirmLabel: context.l10n.actionDelete,
      destructive: true,
    );
    if (!confirmed) {
      return;
    }
    final bool ok = await _editor.deleteBlock(block.id);
    if (!ok && mounted) {
      showAppFailureSnack(context, _editor.failure ?? AppFailure.unknown());
    }
    _invalidateBlocksProvider();
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  بناء الواجهة
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final AsyncValue<NotePage> pageAsync = ref.watch(pageProvider(widget.pageId));

    return PopScope(
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          // حفظ فوري لأي تعديل لم تلتقطه المهلة التلقائية.
          _editor.flush();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: pageAsync.maybeWhen(
            data: (NotePage page) => Text(
              '${page.displayIcon}  ${page.title}',
              overflow: TextOverflow.ellipsis,
            ),
            orElse: () => Text(l10n.editorTitle),
          ),
          actions: <Widget>[
            IconButton(
              tooltip: l10n.editorExportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () => _openExportSheet(pageAsync),
            ),
            IconButton(
              tooltip: l10n.editorSaveNow,
              icon: const Icon(Icons.cloud_done_outlined),
              onPressed: () => _editor.flush(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addBlock(),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.editorAddBlock),
        ),
        body: Column(
          children: <Widget>[
            _SaveStatusBar(
              status: _editor.status,
              lastSavedAt: _editor.lastSavedAt,
              onRetry: _editor.retry,
            ),
            Expanded(child: _buildBody()),
            if (_registry.hasActiveEditor)
              _buildToolbar(_registry.activeController!),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(QuillController controller) {
    final ThemeData theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: QuillSimpleToolbar(
          controller: controller,
          config: const QuillSimpleToolbarConfig(
            multiRowsDisplay: false,
            showDividers: false,
            showFontFamily: false,
            showFontSize: false,
            showInlineCode: true,
            showColorButton: false,
            showBackgroundColorButton: false,
            showSmallButton: false,
            showSubscript: false,
            showSuperscript: false,
            showSearchButton: false,
            showQuote: true,
            showCodeBlock: true,
            showListCheck: true,
            showLink: true,
            showClearFormat: true,
            showUndo: true,
            showRedo: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final AppL10n l10n = context.l10n;
    final AsyncValue<List<NoteBlock>> blocksAsync =
        ref.watch(pageBlocksProvider(widget.pageId));

    return blocksAsync.when(
      loading: () => const AppLoadingView(),
      error: (Object error, StackTrace stackTrace) => AppErrorView(
        failure: error is AppFailure ? error : AppFailure.unknown(),
        onRetry: () async => _invalidateBlocksProvider(),
      ),
      data: (List<NoteBlock> blocks) {
        _attachIfNeeded(blocks);

        if (_editor.blockCount == 0 && blocks.isEmpty) {
          return AppEmptyView(
            title: l10n.editorEmptyTitle,
            body: l10n.editorEmptyBody,
            actionLabel: l10n.editorEmptyCta,
            onAction: () => _addBlock(),
          );
        }

        final List<NoteBlock> items = _editor.blocks.isEmpty
            ? blocks
            : _editor.blocks;

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 96),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) {
            final NoteBlock block = items[index];
            return BlockTile(
              block: block,
              index: index,
              total: items.length,
              canMoveUp: index > 0,
              canMoveDown: index < items.length - 1,
              focused: _registry.focusedBlockId == block.id,
              onAction: (BlockAction action) => _handleAction(block, action),
              child: _buildBlockContent(block),
            );
          },
        );
      },
    );
  }

  Widget _buildBlockContent(NoteBlock block) {
    switch (block.type) {
      case BlockType.text:
        return RichTextBlockField(
          blockId: block.id,
          data: block.richText,
          registry: _registry,
          onChanged: (Map<String, dynamic> content) =>
              _editor.updateContent(block.id, content),
        );
      case BlockType.heading:
        return HeadingBlockField(
          data: block.heading,
          onChanged: (Map<String, dynamic> content) =>
              _editor.updateContent(block.id, content),
        );
      case BlockType.checklist:
        return ChecklistBlockField(
          data: block.checklist,
          onChanged: (Map<String, dynamic> content) =>
              _editor.updateContent(block.id, content),
        );
      case BlockType.table:
        return TableBlockField(
          data: block.table,
          onChanged: (Map<String, dynamic> content) =>
              _editor.updateContent(block.id, content),
        );
      case BlockType.image:
      case BlockType.pdf:
        return MediaBlockField(
          blockId: block.id,
          pageId: widget.pageId,
          type: block.type,
          data: block.media,
          onChanged: (Map<String, dynamic> content) {
            _editor.updateContent(block.id, content);
            _invalidateBlocksProvider();
          },
        );
      case BlockType.code:
        return CodeBlockField(
          data: block.code,
          onChanged: (Map<String, dynamic> content) =>
              _editor.updateContent(block.id, content),
        );
      case BlockType.quote:
        return QuoteBlockField(
          data: block.quote,
          onChanged: (Map<String, dynamic> content) =>
              _editor.updateContent(block.id, content),
        );
      case BlockType.callout:
        return CalloutBlockField(
          data: block.callout,
          onChanged: (Map<String, dynamic> content) =>
              _editor.updateContent(block.id, content),
        );
      case BlockType.divider:
        return Divider(
          thickness: 1.4,
          color: blockTypeColor(BlockType.divider),
          endIndent: 24,
          indent: 24,
        );
    }
  }

  Future<void> _openExportSheet(AsyncValue<NotePage> pageAsync) async {
    final NotePage? page = pageAsync.value;
    final List<NoteBlock> blocks = _editor.blocks;
    if (page == null) {
      showAppSnack(context, context.l10n.editorExportFailedBody);
      return;
    }
    if (blocks.isEmpty) {
      showAppSnack(context, context.l10n.pdfNoContent);
      return;
    }

    // نحفظ أولًا حتى يحتوي الملف على أحدث النسخ.
    await _editor.flush();
    if (!mounted) {
      return;
    }

    final Notebook? notebook =
        ref.read(notebookByIdProvider(page.notebookId));
    await showPdfExportSheet(
      context,
      page: page,
      notebookTitle: notebook?.title ?? '',
      blocks: blocks,
    );
  }
}

/// شريط حالة الحفظ أعلى المحرّر.
class _SaveStatusBar extends StatelessWidget {
  const _SaveStatusBar({
    required this.status,
    required this.lastSavedAt,
    required this.onRetry,
  });

  final EditorSaveStatus status;
  final DateTime? lastSavedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    final (IconData icon, Color color, String label) = switch (status) {
      EditorSaveStatus.idle => (
          Icons.circle_outlined,
          theme.colorScheme.onSurfaceVariant,
          l10n.editorSaved,
        ),
      EditorSaveStatus.dirty => (
          Icons.edit_outlined,
          const Color(0xFFF0A02A),
          l10n.editorUnsaved,
        ),
      EditorSaveStatus.saving => (
          Icons.cloud_upload_outlined,
          theme.colorScheme.primary,
          l10n.editorSaving,
        ),
      EditorSaveStatus.saved => (
          Icons.cloud_done_outlined,
          const Color(0xFF2E9E6B),
          lastSavedAt == null
              ? l10n.editorSaved
              : l10n.editorSavedAt(AppDate.time(lastSavedAt!)),
        ),
      EditorSaveStatus.failed => (
          Icons.error_outline_rounded,
          theme.colorScheme.error,
          l10n.editorSaveFailed,
        ),
    };

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: InkWell(
        onTap: status == EditorSaveStatus.failed ? onRetry : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: <Widget>[
              if (status == EditorSaveStatus.saving)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.8, color: color),
                )
              else
                Icon(icon, size: 15, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ),
              if (status == EditorSaveStatus.failed)
                Icon(Icons.refresh_rounded, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
