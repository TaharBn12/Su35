import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// ══════════════════════════════════════════════════════════════════════════
///  محتوى الكتل (Block Content)
///  كل نوع كتلة يخزّن محتواه في عمود `blocks.content` بصيغة JSONB.
///  هذه الملفات تُعرّف الشكل الدقيق لكل نوع + قراءة/كتابة آمنة،
///  وتطابق ما تتوقّعه دوال قاعدة البيانات (`block_plain_text`) تمامًا:
///    text      → {"delta": [...], "text": "..."}          (نص غني + نص مسطّح)
///    heading   → {"text": "...", "level": 1|2|3}
///    checklist → {"items": [{"id","text","checked"}]}
///    table     → {"columns": [...], "rows": [[...]]}
///    image     → {"storage_path","file_name","mime_type","caption","alt",...}
///    pdf       → {"storage_path","file_name","caption",...}
///    code      → {"language": "...", "code": "..."}
///    quote     → {"text": "..."}
///    callout   → {"title": "...", "text": "...", "tone": "info|warning|danger"}
///    divider   → {}                                        (لا محتوى)
/// ══════════════════════════════════════════════════════════════════════════

/// إنشاء معرّفات فريدة لعناصر المحتوى (بنود القوائم، إلخ).
const Uuid _uuid = Uuid();

String newContentId() => _uuid.v4();

String _string(Object? value) => value is String ? value : (value?.toString() ?? '');

String? _nullableString(Object? value) {
  final String text = _string(value).trim();
  return text.isEmpty ? null : text;
}

int? _nullableInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

List<dynamic> _list(Object? value) => value is List ? value : const <dynamic>[];

List<List<String>> _stringRows(Object? value) {
  return _list(value)
      .map((dynamic row) => _list(row).map(_string).toList(growable: false))
      .toList(growable: false);
}

// ─────────────────────────────────────────────────────────────────────────────
//  1) نص غني (Delta) — كتلة «نص»
// ─────────────────────────────────────────────────────────────────────────────

/// نص غني بصيغة Quill Delta + نسخة مسطّحة للبحث والمعاينة.
@immutable
class RichTextData {
  const RichTextData({required this.delta, required this.plainText});

  /// عمليات Delta: `[{"insert": "..."}, {"insert": "x", "attributes": {...}}]`
  final List<dynamic> delta;

  /// النص المسطّح (يُخزَّن أيضًا في `content.text` ليستخدمه بحث قاعدة البيانات).
  final String plainText;

  static const Map<String, dynamic> _newlineOp = <String, dynamic>{
    'insert': '\n',
  };

  /// محتوى فارغ جاهز للمحرر (سطر واحد فارغ كما يتطلّبه Quill).
  static const RichTextData empty = RichTextData(
    delta: <dynamic>[_newlineOp],
    plainText: '',
  );

  bool get isEmpty => plainText.trim().isEmpty;

  String get preview => plainText.trim();

  /// قراءة المحتوى من JSONB — يتعامل مع الحالات القديمة/الناقصة بأمان.
  factory RichTextData.fromContent(Map<String, dynamic> content) {
    final List<dynamic> delta = _list(content['delta']);
    final String plainText = _string(content['text']);

    if (delta.isEmpty) {
      if (plainText.isEmpty) {
        return RichTextData.empty;
      }
      return RichTextData.fromPlainText(plainText);
    }
    return RichTextData(delta: delta, plainText: plainText);
  }

  /// تحويل نص عادي إلى Delta صالح (يُستخدم عند الهجرة أو الإنشاء المباشر).
  factory RichTextData.fromPlainText(String text) {
    final List<dynamic> ops = <dynamic>[];
    final List<String> lines = text.split('\n');
    for (final String line in lines) {
      ops.add(<String, dynamic>{'insert': line});
      ops.add(_newlineOp);
    }
    if (ops.isEmpty) {
      ops.add(_newlineOp);
    }
    return RichTextData(delta: ops, plainText: text);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'delta': delta,
        'text': plainText,
      };

