/// ثوابت عامة للتطبيق.
class AppInfo {
  const AppInfo._();

  static const String name = 'SU-35 Notes';

  /// نفس قيمة `version` في pubspec.yaml.
  static const String version = '1.0.0+1';

  static const String defaultLocale = 'ar';
  static const List<String> supportedLanguageCodes = <String>['ar', 'en'];

  /// الحد الأقصى لحجم المرفق الواحد (يطابق إعداد الباكت في schema.sql).
  static const int maxAttachmentBytes = 52428800; // 50 MB

  static const String attachmentsBucket = 'attachments';
}
