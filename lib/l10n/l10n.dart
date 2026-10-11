// ══════════════════════════════════════════════════════════════════
//  مدخل موحّد للترجمات + اختصار الاستخدام داخل الواجهات
//  الملف المولَّد: lib/l10n/generated/app_localizations.dart
//  (يُولَّد تلقائيًا عبر `flutter run` أو `flutter gen-l10n`)
// ══════════════════════════════════════════════════════════════════
import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// الاستخدام: `context.l10n.notebooksTitle`
extension AppL10nBuildContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}

/// هل اللغة الحالية عربية؟ (يُستخدم لاختيار التسميات الجوية والصيغ)
extension AppL10nLocale on BuildContext {
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}
