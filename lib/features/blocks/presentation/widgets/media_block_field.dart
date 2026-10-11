import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_snack.dart';
import '../../../../l10n/l10n.dart';
import '../../application/blocks_providers.dart';
import '../../domain/attachment.dart';
import '../../domain/block.dart';
import '../../domain/block_content.dart';
import 'auto_saving_text_field.dart';
import 'block_style.dart';

/// كتلة وسائط: صورة أو ملف PDF مرفوع إلى Supabase Storage.
///
/// • الصور: من المعرض أو الكاميرا أو من الملفات، وتُعرض عبر رابط موقّع مؤقت.
/// • PDF: يُختار من الملفات، ويُفتح عبر `url_launcher` في التطبيق الخارجي.
/// • كل اختيار يرفع الملف ثم يُبلّغ الأب بالبيانات الجديدة لحفظ الكتلة.
class MediaBlockField extends ConsumerStatefulWidget {
  const MediaBlockField({
    super.key,
    required this.blockId,
    required this.pageId,
    required this.type,
    required this.data,
    required this.onChanged,
  });

  final String blockId;
  final String pageId;

  /// [BlockType.image] أو [BlockType.pdf].
  final BlockType type;
  final MediaData data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  ConsumerState<MediaBlockField> createState() => _MediaBlockFieldState();
}

class _MediaBlockFieldState extends ConsumerState<MediaBlockField> {
  bool _busy = false;
  String? _signedUrl;

  bool get _isImage => widget.type == BlockType.image;

