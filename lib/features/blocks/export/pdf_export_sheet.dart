import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../pages/domain/note_page.dart';
import '../application/blocks_providers.dart';
import '../domain/block.dart';
import 'pdf_export_service.dart';

/// ورقة تصدير الصفحة إلى PDF: تبدأ البناء فورًا (مع مؤشّر تقدّم)، ثم تعرض
/// خيارَي المشاركة والطباعة/المعاينة، وتحذيرًا إن لم تتوفّر خطوط عربية.
Future<void> showPdfExportSheet(
  BuildContext context, {
  required NotePage page,
  required String notebookTitle,
  required List<NoteBlock> blocks,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) => PdfExportSheet(
      page: page,
      notebookTitle: notebookTitle,
      blocks: blocks,
    ),
  );
}

class PdfExportSheet extends ConsumerStatefulWidget {
  const PdfExportSheet({
    super.key,
    required this.page,
    required this.notebookTitle,
    required this.blocks,
  });

  final NotePage page;
  final String notebookTitle;
  final List<NoteBlock> blocks;

  @override
  ConsumerState<PdfExportSheet> createState() => _PdfExportSheetState();
}

class _PdfExportSheetState extends ConsumerState<PdfExportSheet> {
  PdfExportResult? _result;
  Object? _error;
  bool _busy = true;
  String? _actionError;

  /// خدمة واحدة لكل جلسة تصدير (تُنشأ عند أول استخدام لتجنّب الوصول إلى `ref`
  /// أثناء إنشاء الحالة).
  late final PdfExportService _service =
      PdfExportService(ref.read(attachmentRepositoryProvider));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _build());
  }

  Future<void> _build() async {
    setState(() {
      _busy = true;
      _error = null;
      _actionError = null;
    });
    try {
      final PdfExportResult result = await _service.buildPagePdf(
        page: widget.page,
        notebookTitle: widget.notebookTitle,
        blocks: widget.blocks,
        l10n: context.l10n,
        arabic: context.isArabic,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _busy = false;
      });
    }
  }

  Future<void> _share() async {
    final PdfExportResult? result = _result;
    if (result == null) {
      return;
    }
    setState(() => _actionError = null);
    try {
      await _service.sharePdf(
        result: result,
        fileName: PdfExportService.suggestedFileName(widget.page),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
    }
  }

  Future<void> _print() async {
    final PdfExportResult? result = _result;
    if (result == null) {
      return;
    }
    setState(() => _actionError = null);
    try {
      await _service.printPdf(
        result: result,
        fileName: PdfExportService.suggestedFileName(widget.page),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final PdfExportResult? result = _result;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.editorExportSheetTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.page.title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_busy) ...<Widget>[
            const LinearProgressIndicator(minHeight: 5),
            const SizedBox(height: 10),
            Text(
              l10n.editorExportPreparing,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ] else if (_error != null) ...<Widget>[
            Icon(
              Icons.error_outline_rounded,
              color: theme.colorScheme.error,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.editorExportFailedBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.actionRetry),
              onPressed: _build,
            ),
          ] else if (result != null) ...<Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.verified_rounded, color: Color(0xFF2E9E6B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.editorExportReady,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '${(result.bytes.lengthInBytes / 1024).toStringAsFixed(0)} KB',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            if (!result.fontsReady) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF0A02A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFF0A02A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.editorExportNoFonts,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(l10n.editorExportShare),
              onPressed: _share,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined),
              label: Text(l10n.editorExportPrint),
              onPressed: _print,
            ),
          ],
          if (_actionError != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _actionError!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
