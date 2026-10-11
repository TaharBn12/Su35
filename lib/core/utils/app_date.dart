/// أدوات التاريخ والوقت بأسلوب الطيران (يوم شهر سنة + توقيت محلي).
/// لا نستخدم حزمة intl هنا لتفادي أي تعارض مع تثبيت flutter_localizations
/// لها، ولأن صيغة الطيران ثابتة وقابلة للتوثيق.
class AppDate {
  const AppDate._();

  static const List<String> _monthsEn = <String>[
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  static const List<String> _monthsAr = <String>[
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// صيغة ISO للتواريخ: 2026-10-11 (تُستخدم عند الكتابة في قاعدة البيانات).
  static String isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

  /// 11 OCT 2026 أو 11 أكتوبر 2026
  static String display(DateTime date, {required bool arabic}) {
    final String month = arabic
        ? _monthsAr[date.month - 1]
        : _monthsEn[date.month - 1];
    return '${_two(date.day)} $month ${date.year}';
  }

  /// 11 OCT 2026 • 14:05
  static String displayWithTime(DateTime date, {required bool arabic}) =>
      '${display(date, arabic: arabic)} • ${_two(date.hour)}:${_two(date.minute)}';

  /// 14:05
  static String time(DateTime date) => '${_two(date.hour)}:${_two(date.minute)}';

  /// قراءة آمنة لتواريخ Postgres (timestamptz) وتحويلها للتوقيت المحلي.
  static DateTime? tryParse(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.isUtc ? value.toLocal() : value;
    }
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed == null) {
        return null;
      }
      return parsed.isUtc ? parsed.toLocal() : parsed;
    }
    return null;
  }

  /// قراءة عمود DATE (بدون وقت) — يُعاد كتاريخ محلي عند منتصف الليل.
  static DateTime? tryParseDateOnly(Object? value) {
    if (value is String) {
      final DateTime? parsed = DateTime.tryParse(value);
      if (parsed == null) {
        return null;
      }
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    return tryParse(value);
  }

  /// النص الذي يُرسل إلى عمود DATE في Postgres.
  static String? toDateOnly(DateTime? date) =>
      date == null ? null : isoDate(DateTime(date.year, date.month, date.day));

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// هل التاريخ ضمن آخر [days] يومًا؟ (يُستخدم لشارات «حديث»)
  static bool isRecent(DateTime date, {int days = 7}) =>
      DateTime.now().difference(date).inDays < days;
}
