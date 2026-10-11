import 'package:flutter/foundation.dart';

import '../../../core/constants/aviation_data.dart';
import '../../../core/utils/app_date.dart';

/// صفحة ملاحظة داخل دفتر — قد تحتوي صفحات فرعية (صفحة داخل صفحة).
///
/// سُمّيت NotePage (لا Page) لتجنّب التعارض مع واجهة `Page` في Flutter.
@immutable
class NotePage {
  const NotePage({
    required this.id,
    required this.notebookId,
    required this.title,
    this.parentPageId,
    this.icon,
    this.summary,
    this.contentText,
    this.templateKey,
    this.aircraftType,
    this.tailNumber,
    this.ataChapter,
    this.airportIcao,
    this.flightDate,
    this.isFavorite = false,
    this.isArchived = false,
    this.sortOrder = 100,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String notebookId;
  final String? parentPageId;
  final String title;
  final String? icon;
  final String? summary;

  /// نص مسطّح مُجمَّع من الكتل (يُملأ في المرحلة (ب) — يُستخدم للبحث والمعاينة).
  final String? contentText;

  /// مفتاح القالب الذي أُنشئت منه الصفحة (المرحلة (ج)).
  final String? templateKey;

  final String? aircraftType;
  final String? tailNumber;
  final String? ataChapter;
  final String? airportIcao;
  final DateTime? flightDate;

  final bool isFavorite;
  final bool isArchived;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayIcon =>
      (icon == null || icon!.isEmpty) ? AviationData.defaultPageIcon : icon!;

  bool get isSubPage => parentPageId != null;

  /// هل تحوي الصفحة أي حقل جوي مُعبَّأ؟
  bool get hasAviationDetails =>
      (aircraftType ?? '').isNotEmpty ||
      (tailNumber ?? '').isNotEmpty ||
      (ataChapter ?? '').isNotEmpty ||
      (airportIcao ?? '').isNotEmpty ||
      flightDate != null;

  factory NotePage.fromRow(Map<String, dynamic> row) {
    return NotePage(
      id: (row['id'] as String?) ?? '',
      notebookId: (row['notebook_id'] as String?) ?? '',
      parentPageId: row['parent_page_id'] as String?,
      title: (row['title'] as String?) ?? '',
      icon: row['icon'] as String?,
      summary: row['summary'] as String?,
      contentText: row['content_text'] as String?,
      templateKey: row['template_key'] as String?,
      aircraftType: row['aircraft_type'] as String?,
      tailNumber: row['tail_number'] as String?,
      ataChapter: row['ata_chapter'] as String?,
      airportIcao: row['airport_icao'] as String?,
      flightDate: AppDate.tryParseDateOnly(row['flight_date']),
      isFavorite: (row['is_favorite'] as bool?) ?? false,
      isArchived: (row['is_archived'] as bool?) ?? false,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
      createdAt: AppDate.tryParse(row['created_at']),
      updatedAt: AppDate.tryParse(row['updated_at']),
    );
  }

  /// الحقول التي تُرسل عند إنشاء صفحة جديدة.
  Map<String, dynamic> toInsertPayload(String userId) {
    return <String, dynamic>{
      'user_id': userId,
      'notebook_id': notebookId,
      'parent_page_id': parentPageId,
      'title': title.trim(),
      'icon': displayIcon,
      'summary': _nullable(summary),
      'template_key': _nullable(templateKey),
      'aircraft_type': _nullable(aircraftType),
      'tail_number': _nullable(tailNumber),
      'ata_chapter': _nullable(ataChapter),
      'airport_icao': _nullable(airportIcao),
      'flight_date': AppDate.toDateOnly(flightDate),
      'is_favorite': isFavorite,
      'is_archived': isArchived,
      'sort_order': sortOrder,
    };
  }

  NotePage copyWith({
    String? id,
    String? notebookId,
    String? parentPageId,
    String? title,
    String? icon,
    String? summary,
    String? contentText,
    String? templateKey,
    String? aircraftType,
    String? tailNumber,
    String? ataChapter,
    String? airportIcao,
    DateTime? flightDate,
    bool? isFavorite,
    bool? isArchived,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotePage(
      id: id ?? this.id,
      notebookId: notebookId ?? this.notebookId,
      parentPageId: parentPageId ?? this.parentPageId,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      summary: summary ?? this.summary,
      contentText: contentText ?? this.contentText,
      templateKey: templateKey ?? this.templateKey,
      aircraftType: aircraftType ?? this.aircraftType,
      tailNumber: tailNumber ?? this.tailNumber,
      ataChapter: ataChapter ?? this.ataChapter,
      airportIcao: airportIcao ?? this.airportIcao,
      flightDate: flightDate ?? this.flightDate,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _nullable(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotePage &&
          other.id == id &&
          other.notebookId == notebookId &&
          other.parentPageId == parentPageId &&
          other.title == title &&
          other.icon == icon &&
          other.summary == summary &&
          other.contentText == contentText &&
          other.templateKey == templateKey &&
          other.aircraftType == aircraftType &&
          other.tailNumber == tailNumber &&
          other.ataChapter == ataChapter &&
          other.airportIcao == airportIcao &&
          other.flightDate == flightDate &&
          other.isFavorite == isFavorite &&
          other.isArchived == isArchived &&
          other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(
        id,
        notebookId,
        parentPageId,
        title,
        icon,
        summary,
        contentText,
        templateKey,
        aircraftType,
        tailNumber,
        ataChapter,
        airportIcao,
        flightDate,
        isFavorite,
        isArchived,
        sortOrder,
      );

  @override
  String toString() => 'NotePage($id, $title, parent: $parentPageId)';
}

/// عنصر في الشجرة المسطّحة: صفحة + عُمقها (0 للمستوى الرئيسي).
@immutable
class PageNode {
  const PageNode({required this.page, required this.depth});

  final NotePage page;
  final int depth;
}

/// أدوات بناء شجرة الصفحات المتداخلة (صفحة داخل صفحة).
class PageTree {
  const PageTree._();

  static int _compare(NotePage a, NotePage b) {
    if (a.sortOrder != b.sortOrder) {
      return a.sortOrder.compareTo(b.sortOrder);
    }
    final DateTime aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
    final DateTime bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
    return bDate.compareTo(aDate);
  }

  /// أبناء صفحة معيّنة (أو الصفحات الرئيسية إذا كان [parentId] فارغًا).
  static List<NotePage> childrenOf(List<NotePage> pages, String? parentId) {
    final List<NotePage> result = pages
        .where((NotePage page) => page.parentPageId == parentId)
        .toList(growable: false);
    return <NotePage>[...result]..sort(_compare);
  }

  /// تسطيح الشجرة لعرضها في قائمة واحدة مع إزاحة بصرية.
  /// [maxDepth] يمنع أي حلقة لا نهائية (التحقق موجود أيضًا في قاعدة البيانات).
  static List<PageNode> flatten(
    List<NotePage> pages, {
    String? rootParentId,
    int maxDepth = 10,
  }) {
    final List<PageNode> output = <PageNode>[];
    void walk(String? parentId, int depth) {
      if (depth > maxDepth) {
        return;
      }
      for (final NotePage page in childrenOf(pages, parentId)) {
        output.add(PageNode(page: page, depth: depth));
        walk(page.id, depth + 1);
      }
    }

    walk(rootParentId, 0);
    return output;
  }

  /// كل الصفحات المتفرّعة عن صفحة (تُستخدم لحساب أثر الحذف).
  static List<NotePage> descendantsOf(List<NotePage> pages, String pageId) {
    final List<NotePage> result = <NotePage>[];
    void walk(String parentId) {
      for (final NotePage child in childrenOf(pages, parentId)) {
        result.add(child);
        walk(child.id);
      }
    }

    walk(pageId);
    return result;
  }
}
