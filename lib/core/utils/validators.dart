import '../../l10n/l10n.dart';

/// تحققات مشتركة لكل نماذج الإدخال.
/// الحقول الجوية (ICAO / رقم التسجيل) اختيارية، لكن إذا كُتب فيها شيء
/// فيجب أن تُطابق الصيغة المعيارية.
class Validators {
  const Validators._();

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  static final RegExp _icaoPattern = RegExp(r'^[A-Za-z]{4}$');
  static final RegExp _tailNumberPattern = RegExp(r'^[A-Za-z0-9\-]{2,16}$');

  static String? email(String? value, AppL10n l10n) {
    final String email = (value ?? '').trim();
    if (email.isEmpty) {
      return l10n.validationEmailRequired;
    }
    if (!_emailPattern.hasMatch(email)) {
      return l10n.validationEmailInvalid;
    }
    return null;
  }

  static String? password(String? value, AppL10n l10n, {int minLength = 8}) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return l10n.validationPasswordRequired;
    }
    if (password.length < minLength) {
      return l10n.validationPasswordTooShort;
    }
    return null;
  }

  static String? confirmPassword(
    String? value,
    String? original,
    AppL10n l10n,
  ) {
    if ((value ?? '').isEmpty) {
      return l10n.validationPasswordRequired;
    }
    if (value != original) {
      return l10n.validationPasswordsMismatch;
    }
    return null;
  }

  static String? requiredName(String? value, AppL10n l10n) {
    if ((value ?? '').trim().isEmpty) {
      return l10n.validationNameRequired;
    }
    return null;
  }

  static String? title(String? value, AppL10n l10n, {int maxLength = 200}) {
    final String title = (value ?? '').trim();
    if (title.isEmpty) {
      return l10n.validationTitleRequired;
    }
    if (title.length > maxLength) {
      return l10n.validationTitleTooLong;
    }
    return null;
  }

  /// رمز مطار ICAO: ٤ أحرف لاتينية — حقل اختياري.
  static String? icao(String? value, AppL10n l10n) {
    final String code = (value ?? '').trim();
    if (code.isEmpty) {
      return null;
    }
    if (!_icaoPattern.hasMatch(code)) {
      return l10n.validationIcaoInvalid;
    }
    return null;
  }

  /// رقم التسجيل (Registration) — حقل اختياري.
  static String? tailNumber(String? value, AppL10n l10n) {
    final String tail = (value ?? '').trim();
    if (tail.isEmpty) {
      return null;
    }
    if (!_tailNumberPattern.hasMatch(tail)) {
      return l10n.validationTailNumberInvalid;
    }
    return null;
  }

  /// تحويل نص إلى أحرف كبيرة (لتطبيع ICAO/التسجيل/نوع الطائرة).
  static String upper(String? value) => (value ?? '').trim().toUpperCase();

  /// تحويل نص فارغ إلى null (لتخزين NULL بدل سلاسل فارغة في Postgres).
  static String? nullable(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}
