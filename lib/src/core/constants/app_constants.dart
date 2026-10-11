import 'package:supabase_flutter/supabase_flutter.dart';

/// App-wide constants.
class AppConstants {
  const AppConstants._();

  static const String appName = 'AeroNotes';
  static const String appVersion = '0.1.0';

  /// Supabase table names (kept in one place so a rename is a one-line change).
  static const String profilesTable = 'profiles';
  static const String notebooksTable = 'notebooks';
  static const String pagesTable = 'pages';
  static const String blocksTable = 'blocks';
  static const String tagsTable = 'tags';
  static const String pageTagsTable = 'page_tags';
  static const String attachmentsTable = 'attachments';

  /// Postgres function used by the global full-text search (Stage C wires it
  /// to the search screen; it already exists in the schema).
  static const String searchPagesFunction = 'search_pages';

  /// Storage bucket for attachments (can be overridden through .env).
  static const String defaultAttachmentsBucket = 'attachments';

  /// Deep-link / redirect URL used by email confirmation & password recovery.
  static const String authRedirectPath = '/auth/callback';

  /// Notebook / page limits kept generous but bounded to avoid runaway writes.
  static const int maxNotebooks = 200;
  static const int maxPagesPerNotebook = 2000;
  static const int maxPageDepth = 8;

  /// Editor auto-save debounce (used by the Stage B editor).
  static const Duration autosaveDebounce = Duration(milliseconds: 800);

  /// Defaults applied to newly created notebooks.
  static const String defaultNotebookIcon = '✈️';
  static const String defaultNotebookColor = '#0B4F8A';
  static const String defaultPageIcon = '📄';
}

/// Short alias for a PostgREST query builder, used across repositories.
typedef SupabaseQuery = SupabaseQueryBuilder;

/// Block types supported by the content model.
///
/// The Postgres enum `public.block_type` uses the exact same string values,
/// so a Dart `String` can be sent straight to the database.
class BlockTypes {
  const BlockTypes._();

  static const String paragraph = 'paragraph';
  static const String heading1 = 'heading1';
  static const String heading2 = 'heading2';
  static const String heading3 = 'heading3';
  static const String bulletList = 'bullet_list';
  static const String numberedList = 'numbered_list';
  static const String checklist = 'checklist';
  static const String table = 'table';
  static const String image = 'image';
  static const String pdf = 'pdf';
  static const String code = 'code';
  static const String divider = 'divider';
  static const String callout = 'callout';
  static const String page = 'page';

  static const List<String> all = <String>[
    paragraph,
    heading1,
    heading2,
    heading3,
    bulletList,
    numberedList,
    checklist,
    table,
    image,
    pdf,
    code,
    divider,
    callout,
    page,
  ];

  /// Blocks that carry no textual payload (rendered as a widget only).
  static const List<String> nonTextual = <String>[divider, image, pdf, table];
}

/// Ready-made aviation templates. `key` matches `pages.template_key` and the
/// rows seeded by the SQL migration.
class TemplateKeys {
  const TemplateKeys._();

  static const String flightLog = 'flight_log';
  static const String maintenance = 'maintenance_note';
  static const String preflightChecklist = 'preflight_checklist';
  static const String theoryLesson = 'theory_lesson';
  static const String defectReport = 'defect_report';
}

/// Common ATA-100 chapter codes used by the aviation domain.
///
/// Shown as quick picks in the page editor; free text is also allowed.
class AtaChapters {
  const AtaChapters._();

  static const Map<String, String> chapters = <String, String>{
    '21': 'Air Conditioning',
    '22': 'Auto Flight',
    '23': 'Communications',
    '24': 'Electrical Power',
    '25': 'Equipment / Furnishings',
    '26': 'Fire Protection',
    '27': 'Flight Controls',
    '28': 'Fuel',
    '29': 'Hydraulic Power',
    '30': 'Ice & Rain Protection',
    '31': 'Indicating / Recording',
    '32': 'Landing Gear',
    '33': 'Lights',
    '34': 'Navigation',
    '35': 'Oxygen',
    '36': 'Pneumatic',
    '38': 'Water / Waste',
    '49': 'Airborne Auxiliary Power',
    '51': 'Structures / Fuselage',
    '52': 'Doors',
    '53': 'Fuselage Structure',
    '54': 'Nacelles / Pylons',
    '55': 'Stabilizers',
    '56': 'Windows',
    '57': 'Wings',
    '70': 'Standard Practices - Engine',
    '71': 'Power Plant',
    '72': 'Engine - Turbine',
    '73': 'Engine Fuel Control',
    '74': 'Ignition',
    '75': 'Engine Air',
    '76': 'Engine Controls',
    '77': 'Engine Indicating',
    '78': 'Exhaust',
    '79': 'Engine Oil',
    '80': 'Starting',
};

  static List<String> get codes => chapters.keys.toList(growable: false);

  static String label(String code) => chapters[code] ?? code;
}

/// Aircraft types offered as quick picks for `pages.aircraft_type`.
class AircraftTypes {
  const AircraftTypes._();

  static const List<String> common = <String>[
    'A320',
    'A321',
    'A330',
    'A350',
    'B737',
    'B777',
    'B787',
    'C172',
    'DA40',
    'E195',
    'Su-35',
    'F-16',
    'AT72',
    'A380',
  ];
}