  RichTextData copyWith({List<dynamic>? delta, String? plainText}) =>
      RichTextData(
        delta: delta ?? this.delta,
        plainText: plainText ?? this.plainText,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  2) العنوان — كتلة «heading»
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class HeadingData {
  const HeadingData({required this.text, this.level = 1});

  final String text;

  /// 1 = رئيسي، 2 = فرعي، 3 = أصغر.
  final int level;

  static const int minLevel = 1;
  static const int maxLevel = 3;

  static const HeadingData empty = HeadingData(text: '');

  bool get isEmpty => text.trim().isEmpty;

  factory HeadingData.fromContent(Map<String, dynamic> content) {
    final int level = (_nullableInt(content['level']) ?? 1).clamp(minLevel, maxLevel);
    return HeadingData(text: _string(content['text']), level: level);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        'level': level,
      };

  HeadingData copyWith({String? text, int? level}) => HeadingData(
        text: text ?? this.text,
        level: (level ?? this.level).clamp(minLevel, maxLevel),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  3) قائمة التحقق — كتلة «checklist»
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class ChecklistItem {
  const ChecklistItem({required this.id, required this.text, this.checked = false});

  final String id;
  final String text;
  final bool checked;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
        id: _string(json['id']).isEmpty ? newContentId() : _string(json['id']),
        text: _string(json['text']),
        checked: json['checked'] == true,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'checked': checked,
      };

  ChecklistItem copyWith({String? id, String? text, bool? checked}) => ChecklistItem(
        id: id ?? this.id,
        text: text ?? this.text,
        checked: checked ?? this.checked,
      );
}

@immutable
class ChecklistData {
  const ChecklistData({required this.items});

  final List<ChecklistItem> items;

  static const ChecklistData empty = ChecklistData(items: <ChecklistItem>[]);

  bool get isEmpty =>
      items.isEmpty || items.every((ChecklistItem item) => item.text.trim().isEmpty);

  int get total => items.length;

  int get doneCount =>
      items.where((ChecklistItem item) => item.checked).length;

  double get progress => items.isEmpty ? 0 : doneCount / items.length;

  /// نص مسطّح للبحث (يطابق ما تجمعه دالة `block_plain_text`).
  String get plainText =>
      items.map((ChecklistItem item) => item.text).join(' ').trim();

