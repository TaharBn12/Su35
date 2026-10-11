import 'package:flutter/material.dart';

import 'block_content.dart';

/// أنواع الكتل المدعومة — تطابق قيد `blocks.type` في قاعدة البيانات.
enum BlockType {
  text,
  heading,
  checklist,
  table,
  image,
  pdf,
  code,
  divider,
  quote,
  callout;

  String get dbValue => name;

  /// القراءة الآمنة من قاعدة البيانات (أي قيمة غير معروفة تصبح «نص»).
  static BlockType fromDb(Object? value) {
    final String raw = value is String ? value : '';
    for (final BlockType type in BlockType.values) {
      if (type.dbValue == raw) {
        return type;
      }
    }
    return BlockType.text;
  }
}

/// خصائص مساعدة لكل نوع كتلة.
extension BlockTypeX on BlockType {
  IconData get icon => switch (this) {
        BlockType.text => Icons.notes_rounded,
        BlockType.heading => Icons.title_rounded,
        BlockType.checklist => Icons.checklist_rounded,
        BlockType.table => Icons.table_chart_outlined,
        BlockType.image => Icons.image_outlined,
        BlockType.pdf => Icons.picture_as_pdf_outlined,
        BlockType.code => Icons.code_rounded,
        BlockType.divider => Icons.horizontal_rule_rounded,
        BlockType.quote => Icons.format_quote_rounded,
        BlockType.callout => Icons.campaign_outlined,
      };

  /// كتل الوسائط تحتاج رفع ملف إلى Storage.
  bool get isMedia => this == BlockType.image || this == BlockType.pdf;

  /// كتلة النص الوحيدة التي تستخدم المحرر الغني (Quill).
  bool get isRichText => this == BlockType.text;

  /// كتل نصية بسيطة (حقل واحد بدون تنسيق).
  bool get isSimpleText =>
      this == BlockType.heading || this == BlockType.quote || this == BlockType.callout;

  /// محتوى افتراضي عند إنشاء كتلة من هذا النوع.
  Map<String, dynamic> get defaultContent => switch (this) {
        BlockType.text => RichTextData.empty.toJson(),
        BlockType.heading => HeadingData.empty.toJson(),
        BlockType.checklist => ChecklistData.starter().toJson(),
        BlockType.table => TableData.starter().toJson(),
        BlockType.image => MediaData.empty.toJson(),
        BlockType.pdf => MediaData.empty.toJson(),
        BlockType.code => CodeData.empty.toJson(),
        BlockType.divider => <String, dynamic>{},
        BlockType.quote => QuoteData.empty.toJson(),
        BlockType.callout => CalloutData.empty.toJson(),
      };
}