  @override
  void initState() {
    super.initState();
    _refreshSignedUrlIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MediaBlockField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.storagePath != widget.data.storagePath) {
      _signedUrl = null;
      _refreshSignedUrlIfNeeded();
    }
  }

  Future<void> _refreshSignedUrlIfNeeded() async {
    final String? path = widget.data.storagePath;
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final String url =
          await ref.read(attachmentRepositoryProvider).createSignedUrl(path);
      if (!mounted) {
        return;
      }
      setState(() => _signedUrl = url);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _signedUrl = null);
    }
  }

  Future<void> _upload({
    required Uint8List bytes,
    required String fileName,
    int? width,
    int? height,
  }) async {
    // إن كانت الكتلة تحتوي ملفًا سابقًا فسنحذفه بعد نجاح الرفع الجديد
    // حتى لا تبقى ملفات يتيمة في التخزين.
    final String? previousPath = widget.data.storagePath;
    final String? previousId = widget.data.attachmentId;

    setState(() => _busy = true);
    try {
      final Attachment attachment =
          await ref.read(attachmentRepositoryProvider).upload(
                pageId: widget.pageId,
                bytes: bytes,
                fileName: fileName,
                blockId: widget.blockId,
                kind: _isImage ? AttachmentKind.image : AttachmentKind.pdf,
                width: width,
                height: height,
                caption: widget.data.caption,
              );
      if (!mounted) {
        return;
      }
      final MediaData updated = widget.data.withFile(
        storagePath: attachment.storagePath,
        fileName: attachment.fileName,
        mimeType: attachment.mimeType,
        sizeBytes: attachment.sizeBytes,
        attachmentId: attachment.id,
        width: width,
        height: height,
      );
      widget.onChanged(updated.toJson());
      _signedUrl = null;
      await _refreshSignedUrlIfNeeded();

      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != attachment.storagePath &&
          previousId != null) {
        try {
          await ref.read(attachmentRepositoryProvider).delete(
                attachmentId: previousId,
                storagePath: previousPath,
              );
        } catch (_) {
          // تنظيف غير حرج: الملف الجديد محفوظ بالفعل.
        }
      }
      if (mounted) {
        showAppSnack(context, context.l10n.blockMediaUploaded);
      }
    } catch (error) {
      if (mounted) {
        showAppFailureSnack(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2400,
        maxHeight: 2400,
      );
      if (file == null) {
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      await _upload(bytes: bytes, fileName: file.name);
    } catch (error) {
      if (mounted) {
        showAppFailureSnack(context, error);
      }
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final XTypeGroup group = _isImage
          ? const XTypeGroup(
              label: 'images',
              extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
            )
          : const XTypeGroup(
              label: 'pdf',
              extensions: <String>['pdf'],
              mimeTypes: <String>['application/pdf'],
            );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[group]);
      if (file == null) {
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      await _upload(bytes: bytes, fileName: file.name);
    } catch (error) {
      if (mounted) {
        showAppFailureSnack(context, error);
      }
    }
  }

  Future<void> _openFile() async {
    final String? path = widget.data.storagePath;
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      final String url =
          await ref.read(attachmentRepositoryProvider).createSignedUrl(path);
      final bool opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        showAppSnack(context, context.l10n.blockMediaPreviewUnavailable);
      }
    } catch (error) {
      if (mounted) {
        showAppFailureSnack(context, error);
      }
    }
  }

  Future<void> _removeFile() async {
    final String? path = widget.data.storagePath;
    final String? attachmentId = widget.data.attachmentId;
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text(context.l10n.actionDelete),
            content: Text(context.l10n.blockMediaRemoveConfirmBody),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(context.l10n.actionCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(context.l10n.actionDelete),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    widget.onChanged(widget.data.cleared().toJson());
    _signedUrl = null;

    if (path != null && path.isNotEmpty && attachmentId != null) {
      try {
        await ref
            .read(attachmentRepositoryProvider)
            .delete(attachmentId: attachmentId, storagePath: path);
      } catch (error) {
        if (mounted) {
          showAppFailureSnack(context, error);
        }
      }
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppL10n l10n = context.l10n;
    final Color accent = blockTypeColor(widget.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.data.hasFile ? accent.withValues(alpha: 0.5) : theme.colorScheme.outlineVariant,
            ),
          ),
          child: widget.data.hasFile
              ? _buildPreview(context, accent)
              : _buildPlaceholder(context, accent),
        ),
        const SizedBox(height: 8),
        AutoSavingTextField(
          value: widget.data.caption ?? '',
          hintText: l10n.blockMediaCaptionHint,
          filled: false,
          isDense: true,
          textStyle: theme.textTheme.bodySmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onChanged: (String value) =>
              widget.onChanged(widget.data.withCaption(value).toJson()),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context, Color accent) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Icon(
          _isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
          size: 34,
          color: accent,
        ),
        const SizedBox(height: 6),
        Text(
          _isImage ? l10n.blockMediaEmptyImage : l10n.blockMediaEmptyPdf,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (_busy)
          Column(
            children: <Widget>[
              const LinearProgressIndicator(minHeight: 4),
              const SizedBox(height: 6),
              Text(l10n.blockMediaUploading, style: theme.textTheme.labelSmall),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: <Widget>[
              if (_isImage) ...<Widget>[
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(l10n.blockMediaPickGallery),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(l10n.blockMediaTakePhoto),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ],
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: Text(_isImage ? l10n.blockMediaAddImage : l10n.blockMediaAddPdf),
                onPressed: _pickFromFiles,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context, Color accent) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_busy) ...<Widget>[
          const LinearProgressIndicator(minHeight: 4),
          const SizedBox(height: 8),
        ],
        if (_isImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _signedUrl == null
                ? Container(
                    height: 160,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  )
                : Image.network(
                    _signedUrl!,
                    height: 220,
                    fit: BoxFit.contain,
                    loadingBuilder: (
                      BuildContext context,
                      Widget child,
                      ImageChunkEvent? event,
                    ) {
                      if (event == null) {
                        return child;
                      }
                      final double? progress = event.expectedTotalBytes == null
                          ? null
                          : event.cumulativeBytesLoaded /
                              event.expectedTotalBytes!;
                      return SizedBox(
                        height: 160,
                        child: Center(
                          child: CircularProgressIndicator(value: progress),
                        ),
                      );
                    },
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) =>
                        Container(
                      height: 120,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(Icons.broken_image_outlined, size: 30),
                          const SizedBox(height: 6),
                          Text(
                            l10n.blockMediaLoadFailed,
                            style: theme.textTheme.labelSmall,
                          ),
                          TextButton(
                            onPressed: _refreshSignedUrlIfNeeded,
                            child: Text(l10n.actionRetry),
                          ),
                        ],
                      ),
                    ),
                  ),
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.picture_as_pdf_outlined, color: accent),
            title: Text(
              widget.data.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
            ),
            subtitle: Text(
              '${widget.data.mimeType ?? 'application/pdf'}'
              '${widget.data.sizeBytes == null ? '' : ' • ${_formatSize(widget.data.sizeBytes!)}'}',
              style: theme.textTheme.labelSmall,
            ),
            trailing: IconButton(
              tooltip: l10n.blockMediaOpen,
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: _openFile,
            ),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          alignment: WrapAlignment.end,
          children: <Widget>[
            TextButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text(l10n.blockMediaReplace),
              onPressed: _busy ? null : _pickFromFiles,
            ),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(l10n.blockMediaRemove),
              onPressed: _busy ? null : _removeFile,
            ),
          ],
        ),
      ],
    );
  }
}
