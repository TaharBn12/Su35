import '../../core/utils/json_utils.dart';

/// A row of `public.notebooks`.
///
/// A workspace contains notebooks, a notebook contains pages (which can nest).
class Notebook {
  const Notebook({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    this.color,
    this.description,
    this.position = 0,
    this.isArchived = false,
    this.pagesCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;

  /// Emoji or short label rendered on the notebook card.
  final String? icon;

  /// Hex colour string such as `#0B4F8A`.
  final String? color;

  final String? description;
  final int position;
  final bool isArchived;
  final int pagesCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Notebook.fromJson(Map<String, dynamic> json) {
    return Notebook(
      id: asString(json['id']),
      userId: asString(json['user_id']),
      name: asString(json['name']),
      icon: asNullableString(json['icon']),
      color: asNullableString(json['color']),
      description: asNullableString(json['description']),
      position: asInt(json['position']),
      isArchived: asBool(json['is_archived']),
      pagesCount: asInt(json['pages_count']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  static List<Notebook> listFromJson(Object? rows) => asMapList(rows)
      .map(Notebook.fromJson)
      .toList(growable: false);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'name': name,
      'icon': icon,
      'color': color,
      'description': description,
      'position': position,
      'is_archived': isArchived,
      'pages_count': pagesCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// INSERT payload. `user_id` is filled server-side from `auth.uid()`, but we
  /// send it explicitly so RLS `WITH CHECK` always matches.
  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'user_id': userId,
      'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (description != null) 'description': description,
      'position': position,
    };
  }

  Notebook copyWith({
    String? name,
    String? icon,
    String? color,
    String? description,
    int? position,
    bool? isArchived,
    int? pagesCount,
    DateTime? updatedAt,
  }) {
    return Notebook(
      id: id,
      userId: userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      description: description ?? this.description,
      position: position ?? this.position,
      isArchived: isArchived ?? this.isArchived,
      pagesCount: pagesCount ?? this.pagesCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Falls back to a neutral colour when the stored hex value is invalid.
  int get colorValue {
    final raw = color;
    if (raw == null) return 0xFF0B4F8A;
    var hex = raw.replaceFirst('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    return int.tryParse(hex, radix: 16) ?? 0xFF0B4F8A;
  }

  @override
  bool operator ==(Object other) =>
      other is Notebook &&
      other.id == id &&
      other.name == name &&
      other.icon == icon &&
      other.color == color &&
      other.description == description &&
      other.position == position &&
      other.isArchived == isArchived &&
      other.pagesCount == pagesCount;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        icon,
        color,
        description,
        position,
        isArchived,
        pagesCount,
      );

  @override
  String toString() => 'Notebook($id, $name)';
}
