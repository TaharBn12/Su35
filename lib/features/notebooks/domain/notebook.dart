import 'package:flutter/foundation.dart';

import '../../../core/constants/aviation_data.dart';
import '../../../core/utils/app_date.dart';

/// دفتر = حاوية صفحات (رحلات، صيانة، دروس نظرية...).
@immutable
class Notebook {
  const Notebook({
    required this.id,
    required this.title,
    this.description,
    this.icon,
    this.color,
    this.aircraftType,
    this.isFavorite = false,
    this.isArchived = false,
    this.sortOrder = 100,
    this.pagesCount = 0,
    this.lastPageUpdate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? icon;
  final String? color;
  final String? aircraftType;
  final bool isFavorite;
  final bool isArchived;
  final int sortOrder;

  /// يأتي من العرض `notebook_page_counts` (ليس عمودًا في الجدول).
  final int pagesCount;
  final DateTime? lastPageUpdate;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get displayIcon => (icon == null || icon!.isEmpty)
      ? AviationData.defaultNotebookIcon
      : icon!;

  factory Notebook.fromRow(
    Map<String, dynamic> row, {
    int pagesCount = 0,
    DateTime? lastPageUpdate,
  }) {
    return Notebook(
      id: (row['id'] as String?) ?? '',
      title: (row['title'] as String?) ?? '',
      description: row['description'] as String?,
      icon: row['icon'] as String?,
      color: row['color'] as String?,
      aircraftType: row['aircraft_type'] as String?,
      isFavorite: (row['is_favorite'] as bool?) ?? false,
      isArchived: (row['is_archived'] as bool?) ?? false,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 100,
      createdAt: AppDate.tryParse(row['created_at']),
      updatedAt: AppDate.tryParse(row['updated_at']),
      pagesCount: pagesCount,
      lastPageUpdate: lastPageUpdate,
    );
  }

  /// الحقول التي تُرسل إلى PostgREST عند الإنشاء.
  Map<String, dynamic> toInsertPayload(String userId) {
    return <String, dynamic>{
      'user_id': userId,
      'title': title.trim(),
      'description': _nullable(description),
      'icon': displayIcon,
      'color': color ?? AviationData.defaultNotebookColor,
      'aircraft_type': _nullable(aircraftType),
      'is_favorite': isFavorite,
      'is_archived': isArchived,
      'sort_order': sortOrder,
    };
  }

  Notebook copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    String? color,
    String? aircraftType,
    bool? isFavorite,
    bool? isArchived,
    int? sortOrder,
    int? pagesCount,
    DateTime? lastPageUpdate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Notebook(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      aircraftType: aircraftType ?? this.aircraftType,
      isFavorite: isFavorite ?? this.isFavorite,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      pagesCount: pagesCount ?? this.pagesCount,
      lastPageUpdate: lastPageUpdate ?? this.lastPageUpdate,
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
      other is Notebook &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.icon == icon &&
          other.color == color &&
          other.aircraftType == aircraftType &&
          other.isFavorite == isFavorite &&
          other.isArchived == isArchived &&
          other.sortOrder == sortOrder &&
          other.pagesCount == pagesCount;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        icon,
        color,
        aircraftType,
        isFavorite,
        isArchived,
        sortOrder,
        pagesCount,
      );

  @override
  String toString() => 'Notebook($id, $title, pages: $pagesCount)';
}