  factory ChecklistData.fromContent(Map<String, dynamic> content) {
    final List<ChecklistItem> items = _list(content['items'])
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> raw) =>
            ChecklistItem.fromJson(raw.cast<String, dynamic>()))
        .toList(growable: false);
    return ChecklistData(items: items);
  }

  /// قائمة جديدة ببند مبدئي واحد (تُستخدم عند إنشاء الكتلة).
  factory ChecklistData.starter() => ChecklistData(
        items: <ChecklistItem>[ChecklistItem(id: newContentId(), text: '')],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items.map((ChecklistItem item) => item.toJson()).toList(),
      };

  ChecklistData addItem({String text = '', String? afterId}) {
    final ChecklistItem item = ChecklistItem(id: newContentId(), text: text);
    if (afterId == null) {
      return ChecklistData(items: <ChecklistItem>[...items, item]);
    }
    final List<ChecklistItem> next = <ChecklistItem>[...items];
    final int index = next.indexWhere((ChecklistItem existing) => existing.id == afterId);
    next.insert(index < 0 ? next.length : index + 1, item);
    return ChecklistData(items: next);
  }

  ChecklistData updateItem(String id, {String? text, bool? checked}) => ChecklistData(
        items: items
            .map((ChecklistItem item) => item.id == id
                ? item.copyWith(text: text, checked: checked)
                : item)
            .toList(growable: false),
      );

  ChecklistData removeItem(String id) => ChecklistData(
        items: items
            .where((ChecklistItem item) => item.id != id)
            .toList(growable: false),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  4) الجدول — كتلة «table»
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class TableData {
  const TableData({this.columns = const <String>[], this.rows = const <List<String>>[]});

  /// رؤوس الأعمدة.
  final List<String> columns;

  /// صفوف البيانات (كل صف بطول `columns.length` بعد التطبيع).
  final List<List<String>> rows;

  static const TableData empty = TableData();

  bool get isEmpty =>
      columns.every((String column) => column.trim().isEmpty) &&
      rows.every((List<String> row) =>
          row.every((String cell) => cell.trim().isEmpty));

  String get plainText => <String>[
        ...columns,
        for (final List<String> row in rows) ...row,
      ].join(' ').trim();

  factory TableData.fromContent(Map<String, dynamic> content) {
    final List<List<String>> rows = _stringRows(content['rows']);

    List<String> columns = _list(content['columns']).map(_string).toList(growable: false);
    if (columns.isEmpty && rows.isNotEmpty) {
      columns = List<String>.filled(rows.first.length, '');
    }

    int width = columns.length;
    for (final List<String> row in rows) {
      if (row.length > width) {
        width = row.length;
      }
    }
    // توسيع الأعمدة إن كان صفّ أطول منها (بيانات قديمة)
    final List<String> normalizedColumns = <String>[
      ...columns,
      ...List<String>.filled(width - columns.length, ''),
    ];

    return TableData(
      columns: normalizedColumns,
      rows: rows
          .map((List<String> row) => <String>[
                ...row,
                ...List<String>.filled(width - row.length, ''),
              ])
          .toList(growable: false),
    );
  }

  /// جدول مبدئي: عمودان + صف فارغ واحد.
  factory TableData.starter({int columns = 2, int rows = 1}) => TableData(
        columns: List<String>.filled(columns, ''),
        rows: List<List<String>>.generate(
          rows,
          (int _) => List<String>.filled(columns, ''),
        ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'columns': columns,
        'rows': rows,
      };

  TableData setColumn(int index, String value) {
    final List<String> next = <String>[...columns];
    if (index < 0 || index >= next.length) {
      return this;
    }
    next[index] = value;
    return TableData(columns: next, rows: rows);
  }

  TableData setCell(int rowIndex, int columnIndex, String value) {
    if (rowIndex < 0 || rowIndex >= rows.length) {
      return this;
    }
    final List<List<String>> next = rows
        .map((List<String> row) => <String>[...row])
        .toList(growable: false);
    if (columnIndex < 0 || columnIndex >= next[rowIndex].length) {
      return this;
    }
    next[rowIndex][columnIndex] = value;
    return TableData(columns: columns, rows: next);
  }

  TableData addRow({int? at}) {
    final List<List<String>> next = rows
        .map((List<String> row) => <String>[...row])
        .toList(growable: true);
    final List<String> emptyRow = List<String>.filled(columns.length, '');
    next.insert(at == null || at > next.length ? next.length : at, emptyRow);
    return TableData(columns: columns, rows: next);
  }

  TableData addColumn({int? at}) {
    final int index = at == null || at > columns.length ? columns.length : at;
    final List<String> nextColumns = <String>[...columns]..insert(index, '');
    final List<List<String>> nextRows = rows
        .map((List<String> row) => <String>[...row]..insert(index, ''))
        .toList(growable: false);
    return TableData(columns: nextColumns, rows: nextRows);
  }

  TableData removeRow(int index) {
    if (index < 0 || index >= rows.length) {
      return this;
    }
    return TableData(
      columns: columns,
      rows: rows
          .asMap()
          .entries
          .where((MapEntry<int, List<String>> entry) => entry.key != index)
          .map((MapEntry<int, List<String>> entry) => entry.value)
          .toList(growable: false),
    );
  }

  /// حذف عمود — يبقى عمود واحد على الأقل.
  TableData removeColumn(int index) {
    if (columns.length <= 1 || index < 0 || index >= columns.length) {
      return this;
    }
    return TableData(
      columns: columns
          .asMap()
          .entries
          .where((MapEntry<int, String> entry) => entry.key != index)
          .map((MapEntry<int, String> entry) => entry.value)
          .toList(growable: false),
      rows: rows
          .map((List<String> row) => row
              .asMap()
              .entries
              .where((MapEntry<int, String> entry) => entry.key != index)
              .map((MapEntry<int, String> entry) => entry.value)
              .toList(growable: false))
          .toList(growable: false),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  5) الوسائط (صورة / PDF) — كتلتا «image» و «pdf»
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class MediaData {
  const MediaData({
    this.storagePath,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.caption,
    this.attachmentId,
    this.width,
    this.height,
  });

  /// مسار الملف داخل bucket `attachments`: `<user_id>/<page_id>/<file>`.
  final String? storagePath;
  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final String? caption;

  /// معرّف صف `attachments` المرتبط بالكتلة.
  final String? attachmentId;
  final int? width;
  final int? height;

  static const MediaData empty = MediaData();

  bool get hasFile => (storagePath ?? '').trim().isNotEmpty;

  String get displayName => (fileName ?? '').trim();

  factory MediaData.fromContent(Map<String, dynamic> content) => MediaData(
        storagePath: _nullableString(content['storage_path']),
        fileName: _nullableString(content['file_name']),
        mimeType: _nullableString(content['mime_type']),
        sizeBytes: _nullableInt(content['size_bytes']),
        caption: _nullableString(content['caption']),
        attachmentId: _nullableString(content['attachment_id']),
        width: _nullableInt(content['width']),
        height: _nullableInt(content['height']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'storage_path': storagePath,
        'file_name': fileName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'caption': caption,
        'attachment_id': attachmentId,
        'width': width,
        'height': height,
      };

  MediaData withFile({
    required String storagePath,
    required String fileName,
    String? mimeType,
    int? sizeBytes,
    String? attachmentId,
    int? width,
    int? height,
  }) =>
      MediaData(
        storagePath: storagePath,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        caption: caption,
        attachmentId: attachmentId,
        width: width,
        height: height,
      );

  MediaData withCaption(String? caption) => MediaData(
        storagePath: storagePath,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        caption: _nullableString(caption),
        attachmentId: attachmentId,
        width: width,
        height: height,
      );

  /// إزالة الملف (يُستخدم بعد حذف المرفق من التخزين).
  MediaData cleared() => MediaData(caption: caption);
}

// ─────────────────────────────────────────────────────────────────────────────
//  6) الكود — كتلة «code»
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class CodeData {
  const CodeData({required this.code, this.language});

  final String code;

  /// لغة الكود (اختيارية) — للعرض فقط، لا تلوين نحوي في هذه المرحلة.
  final String? language;

  static const CodeData empty = CodeData(code: '');

  bool get isEmpty => code.trim().isEmpty;

  factory CodeData.fromContent(Map<String, dynamic> content) => CodeData(
        code: _string(content['code']),
        language: _nullableString(content['language']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'language': language,
      };

  CodeData copyWith({String? code, String? language}) => CodeData(
        code: code ?? this.code,
        language: language ?? this.language,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  7) الاقتباس — كتلة «quote»
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class QuoteData {
  const QuoteData({required this.text});

  final String text;

  static const QuoteData empty = QuoteData(text: '');

  bool get isEmpty => text.trim().isEmpty;

  factory QuoteData.fromContent(Map<String, dynamic> content) =>
      QuoteData(text: _string(content['text']));

  Map<String, dynamic> toJson() => <String, dynamic>{'text': text};

  QuoteData copyWith({String? text}) => QuoteData(text: text ?? this.text);
}

// ─────────────────────────────────────────────────────────────────────────────
//  8) التنبيه — كتلة «callout»
// ─────────────────────────────────────────────────────────────────────────────

/// نبرة التنبيه (تغيّر لونه في التطبيق وفي PDF).
enum CalloutTone { info, warning, danger }

extension CalloutToneDb on CalloutTone {
  String get dbValue => name;

  static CalloutTone fromDb(Object? value) {
    final String raw = _string(value);
    for (final CalloutTone tone in CalloutTone.values) {
      if (tone.dbValue == raw) {
        return tone;
      }
    }
    return CalloutTone.info;
  }
}

@immutable
class CalloutData {
  const CalloutData({required this.title, required this.text, this.tone = CalloutTone.info});

  final String title;
  final String text;
  final CalloutTone tone;

  static const CalloutData empty = CalloutData(title: '', text: '');

  bool get isEmpty => title.trim().isEmpty && text.trim().isEmpty;

  factory CalloutData.fromContent(Map<String, dynamic> content) => CalloutData(
        title: _string(content['title']),
        text: _string(content['text']),
        tone: CalloutToneDb.fromDb(content['tone']),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'text': text,
        'tone': tone.dbValue,
      };

  CalloutData copyWith({String? title, String? text, CalloutTone? tone}) => CalloutData(
        title: title ?? this.title,
        text: text ?? this.text,
        tone: tone ?? this.tone,
      );
}
