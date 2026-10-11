import 'package:flutter/foundation.dart';

/// نوع المرفق — يطابق قيد `attachments.kind` (`image` | `pdf` | `other`).
enum AttachmentKind {
  image,
  pdf,
  other;

  String get dbValue => name;

  static AttachmentKind fromDb(Object? value) {
    final String raw = value is String ? value : '';
    for (final AttachmentKind kind in AttachmentKind.values) {
      if (kind.dbValue == raw) {
        return kind;
      }
    }
    return AttachmentKind.other;
  }

  /// تخمين النوع من امتداد/نوع الملف.
  static AttachmentKind detect({String? fileName, String? mimeType}) {
    final String name = (fileName ?? '').toLowerCase();
    final String mime = (mimeType ?? '').toLowerCase();
    if (mime.startsWith('image/') || _imageExtensions.any(name.endsWith)) {
      return AttachmentKind.image;
    }
    if (mime == 'application/pdf' || name.endsWith('.pdf')) {
      return AttachmentKind.pdf;
    }
    return AttachmentKind.other;
  }

  static const List<String> _imageExtensions = <String>[
    '.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif',
  ];
}

/// صف جدول `attachments` — بيانات ملف مخزَّن في bucket `attachments`.
@immutable
class Attachment {
  const Attachment({
    required this.id,
    required this.pageId,
    required this.kind,
    required this.fileName,
    required this.storagePath,
    this.blockId,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
    this.caption,
    this.createdAt,
  });

  final String id;
  final String pageId;
  final String? blockId;
  final AttachmentKind kind;
  final String fileName;
  final String storagePath;
  final String? mimeType;
  final int? sizeBytes;
  final int? width;
  final int? height;
  final String? caption;
  final DateTime? createdAt;

  bool get isImage => kind == AttachmentKind.image;

  /// حجم مقروء للعرض (مثال: 1.4 MB).
  String get readableSize {
    final int bytes = sizeBytes ?? 0;
    if (bytes <= 0) {
      return '—';
    }
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory Attachment.fromRow(Map<String, dynamic> row) => Attachment(
        id: (row['id'] as String?) ?? '',
        pageId: (row['page_id'] as String?) ?? '',
        blockId: row['block_id'] as String?,
        kind: AttachmentKind.fromDb(row['kind']),
        fileName: (row['file_name'] as String?) ?? 'file',
        storagePath: (row['storage_path'] as String?) ?? '',
        mimeType: row['mime_type'] as String?,
        sizeBytes: (row['size_bytes'] as num?)?.toInt(),
        width: (row['width'] as num?)?.toInt(),
        height: (row['height'] as num?)?.toInt(),
        caption: row['caption'] as String?,
        createdAt: row['created_at'] == null
            ? null
            : DateTime.tryParse(row['created_at'].toString())?.toLocal(),
      );
}
