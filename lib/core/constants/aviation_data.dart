import 'package:flutter/material.dart';

/// فصل ATA — وحدة تنظيم الصيانة المعيارية (ATA 100 / iSpec 2200).
/// يُخزَّن الرمز فقط في قاعدة البيانات، وتُعرض التسمية حسب لغة الواجهة.
@immutable
class AtaChapter {
  const AtaChapter(this.code, this.titleEn, this.titleAr);

  /// رمز الفصل كما يُخزَّن في العمود pages.ata_chapter (مثال: "21").
  final String code;
  final String titleEn;
  final String titleAr;

  String title({required bool arabic}) => arabic ? titleAr : titleEn;

  /// مثال: "21 — Air Conditioning"
  String label({required bool arabic}) => '$code — ${title(arabic: arabic)}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AtaChapter && other.code == code);

  @override
  int get hashCode => code.hashCode;
}

/// بيانات مجال الطيران: أنواع الطائرات، فصول ATA، رموز وألوان الدفاتر.
class AviationData {
  const AviationData._();

  // ── أنواع الطائرات (مقترحات قابلة للتوسيع بحرية مكتوبة) ────────────────
  static const List<String> aircraftTypes = <String>[
    'A319',
    'A320',
    'A321',
    'A330-300',
    'A340-600',
    'A350-900',
    'A380-800',
    'B737-700',
    'B737-800',
    'B737 MAX 8',
    'B747-400',
    'B757-200',
    'B767-300ER',
    'B777-300ER',
    'B787-9',
    'B787-10',
    'E170',
    'E190',
    'ATR 42-600',
    'ATR 72-600',
    'C172S',
    'C182T',
    'PA-28-181',
    'DA 42 NG',
    'King Air 350',
    'PC-12',
    'H125',
    'H145',
    'B412',
    'Su-35',
    'MiG-29',
    'F-16C',
  ];

  // ── فصول ATA الأكثر استخدامًا في الصيانة اليومية ──────────────────────
  static const List<AtaChapter> ataChapters = <AtaChapter>[
    AtaChapter('00', 'General', 'عام'),
    AtaChapter('05', 'Time Limits & Maintenance Checks', 'حدود الزمن وفحوص الصيانة'),
    AtaChapter('11', 'Placards & Markings', 'اللوحات والعلامات'),
    AtaChapter('20', 'Standard Practices', 'الممارسات القياسية'),
    AtaChapter('21', 'Air Conditioning', 'التكييف والضغط'),
    AtaChapter('22', 'Auto Flight', 'الطيار الآلي'),
    AtaChapter('23', 'Communications', 'الاتصالات'),
    AtaChapter('24', 'Electrical Power', 'الطاقة الكهربائية'),
    AtaChapter('25', 'Equipment & Furnishings', 'التجهيزات والمقصورة'),
    AtaChapter('26', 'Fire Protection', 'الحماية من الحرائق'),
    AtaChapter('27', 'Flight Controls', 'أنظمة التحكم بالطيران'),
    AtaChapter('28', 'Fuel', 'الوقود'),
    AtaChapter('29', 'Hydraulic Power', 'الطاقة الهيدروليكية'),
    AtaChapter('30', 'Ice & Rain Protection', 'الحماية من الجليد والمطر'),
    AtaChapter('31', 'Indicating & Recording', 'أنظمة العرض والتسجيل'),
    AtaChapter('32', 'Landing Gear', 'معدات الهبوط'),
    AtaChapter('33', 'Lights', 'الإضاءة'),
    AtaChapter('34', 'Navigation', 'الملاحة'),
    AtaChapter('35', 'Oxygen', 'الأكسجين'),
    AtaChapter('36', 'Pneumatic', 'الهواء المضغوط'),
    AtaChapter('38', 'Water & Waste', 'المياه والصرف'),
    AtaChapter('49', 'Airborne Auxiliary Power (APU)', 'وحدة الطاقة المساعدة'),
    AtaChapter('51', 'Standard Practices — Structures', 'الممارسات الهيكلية'),
    AtaChapter('52', 'Doors', 'الأبواب'),
    AtaChapter('53', 'Fuselage', 'جسم الطائرة'),
    AtaChapter('54', 'Nacelles & Pylons', 'الحوض والمعلقات'),
    AtaChapter('55', 'Stabilizers', 'المثبتات الأفقية والعمودية'),
    AtaChapter('56', 'Windows', 'النوافذ'),
    AtaChapter('57', 'Wings', 'الأجنحة'),
    AtaChapter('61', 'Propellers', 'المراوح'),
    AtaChapter('71', 'Power Plant', 'مجموعة القدرة'),
    AtaChapter('72', 'Engine', 'المحرك'),
    AtaChapter('73', 'Engine Fuel & Control', 'وقود المحرك والتحكم'),
    AtaChapter('74', 'Ignition', 'الإشعال'),
    AtaChapter('75', 'Engine Air', 'هواء المحرك'),
    AtaChapter('76', 'Engine Controls', 'تحكم المحرك'),
    AtaChapter('77', 'Engine Indicating', 'مؤشرات المحرك'),
    AtaChapter('78', 'Exhaust', 'العادم'),
    AtaChapter('79', 'Oil', 'الزيت'),
    AtaChapter('80', 'Starting', 'تشغيل المحرك'),
  ];

  static AtaChapter? ataByCode(String? code) {
    if (code == null || code.isEmpty) {
      return null;
    }
    for (final AtaChapter chapter in ataChapters) {
      if (chapter.code == code) {
        return chapter;
      }
    }
    return null;
  }

  /// تسمية الفصل للعرض (تتعامل مع رموز مخصّصة غير موجودة في القائمة).
  static String ataLabel(String? code, {required bool arabic}) {
    if (code == null || code.isEmpty) {
      return '';
    }
    final AtaChapter? chapter = ataByCode(code);
    return chapter?.label(arabic: arabic) ?? code;
  }

  // ── رموز الدفاتر والصفحات ─────────────────────────────────────────────
  static const List<String> notebookIcons = <String>[
    '📘', '✈️', '🛠️', '📐', '📋', '🧭', '🛫', '🛬',
    '⚙️', '🔧', '📚', '🧪', '⚠️', '📡', '🔋', '🌍',
  ];

  static const List<String> pageIcons = <String>[
    '📝', '🛫', '✈️', '🛠️', '✅', '⚠️', '📋', '📐',
    '🧭', '💡', '🔍', '📌', '🖼️', '📄', '🧰', '🔩',
    '⛽', '🛬', '📊', '🔊',
  ];

  static const List<String> notebookColors = <String>[
    '#0B3D91', '#4FA3E3', '#0E7490', '#047857',
    '#B45309', '#B91C1C', '#7C3AED', '#DB2777',
    '#475569', '#65A30D',
  ];

  static const String defaultNotebookIcon = '📘';
  static const String defaultNotebookColor = '#0B3D91';
  static const String defaultPageIcon = '📝';

  /// تحويل نص اللون "#0B3D91" إلى Color مع قيمة احتياطية آمنة.
  static Color colorFromHex(String? hex, {Color fallback = const Color(0xFF0B3D91)}) {
    if (hex == null) {
      return fallback;
    }
    final String cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6) {
      return fallback;
    }
    final int? value = int.tryParse(cleaned, radix: 16);
    if (value == null) {
      return fallback;
    }
    return Color(0xFF000000 | value);
  }
}
