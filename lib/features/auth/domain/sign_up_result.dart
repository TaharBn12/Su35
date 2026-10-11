import 'app_user.dart';

/// نتيجة إنشاء حساب جديد.
class SignUpResult {
  const SignUpResult({
    required this.user,
    required this.needsEmailConfirmation,
  });

  /// المستخدم المُنشأ (قد يكون null إذا لم يُعدّه الخادم بعد).
  final AppUser? user;

  /// true إذا كان تأكيد البريد الإلكتروني مُفعَّلًا في مشروع Supabase،
  /// أي أن الحساب لن يستطيع تسجيل الدخول قبل تأكيد البريد.
  final bool needsEmailConfirmation;
}
