/// Form validators shared by the auth screens and the page/notebook dialogs.
///
/// Every method returns `null` when the value is valid, or a translation key
/// that the caller resolves through `context.t.get(key)`.
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(
    r'^[\w.!#$%&’*+/=?^`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );
  static final RegExp _icao = RegExp(r'^[A-Za-z]{4}$');
  static final RegExp _registration = RegExp(r'^[A-Za-z0-9\-]{3,10}$');
  static final RegExp _ata = RegExp(r'^\d{2,3}$');

  static const int minPasswordLength = 8;

  static String? requiredText(String? value) {
    if (value == null || value.trim().isEmpty) return 'validation.required';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'validation.required';
    if (!_email.hasMatch(text)) return 'validation.email';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'validation.required';
    if (text.length < minPasswordLength) return 'validation.passwordMin';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) return 'validation.required';
    if (value != original) return 'validation.passwordMismatch';
    return null;
  }

  static String? displayName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'validation.required';
    if (text.length < 2) return 'validation.nameMin';
    return null;
  }

  /// Optional ICAO airport identifier (4 letters).
  static String? optionalIcao(String? value) {
    final text = value?.trim().toUpperCase() ?? '';
    if (text.isEmpty) return null;
    if (!_icao.hasMatch(text)) return 'validation.icao';
    return null;
  }

  /// Optional aircraft registration such as `A6-EOV`, `N12345`, `SU-GCU`.
  static String? optionalRegistration(String? value) {
    final text = value?.trim().toUpperCase() ?? '';
    if (text.isEmpty) return null;
    if (!_registration.hasMatch(text)) return 'validation.registration';
    return null;
  }

  /// Optional ATA-100 chapter number such as `32` or `032`.
  static String? optionalAtaChapter(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!_ata.hasMatch(text)) return 'validation.ataChapter';
    return null;
  }

  /// Normalizes an ATA chapter to two digits ("032" -> "32").
  static String? normalizeAta(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final number = int.tryParse(text);
    if (number == null) return null;
    return number.toString();
  }
}
