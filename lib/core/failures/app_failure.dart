/// تصنيف الأخطاء على مستوى التطبيق — الواجهة تترجم كل نوع إلى رسالة مفهومة.
enum FailureKind {
  /// لا يوجد اتصال بالشبكة أو الخادم لا يستجيب
  network,

  /// خطأ مصادقة: بيانات دخول خاطئة، جلسة منتهية، حساب غير مؤكد
  auth,

  /// لا تصل الصلاحية (سياسات RLS / Storage)
  permission,

  /// العنصر غير موجود
  notFound,

  /// تعارض: عنصر مكرر (اسم وسم مكرر، مثلًا)
  conflict,

  /// بيانات غير صالحة أدخلها المستخدم أو يرفضها الخادم
  validation,

  /// خلل في إعداد التطبيق (ملف .env ناقص)
  config,

  /// أي خطأ آخر
  unknown,
}

/// خطأ موحّد يحمل تصنيفًا + رسالة تقنية تُعرَض في «تفاصيل تقنية».
class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.code,
    this.details,
  });

  const AppFailure.unknown([String message = 'Unexpected error'])
      : kind = FailureKind.unknown,
        message = message,
        code = null,
        details = null;

  final FailureKind kind;

  /// رسالة تقنية (بالإنجليزية عادةً) من الخادم أو من طبقة البيانات.
  final String message;

  /// رمز الخطأ إن وُجد (مثل رمز PostgREST).
  final String? code;

  /// تفاصيل إضافية للتشخيص.
  final String? details;

  @override
  String toString() =>
      'AppFailure(kind: ${kind.name}, code: $code, message: $message)';
}
