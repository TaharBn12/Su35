import '../../core/utils/json_utils.dart';

/// A row of `public.pages`.
///
/// Pages live inside a notebook and can nest inside another page through
/// [parentPageId] (Notion-style). The aviation metadata (aircraft type,
/// registration, ATA chapter, ICAO airports, date) is stored on the page so it
/// can be filtered and searched later (Stage C).
class NotePage {
  const NotePage({
    required this.id,
    required this.userId,
    required this.notebookId,
    this.parentPageId,
    required this.title,
    this.icon,
    this.coverUrl,
    this.summary,
    this.templateKey,
    this.aircraftType,
    this.registration,
    this.ataChapter,
    this.airportIcao,
    this.departureIcao,
    this.arrivalIcao,
    this.flightDate,
    this.position = 0,
    this.isArchived = false,
    this.isFavorite = false,
    this.childCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String notebookId;

  /// `null` for a top-level page of the notebook.
  final String? parentPageId;

  final String title;
  final String? icon;
  final String? coverUrl;
  final String? summary;

  /// `flight_log`, `maintenance_note`, `preflight_checklist`,
  /// `theory_lesson`, `defect_report` or `null` for a blank page.
  final String? templateKey;

  // --- Aviation specific fields -------------------------------------------
  final String? aircraftType;
  final String? registration;
  final String? ataChapter;
  final String? airportIcao;
  final String? departureIcao;
  final String? arrivalIcao;
  final DateTime? flightDate;

  final int position;
  final bool isArchived;
  final bool isFavorite;

  /// Number of direct sub-pages (maintained by a database trigger).
  final int childCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasChildren => childCount > 0;
  bool get isSubPage => parentPageId != null;

  factory NotePage.fromJson(Map<String, dynamic> json) {
    return NotePage(
      id: asString(json['id']),
      userId: asString(json['user_id']),
      notebookId: asString(json['notebook_id']),
      parentPageId: asNullableString(json['parent_page_id']),
      title: asString(json['title']),
      icon: asNullableString(json['icon']),
      coverUrl: asNullableString(json['cover_url']),
      summary: asNullableString(json['summary']),
      templateKey: asNullableString(json['template_key']),
      aircraftType: asNullableString(json['aircraft_type']),
      registration: asNullableString(json['registration']),
      ataChapter: asNullableString(json['ata_chapter']),
      airportIcao: asNullableString(json['airport_icao']),
      departureIcao: asNullableString(json['departure_icao']),
      arrivalIcao: asNullableString(json['arrival_icao']),
      flightDate: asNullableDateTime(json['flight_date']),
      position: asInt(json['position']),
      isArchived: asBool(json['is_archived']),
      isFavorite: asBool(json['is_favorite']),
      childCount: asInt(json['child_count']),
      createdAt: asDateTime(json['created_at']),
      updatedAt: asDateTime(json['updated_at']),
    );
  }

  static List<NotePage> listFromJson(Object? rows) =>
      asMapList(rows).map(NotePage.fromJson).toList(growable: false);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'notebook_id': notebookId,
      'parent_page_id': parentPageId,
      'title': title,
      'icon': icon,
      'cover_url': coverUrl,
      'summary': summary,
      'template_key': templateKey,
      'aircraft_type': aircraftType,
      'registration': registration,
      'ata_chapter': ataChapter,
      'airport_icao': airportIcao,
      'departure_icao': departureIcao,
      'arrival_icao': arrivalIcao,
      'flight_date': flightDate?.toIso8601String(),
      'position': position,
      'is_archived': isArchived,
      'is_favorite': isFavorite,
      'child_count': childCount,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  /// INSERT payload for a new page.
  Map<String, dynamic> toInsertJson() {
    return <String, dynamic>{
      'user_id': userId,
      'notebook_id': notebookId,
      if (parentPageId != null) 'parent_page_id': parentPageId,
      'title': title,
      if (icon != null) 'icon': icon,
      if (templateKey != null) 'template_key': templateKey,
      if (aircraftType != null) 'aircraft_type': aircraftType,
      if (registration != null) 'registration': registration,
      if (ataChapter != null) 'ata_chapter': ataChapter,
      if (airportIcao != null) 'airport_icao': airportIcao,
      if (departureIcao != null) 'departure_icao': departureIcao,
      if (arrivalIcao != null) 'arrival_icao': arrivalIcao,
      if (flightDate != null) 'flight_date': flightDate!.toIso8601String(),
      'position': position,
    };
  }

  /// PATCH payload for the aviation metadata + title.
  Map<String, dynamic> toUpdateJson() {
    return <String, dynamic>{
      'title': title,
      'icon': icon,
      'summary': summary,
      'aircraft_type': aircraftType,
      'registration': registration,
      'ata_chapter': ataChapter,
      'airport_icao': airportIcao,
      'departure_icao': departureIcao,
      'arrival_icao': arrivalIcao,
      'flight_date': flightDate?.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  NotePage copyWith({
    String? title,
    String? icon,
    String? summary,
    String? parentPageId,
    String? aircraftType,
    String? registration,
    String? ataChapter,
    String? airportIcao,
    String? departureIcao,
    String? arrivalIcao,
    DateTime? flightDate,
    int? position,
    bool? isArchived,
    bool? isFavorite,
    int? childCount,
    DateTime? updatedAt,
  }) {
    return NotePage(
      id: id,
      userId: userId,
      notebookId: notebookId,
      parentPageId: parentPageId ?? this.parentPageId,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      coverUrl: coverUrl,
      summary: summary ?? this.summary,
      templateKey: templateKey,
      aircraftType: aircraftType ?? this.aircraftType,
      registration: registration ?? this.registration,
      ataChapter: ataChapter ?? this.ataChapter,
      airportIcao: airportIcao ?? this.airportIcao,
      departureIcao: departureIcao ?? this.departureIcao,
      arrivalIcao: arrivalIcao ?? this.arrivalIcao,
      flightDate: flightDate ?? this.flightDate,
      position: position ?? this.position,
      isArchived: isArchived ?? this.isArchived,
      isFavorite: isFavorite ?? this.isFavorite,
      childCount: childCount ?? this.childCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Aviation chips shown under the page title (skips empty values).
  List<String> get metadataChips {
    final chips = <String>[];
    if (aircraftType != null && aircraftType!.isNotEmpty) {
      chips.add(aircraftType!);
    }
    if (registration != null && registration!.isNotEmpty) {
      chips.add(registration!);
    }
    if (ataChapter != null && ataChapter!.isNotEmpty) {
      chips.add('ATA $ataChapter');
    }
    if (departureIcao != null && arrivalIcao != null) {
      chips.add('$departureIcao → $arrivalIcao');
    } else if (airportIcao != null && airportIcao!.isNotEmpty) {
      chips.add(airportIcao!);
    }
    return chips;
  }

  @override
  bool operator ==(Object other) => other is NotePage && other.id == id && other.updatedAt == updatedAt && other.title == title;

  @override
  int get hashCode => Object.hash(id, updatedAt, title);

  @override
  String toString() => 'NotePage($id, $title)';
}
