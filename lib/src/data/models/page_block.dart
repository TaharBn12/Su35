import '../../core/utils/json_utils.dart';

/// A row of `public.blocks` - the smallest unit of content inside a page.
///
/// Stage A only *reads* text-ish blocks (so template-seeded pages render
/// immediately). Stage B replaces the read-only renderer with the full
/// flutter_quill editor that writes every block type listed in
/// `BlockTypes.all`.
class PageBlock {
  const PageBlock({
    required this.id,
    required this.userId,
    required this.pageId,
    this.parentBlockId,
    required this.type,
    this.content,
    this.props,
    this.isChecked,
    this.language,
    this.position = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String pageId;

  /// Parent block for list items / table cells (nested blocks).
  final String? parentBlockId;

  /// One of `BlockTypes.*` (`paragraph`, `heading1`, `checklist`, ...).
  final String type;

  /// Plain text (or Delta JSON as a string for rich blocks).
  final String? content;

  /// Extra JSON payload: table cells, image metadata, callout kind, ...
  final Map<String, dynamic>? props;

  /// Checklist state.
  final bool? isChecked;

  /// Code block language.
  final String? language;

  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTextual => content != null && content!.trim().isNotEmpty;

  int get wordCount {
    final text = content?.trim() ?? '';
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  factory PageBlock.fromJson(Map<String, dynamic> json) {
    return PageBlock(
      id: asString(json['id']),
      userId: asString(json['user_id']),
      pageId: asString(json['page_id']),
      parentBlockId: asNullableString(json['parent_block_id']),
      type: asString(json['type'], fallback: 'paragraph'),
      content: asNullableString(json['content']),
      props: asNullableMap(json['props']),
      isChecked: json['is_checked'] == null
          ? null
          : asBool(json['is_checked']),
      language: asNullableString(json['language']),
      position: asInt(json['position']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  static List<PageBlock> listFromJson(Object? rows) => asMapList(rows)
      .map(PageBlock.fromJson)
      .toList(growable: false);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'page_id': pageId,
      'parent_block_id': parentBlockId,
      'type': type,
      'content': content,
      'props': props,
      'is_checked': isChecked,
      'language': language,
      'position': position,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'page_id': pageId,
      if (parentBlockId != null) 'parent_block_id': parentBlockId,
      'type': type,
      'content': content,
      if (props != null) 'props': props,
      if (isChecked != null) 'is_checked': isChecked,
      if (language != null) 'language': language,
      'position': position,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is PageBlock &&
      other.id == id &&
      other.type == type &&
      other.content == content &&
      other.isChecked == isChecked &&
      other.position == position;

  @override
  int get hashCode => Object.hash(id, type, content, isChecked, position);

  @override
  String toString() => 'PageBlock($id, $type, ${content?.length ?? 0} chars)';
}