/// كتلة محتوى داخل صفحة.
///
/// `content` خريطة JSONB حسب النوع (انظر [block_content.dart]).
/// الترتيب عبر `sortOrder` (نوعه numeric في قاعدة البيانات لدعم الإدراج بين كتلتين).
@immutable
class NoteBlock {
  const NoteBlock({
    required this.id,
    required this.pageId,
    required this.type,
    this.parentBlockId,
    this.content = const <String, dynamic>{},
    this.textContent,
    this.sortOrder = 1000,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String pageId;
  final String? parentBlockId;
  final BlockType type;
  final Map<String, dynamic> content;

  /// نسخة النص المسطّح التي تحسبها قاعدة البيانات (للقراءة فقط).
  final String? textContent;

  final double sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// هل يوجد للكتلة صف حقيقي في قاعدة البيانات؟ (المعرّفات المحلية تبدأ بـ local-)
  bool get hasServerId => id.isNotEmpty && !id.startsWith('local-');

  // ── قراءة المحتوى بأمان حسب النوع ────────────────────────────────────────

  RichTextData get richText => RichTextData.fromContent(content);

  HeadingData get heading => HeadingData.fromContent(content);

  ChecklistData get checklist => ChecklistData.fromContent(content);

  TableData get table => TableData.fromContent(content);

  MediaData get media => MediaData.fromContent(content);

  CodeData get code => CodeData.fromContent(content);

  QuoteData get quote => QuoteData.fromContent(content);

  CalloutData get callout => CalloutData.fromContent(content);

  /// نص مختصر يُعرض في المعاينة وفي قوائم الصفحة.
  String get previewText {
    switch (type) {
      case BlockType.text:
        return richText.preview;
      case BlockType.heading:
        return heading.text.trim();
      case BlockType.checklist:
        return checklist.plainText;
      case BlockType.table:
        return table.plainText;
      case BlockType.image:
        final MediaData data = media;
        return data.caption?.trim().isNotEmpty == true
            ? data.caption!.trim()
            : data.displayName;
      case BlockType.pdf:
        final MediaData data = media;
        return data.displayName.isEmpty ? (data.caption ?? '') : data.displayName;
      case BlockType.code:
        return code.code.trim();
      case BlockType.divider:
        return '';
      case BlockType.quote:
        return quote.text.trim();
      case BlockType.callout:
        final CalloutData data = callout;
        return data.title.trim().isEmpty ? data.text.trim() : data.title.trim();
    }
  }

  /// هل المحتوى فارغ؟ (يُستخدم لإخفاء كتل فارغة في المعاينة)
  bool get isEmpty {
    switch (type) {
      case BlockType.text:
        return richText.isEmpty;
      case BlockType.heading:
        return heading.isEmpty;
      case BlockType.checklist:
        return checklist.isEmpty;
      case BlockType.table:
        return table.isEmpty;
      case BlockType.image:
        return !media.hasFile && (media.caption ?? '').trim().isEmpty;
      case BlockType.pdf:
        return !media.hasFile && (media.caption ?? '').trim().isEmpty;
      case BlockType.code:
        return code.isEmpty;
      case BlockType.divider:
        return false;
      case BlockType.quote:
        return quote.isEmpty;
      case BlockType.callout:
        return callout.isEmpty;
    }
  }

  factory NoteBlock.fromRow(Map<String, dynamic> row) {
    final Object? rawContent = row['content'];
    return NoteBlock(
      id: (row['id'] as String?) ?? '',
      pageId: (row['page_id'] as String?) ?? '',
      parentBlockId: row['parent_block_id'] as String?,
      type: BlockType.fromDb(row['type']),
      content: rawContent is Map
          ? rawContent.cast<String, dynamic>()
          : <String, dynamic>{},
      textContent: row['text_content'] as String?,
      sortOrder: (row['sort_order'] as num?)?.toDouble() ?? 1000,
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
    );
  }

  Map<String, dynamic> toInsertPayload(String userId) => <String, dynamic>{
        'user_id': userId,
        'page_id': pageId,
        'parent_block_id': parentBlockId,
        'type': type.dbValue,
        'sort_order': sortOrder,
        'content': content,
      };

  NoteBlock copyWith({
    String? id,
    String? pageId,
    String? parentBlockId,
    BlockType? type,
    Map<String, dynamic>? content,
    String? textContent,
    double? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      NoteBlock(
        id: id ?? this.id,
        pageId: pageId ?? this.pageId,
        parentBlockId: parentBlockId ?? this.parentBlockId,
        type: type ?? this.type,
        content: content ?? this.content,
        textContent: textContent ?? this.textContent,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static DateTime? _parseDate(Object? value) {
    if (value is DateTime) {
      return value.isUtc ? value.toLocal() : value;
    }
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NoteBlock &&
          other.id == id &&
          other.pageId == pageId &&
          other.type == type &&
          other.sortOrder == sortOrder &&
          _mapEquals(other.content, content);

  @override
  int get hashCode => Object.hash(id, pageId, type, sortOrder, content.length);

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (final String key in a.keys) {
      final Object? first = a[key];
      final Object? second = b[key];
      if (first is List && second is List) {
        if (first.length != second.length) {
          return false;
        }
        continue;
      }
      if (first != second) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() => 'NoteBlock($id, ${type.dbValue}, order: $sortOrder)';
}
