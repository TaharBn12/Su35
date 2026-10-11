import 'package:flutter_dotenv/flutter_dotenv.dart';

/// خطأ إعداد يُعرَض للمستخدم في شاشة إعداد واضحة
/// بدل أن يتعطّل التطبيق أو يظهر استثناء غامض.
class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

/// قراءة مفاتيح Supabase من ملف `.env` (لا تُكتب المفاتيح داخل الكود أبدًا).
///
/// الملف `.env` مُضمَّن في assets حسب pubspec.yaml، ومستثنى من Git.
class AppConfig {
  const AppConfig._();

  static const String envFileName = '.env';
  static const String urlKey = 'SUPABASE_URL';
  static const String publishableKeyKey = 'SUPABASE_PUBLISHABLE_KEY';

  static bool _loaded = false;
  static String? _loadFailure;

  /// تُستدعى مرة واحدة في بداية التشغيل قبل `Supabase.initialize`.
  static Future<void> load() async {
    if (_loaded) {
      return;
    }
    try {
      await dotenv.load(fileName: envFileName);
      _loaded = true;
      _loadFailure = null;
    } catch (error) {
      _loaded = false;
      _loadFailure = error.toString();
    }
  }

  /// هل الإعداد مكتمل وجاهز للتشغيل؟
  static bool get isConfigured =>
      _loaded && supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// سبب فشل قراءة ملف الإعداد (يُعرض في شاشة الإعداد للمساعدة في التشخيص).
  static String? get loadFailure => _loadFailure;

  static String get supabaseUrl => _read(urlKey);

  /// تقبل القيمة الجديدة `sb_publishable_...` أو مفتاح anon القديم — كلاهما آمن
  /// للاستخدام في تطبيق العميل، والحماية الفعلية تأتي من سياسات RLS.
  static String get supabasePublishableKey => _read(publishableKeyKey);

  static String _read(String key) {
    if (!_loaded) {
      return '';
    }
    try {
      return (dotenv.env[key] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  /// يتحقق من الإعداد أو يرمي استثناءً واضحًا.
  static void assertConfigured() {
    if (loadFailure != null) {
      throw const AppConfigException('تعذّر قراءة الملف .env / Could not read .env');
    }
    if (supabaseUrl.isEmpty) {
      throw const AppConfigException('SUPABASE_URL غير موجود في ملف .env');
    }
    if (supabasePublishableKey.isEmpty) {
      throw const AppConfigException('SUPABASE_PUBLISHABLE_KEY غير موجود في ملف .env');
    }
    if (!supabaseUrl.startsWith('http')) {
      throw const AppConfigException('SUPABASE_URL يجب أن يبدأ بـ https://');
    }
  }
}
