import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Lightweight, dependency-free localization (English + Arabic with full RTL).
///
/// The app intentionally does **not** use `flutter gen-lints`/ARB codegen so
/// that the whole project stays readable as plain Dart. Adding a language means
/// adding one map below and one `Locale` in [AppLocalizations.supportedLocales].
class AppLocalizations {
  const AppLocalizations(this.locale, this.translations);

  final Locale locale;
  final AppTranslations translations;

  static const Locale english = Locale('en');
  static const Locale arabic = Locale('ar');

  static const List<Locale> supportedLocales = <Locale>[english, arabic];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final result = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    assert(result != null, 'AppLocalizations.delegate was not installed.');
    return result!;
  }

  bool get isRtl => locale.languageCode == 'ar';

  String get languageCode => locale.languageCode;

  /// Formats a date according to the active locale.
  String formatDate(DateTime? date) {
    if (date == null) return '';
    final localeName = locale.languageCode == 'ar' ? 'ar' : 'en_US';
    return DateFormat.yMMMd(localeName).format(date.toLocal());
  }

  /// Formats a date + time according to the active locale.
  String formatDateTime(DateTime? date) {
    if (date == null) return '';
    final localeName = locale.languageCode == 'ar' ? 'ar' : 'en_US';
    return DateFormat.yMMMd(localeName).add_Hm().format(date.toLocal());
  }

  /// Relative time ("3 min ago") - kept dependency free.
  String timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date.toLocal());
    final t = translations;
    if (diff.inSeconds < 60) return t.values['time.now']!;
    if (diff.inMinutes < 60) {
      return t.values['time.minutesAgo']!.replaceFirst(
        '{n}',
        diff.inMinutes.toString(),
      );
    }
    if (diff.inHours < 24) {
      return t.values['time.hoursAgo']!.replaceFirst(
        '{n}',
        diff.inHours.toString(),
      );
    }
    if (diff.inDays < 30) {
      return t.values['time.daysAgo']!.replaceFirst(
        '{n}',
        diff.inDays.toString(),
      );
    }
    return formatDate(date);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) {
    final translations = locale.languageCode == 'ar'
        ? AppTranslations.arabic
        : AppTranslations.english;
    return SynchronousFuture<AppLocalizations>(
      AppLocalizations(locale, translations),
    );
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Convenience accessor: `context.t.values['auth.signIn']`.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  AppTranslations get t => AppLocalizations.of(this).translations;
  bool get isRtl => AppLocalizations.of(this).isRtl;
}

/// A frozen bag of strings. Keys are stable identifiers used by
/// `AppFailure.messageKey` as well.
class AppTranslations {
  const AppTranslations(this.values);

  final Map<String, String> values;

  /// Returns the localized string for [key].
  ///
  /// When the key is missing, [fallback] is returned; when that is null too the
  /// key itself is returned so the UI never shows "null".
  String get(String key, [String? fallback]) {
    final value = values[key];
    if (value != null && value.isNotEmpty) return value;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return key;
  }

  /// Same as [get] but interpolates `{n}` and `{value}` placeholders.
  String plural(String key, int n) =>
      get(key).replaceFirst('{n}', n.toString());

  static const AppTranslations english = AppTranslations(_en);
  static const AppTranslations arabic = AppTranslations(_ar);
}

const Map<String, String> _en = <String, String>{
  // --- Generic -------------------------------------------------------------
  'app.name': 'AeroNotes',
  'app.tagline': 'Aviation knowledge, organized',
  'generic.cancel': 'Cancel',
  'generic.save': 'Save',
  'generic.create': 'Create',
  'generic.delete': 'Delete',
  'generic.rename': 'Rename',
  'generic.edit': 'Edit',
  'generic.retry': 'Retry',
  'generic.close': 'Close',
  'generic.search': 'Search',
  'generic.loading': 'Loading…',
  'generic.optional': 'optional',
  'generic.required': 'required',
  'generic.yes': 'Yes',
  'generic.no': 'No',
  'generic.open': 'Open',
  'generic.back': 'Back',
  'generic.done': 'Done',
  'generic.soon': 'Coming soon',
  'time.now': 'just now',
  'time.minutesAgo': '{n} min ago',
  'time.hoursAgo': '{n} h ago',
  'time.daysAgo': '{n} d ago',

  // --- Errors --------------------------------------------------------------
  'error.generic': 'Something went wrong. Please try again.',
  'error.network':
      'No internet connection. Check your network and try again.',
  'error.auth': 'Authentication failed.',
  'error.database': 'Database error.',
  'error.storage': 'Storage error.',
  'error.permission': 'You do not have access to this resource.',
  'error.notFound': 'Not found.',
  'error.conflict': 'This item already exists.',
  'error.foreignKey': 'Related record is missing.',
  'error.validation': 'The submitted values are not valid.',
  'error.invalidCredentials': 'Incorrect email or password.',
  'error.emailNotConfirmed':
      'Your email is not confirmed yet. Check your inbox.',
  'error.emailInUse': 'This email is already registered.',
  'error.weakPassword':
      'Password is too weak. Use at least 8 characters.',
  'error.invalidEmail': 'Enter a valid email address.',
  'error.rateLimit': 'Too many attempts. Please wait a moment.',
  'error.sessionExpired': 'Your session expired. Please sign in again.',
  'error.envNotConfigured': 'Supabase is not configured yet.',
  'error.routeNotFound': 'This screen does not exist.',

  // --- Validation ----------------------------------------------------------
  'validation.required': 'This field is required.',
  'validation.email': 'Enter a valid email address.',
  'validation.passwordMin': 'Password must be at least 8 characters.',
  'validation.passwordMismatch': 'Passwords do not match.',
  'validation.nameMin': 'Name must be at least 2 characters.',
  'validation.icao': 'ICAO codes are 4 letters, e.g. OMMG.',
  'validation.registration': 'Enter a valid registration, e.g. A6-EOV.',
  'validation.ataChapter': 'ATA chapter is a 2 or 3 digit number, e.g. 32.',

  // --- Auth ----------------------------------------------------------------
  'auth.signIn': 'Sign in',
  'auth.signUp': 'Create account',
  'auth.signOut': 'Sign out',
  'auth.email': 'Email',
  'auth.password': 'Password',
  'auth.confirmPassword': 'Confirm password',
  'auth.fullName': 'Full name',
  'auth.forgotPassword': 'Forgot password?',
  'auth.resetPassword': 'Send reset link',
  'auth.resetSent': 'If that email exists, a reset link was sent to it.',
  'auth.noAccount': "Don't have an account?",
  'auth.haveAccount': 'Already have an account?',
  'auth.welcomeTitle': 'Your aviation notebook',
  'auth.welcomeSubtitle':
      'Flight logs, maintenance notes, pre-flight checklists and theory lessons - all in one offline-ready workspace.',
  'auth.signedUpTitle': 'Check your email',
  'auth.signedUpBody':
      'We sent a confirmation link to {email}. Open it to activate your account, then sign in.',
  'auth.signOutConfirm': 'Sign out of AeroNotes?',
  'auth.signingIn': 'Signing in…',
  'auth.signingUp': 'Creating account…',

  // --- Navigation ----------------------------------------------------------
  'nav.notebooks': 'Notebooks',
  'nav.pages': 'Pages',
  'nav.settings': 'Settings',
  'nav.templates': 'Templates',
  'nav.search': 'Search',

  // --- Home / Notebooks ----------------------------------------------------
  'home.title': 'Notebooks',
  'home.subtitle': 'Organize your aviation knowledge by notebook.',
  'home.emptyTitle': 'No notebooks yet',
  'home.emptyBody':
      'Create your first notebook, for example "A320 Fleet", "Type Rating" or "Maintenance".',
  'home.newNotebook': 'New notebook',
  'home.notebookName': 'Notebook name',
  'home.notebookIcon': 'Icon',
  'home.notebookColor': 'Color',
  'home.createNotebook': 'Create notebook',
  'home.renameNotebook': 'Rename notebook',
  'home.deleteNotebook': 'Delete notebook',
  'home.deleteNotebookConfirm':
      'Delete "{name}" and every page inside it? This cannot be undone.',
  'home.pagesCount': '{n} pages',
  'home.onePage': '1 page',
  'home.noPages': 'No pages',
  'home.createdOk': 'Notebook created.',
  'home.renamedOk': 'Notebook renamed.',
  'home.deletedOk': 'Notebook deleted.',

  // --- Pages ---------------------------------------------------------------
  'pages.title': 'Pages',
  'pages.emptyTitle': 'This notebook is empty',
  'pages.emptyBody':
      'Add your first page. You can nest pages inside pages, like a Notion workspace.',
  'pages.newPage': 'New page',
  'pages.newSubPage': 'Add sub-page',
  'pages.pageTitle': 'Page title',
  'pages.createPage': 'Create page',
  'pages.renamePage': 'Rename page',
  'pages.deletePage': 'Delete page',
  'pages.deletePageConfirm':
      'Delete "{name}" and all of its sub-pages? This cannot be undone.',
  'pages.createdOk': 'Page created.',
  'pages.renamedOk': 'Page renamed.',
  'pages.deletedOk': 'Page deleted.',
  'pages.untitled': 'Untitled',
  'pages.aircraftType': 'Aircraft type',
  'pages.registration': 'Registration',
  'pages.ataChapter': 'ATA chapter',
  'pages.airport': 'Airport (ICAO)',
  'pages.departure': 'Departure (ICAO)',
  'pages.arrival': 'Arrival (ICAO)',
  'pages.flightDate': 'Date',
  'pages.template': 'Template',
  'pages.noTemplate': 'Blank page',
  'pages.advancedFields': 'Aviation fields',
  'pages.subPages': 'Sub-pages',
  'pages.viewerBanner':
      'Read-only view - the block editor (rich text, checklists, tables, images, PDF) arrives in Stage B.',
  'pages.noContent': 'This page has no content yet.',
  'pages.openPage': 'Open page',
  'pages.contentPreview': 'Content',
  'pages.wordCount': '{n} words',
  'pages.createdAt': 'Created',
  'pages.updatedAt': 'Last updated',

  // --- Templates -----------------------------------------------------------
  'template.flight_log': 'Flight Log',
  'template.maintenance_note': 'Maintenance Note',
  'template.preflight_checklist': 'Pre-flight Checklist',
  'template.theory_lesson': 'Theory Lesson',
  'template.defect_report': 'Defect Report',
  'template.flight_log.desc':
      'Route, times, fuel, crew and remarks for one flight.',
  'template.maintenance_note.desc':
      'Work performed, ATA chapter, parts and sign-off.',
  'template.preflight_checklist.desc':
      'Walk-around and cockpit checks as a checklist block.',
  'template.theory_lesson.desc':
      'Lesson summary with headings, key points and questions.',
  'template.defect_report.desc':
      'Defect description, severity, MEL reference and actions.',

  // --- Settings ------------------------------------------------------------
  'settings.title': 'Settings',
  'settings.appearance': 'Appearance',
  'settings.theme': 'Theme',
  'settings.theme.system': 'System',
  'settings.theme.light': 'Light',
  'settings.theme.dark': 'Dark',
  'settings.language': 'Language',
  'settings.language.en': 'English',
  'settings.language.ar': 'العربية (Arabic)',
  'settings.account': 'Account',
  'settings.profile': 'Profile',
  'settings.email': 'Email',
  'settings.emailVerified': 'Verified',
  'settings.emailNotVerified': 'Not verified',
  'settings.userId': 'User ID',
  'settings.about': 'About',
  'settings.version': 'Version',
  'settings.offline': 'Offline sync',
  'settings.offlineHint': 'Local cache and sync arrive in Stage D.',
  'settings.searchHint': 'Global search arrives in Stage C.',
  'settings.savedOk': 'Saved.',

  // --- Shared widgets ------------------------------------------------------
  'state.errorTitle': 'Could not load',
  'state.retry': 'Try again',
  'state.refresh': 'Pull to refresh',
};

const Map<String, String> _ar = <String, String>{
  // --- Generic -------------------------------------------------------------
  'app.name': 'دفتر الطيران',
  'app.tagline': 'معارفك الجوية، منظّمة',
  'generic.cancel': 'إلغاء',
  'generic.save': 'حفظ',
  'generic.create': 'إنشاء',
  'generic.delete': 'حذف',
  'generic.rename': 'إعادة تسمية',
  'generic.edit': 'تعديل',
  'generic.retry': 'إعادة المحاولة',
  'generic.close': 'إغلاق',
  'generic.search': 'بحث',
  'generic.loading': 'جارٍ التحميل…',
  'generic.optional': 'اختياري',
  'generic.required': 'مطلوب',
  'generic.yes': 'نعم',
  'generic.no': 'لا',
  'generic.open': 'فتح',
  'generic.back': 'رجوع',
  'generic.done': 'تم',
  'generic.soon': 'قريبًا',
  'time.now': 'الآن',
  'time.minutesAgo': 'قبل {n} دقيقة',
  'time.hoursAgo': 'قبل {n} ساعة',
  'time.daysAgo': 'قبل {n} يوم',

  // --- Errors --------------------------------------------------------------
  'error.generic': 'حدث خطأ ما، يرجى المحاولة مرة أخرى.',
  'error.network': 'لا يوجد اتصال بالإنترنت. تحقّق من الشبكة ثم أعد المحاولة.',
  'error.auth': 'فشلت عملية المصادقة.',
  'error.database': 'خطأ في قاعدة البيانات.',
  'error.storage': 'خطأ في التخزين.',
  'error.permission': 'ليس لديك صلاحية للوصول إلى هذا العنصر.',
  'error.notFound': 'العنصر غير موجود.',
  'error.conflict': 'هذا العنصر موجود مسبقًا.',
  'error.foreignKey': 'السجل المرتبط غير موجود.',
  'error.validation': 'القيم المُدخلة غير صحيحة.',
  'error.invalidCredentials': 'البريد الإلكتروني أو كلمة المرور غير صحيحة.',
  'error.emailNotConfirmed':
      'لم يتم تأكيد بريدك الإلكتروني بعد. تفقّد صندوق الوارد.',
  'error.emailInUse': 'هذا البريد الإلكتروني مسجّل مسبقًا.',
  'error.weakPassword': 'كلمة المرور ضعيفة، استخدم 8 أحرف على الأقل.',
  'error.invalidEmail': 'أدخل بريدًا إلكترونيًا صحيحًا.',
  'error.rateLimit': 'محاولات كثيرة، يرجى الانتظار قليلًا.',
  'error.sessionExpired': 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجددًا.',
  'error.envNotConfigured': 'لم يتم ضبط إعدادات Supabase بعد.',
  'error.routeNotFound': 'هذه الشاشة غير موجودة.',

  // --- Validation ----------------------------------------------------------
  'validation.required': 'هذا الحقل مطلوب.',
  'validation.email': 'أدخل بريدًا إلكترونيًا صحيحًا.',
  'validation.passwordMin': 'كلمة المرور يجب أن تكون 8 أحرف على الأقل.',
  'validation.passwordMismatch': 'كلمتا المرور غير متطابقتين.',
  'validation.nameMin': 'الاسم يجب أن يكون حرفين على الأقل.',
  'validation.icao': 'رمز ICAO مكوّن من 4 أحرف، مثال: OMMG.',
  'validation.registration': 'أدخل رقم تسجيل صحيحًا، مثال: A6-EOV.',
  'validation.ataChapter': 'فصل ATA رقم من خانتين أو ثلاث، مثال: 32.',

  // --- Auth ----------------------------------------------------------------
  'auth.signIn': 'تسجيل الدخول',
  'auth.signUp': 'إنشاء حساب',
  'auth.signOut': 'تسجيل الخروج',
  'auth.email': 'البريد الإلكتروني',
  'auth.password': 'كلمة المرور',
  'auth.confirmPassword': 'تأكيد كلمة المرور',
  'auth.fullName': 'الاسم الكامل',
  'auth.forgotPassword': 'هل نسيت كلمة المرور؟',
  'auth.resetPassword': 'إرسال رابط الاستعادة',
  'auth.resetSent': 'إن كان البريد مسجّلًا فقد أُرسل إليه رابط الاستعادة.',
  'auth.noAccount': 'ليس لديك حساب؟',
  'auth.haveAccount': 'لديك حساب بالفعل؟',
  'auth.welcomeTitle': 'دفتر ملاحظاتك الجوية',
  'auth.welcomeSubtitle':
      'سجلات الرحلات، ملاحظات الصيانة، قوائم الفحص قبل الطيران، وملخصات الدروس النظرية — في مساحة عمل واحدة تعمل دون إنترنت.',
  'auth.signedUpTitle': 'تفقّد بريدك الإلكتروني',
  'auth.signedUpBody':
      'أرسلنا رابط التأكيد إلى {email}. افتحه لتفعيل حسابك ثم سجّل الدخول.',
  'auth.signOutConfirm': 'تسجيل الخروج من دفتر الطيران؟',
  'auth.signingIn': 'جارٍ تسجيل الدخول…',
  'auth.signingUp': 'جارٍ إنشاء الحساب…',

  // --- Navigation ----------------------------------------------------------
  'nav.notebooks': 'الدفاتر',
  'nav.pages': 'الصفحات',
  'nav.settings': 'الإعدادات',
  'nav.templates': 'القوالب',
  'nav.search': 'البحث',

  // --- Home / Notebooks ----------------------------------------------------
  'home.title': 'الدفاتر',
  'home.subtitle': 'نظّم معارفك الجوية في دفاتر.',
  'home.emptyTitle': 'لا توجد دفاتر بعد',
  'home.emptyBody':
      'أنشئ دفترك الأول، مثل «أسطول A320» أو «التصنيف على النوع» أو «الصيانة».',
  'home.newNotebook': 'دفتر جديد',
  'home.notebookName': 'اسم الدفتر',
  'home.notebookIcon': 'الأيقونة',
  'home.notebookColor': 'اللون',
  'home.createNotebook': 'إنشاء الدفتر',
  'home.renameNotebook': 'إعادة تسمية الدفتر',
  'home.deleteNotebook': 'حذف الدفتر',
  'home.deleteNotebookConfirm':
      'حذف «{name}» وكل الصفحات داخله؟ لا يمكن التراجع.',
  'home.pagesCount': '{n} صفحات',
  'home.onePage': 'صفحة واحدة',
  'home.noPages': 'لا صفحات',
  'home.createdOk': 'تم إنشاء الدفتر.',
  'home.renamedOk': 'تمت إعادة تسمية الدفتر.',
  'home.deletedOk': 'تم حذف الدفتر.',

  // --- Pages ---------------------------------------------------------------
  'pages.title': 'الصفحات',
  'pages.emptyTitle': 'هذا الدفتر فارغ',
  'pages.emptyBody':
      'أضف صفحتك الأولى. يمكن إنشاء صفحات داخل صفحات تمامًا كما في Notion.',
  'pages.newPage': 'صفحة جديدة',
  'pages.newSubPage': 'إضافة صفحة فرعية',
  'pages.pageTitle': 'عنوان الصفحة',
  'pages.createPage': 'إنشاء الصفحة',
  'pages.renamePage': 'إعادة تسمية الصفحة',
  'pages.deletePage': 'حذف الصفحة',
  'pages.deletePageConfirm':
      'حذف «{name}» وكل صفحاتها الفرعية؟ لا يمكن التراجع.',
  'pages.createdOk': 'تم إنشاء الصفحة.',
  'pages.renamedOk': 'تمت إعادة تسمية الصفحة.',
  'pages.deletedOk': 'تم حذف الصفحة.',
  'pages.untitled': 'بدون عنوان',
  'pages.aircraftType': 'نوع الطائرة',
  'pages.registration': 'رقم التسجيل',
  'pages.ataChapter': 'فصل ATA',
  'pages.airport': 'المطار (ICAO)',
  'pages.departure': 'مطار الإقلاع (ICAO)',
  'pages.arrival': 'مطار الوصول (ICAO)',
  'pages.flightDate': 'التاريخ',
  'pages.template': 'القالب',
  'pages.noTemplate': 'صفحة فارغة',
  'pages.advancedFields': 'حقول الطيران',
  'pages.subPages': 'الصفحات الفرعية',
  'pages.viewerBanner':
      'عرض للقراءة فقط — محرّر البلوكات (نص منسّق، قوائم تحقق، جداول، صور، PDF) يصل في المرحلة (ب).',
  'pages.noContent': 'لا يوجد محتوى في هذه الصفحة بعد.',
  'pages.openPage': 'فتح الصفحة',
  'pages.contentPreview': 'المحتوى',
  'pages.wordCount': '{n} كلمة',
  'pages.createdAt': 'تاريخ الإنشاء',
  'pages.updatedAt': 'آخر تحديث',

  // --- Templates -----------------------------------------------------------
  'template.flight_log': 'سجل رحلة',
  'template.maintenance_note': 'ملاحظة صيانة',
  'template.preflight_checklist': 'قائمة الفحص قبل الطيران',
  'template.theory_lesson': 'ملخص درس نظري',
  'template.defect_report': 'تقرير عطل',
  'template.flight_log.desc': 'المسار، الأوقات، الوقود، الطاقم وملاحظات الرحلة.',
  'template.maintenance_note.desc':
      'الأعمال المنفّذة، فصل ATA، القطع المستخدمة والتوقيع.',
  'template.preflight_checklist.desc':
      'فحص خارجي وفحص المقصورة على شكل قائمة تحقق.',
  'template.theory_lesson.desc':
      'ملخص الدرس مع عناوين ونقاط رئيسية وأسئلة مراجعة.',
  'template.defect_report.desc':
      'وصف العطل، خطورته، مرجع MEL والإجراءات المتخذة.',

  // --- Settings ------------------------------------------------------------
  'settings.title': 'الإعدادات',
  'settings.appearance': 'المظهر',
  'settings.theme': 'السمة',
  'settings.theme.system': 'حسب النظام',
  'settings.theme.light': 'فاتح',
  'settings.theme.dark': 'داكن',
  'settings.language': 'اللغة',
  'settings.language.en': 'English (الإنجليزية)',
  'settings.language.ar': 'العربية',
  'settings.account': 'الحساب',
  'settings.profile': 'الملف الشخصي',
  'settings.email': 'البريد الإلكتروني',
  'settings.emailVerified': 'موثّق',
  'settings.emailNotVerified': 'غير موثّق',
  'settings.userId': 'معرّف المستخدم',
  'settings.about': 'حول التطبيق',
  'settings.version': 'الإصدار',
  'settings.offline': 'المزامنة دون إنترنت',
  'settings.offlineHint': 'التخزين المحلي والمزامنة يصلان في المرحلة (د).',
  'settings.searchHint': 'البحث الشامل يصل في المرحلة (ج).',
  'settings.savedOk': 'تم الحفظ.',

  // --- Shared widgets ------------------------------------------------------
  'state.errorTitle': 'تعذّر التحميل',
  'state.retry': 'حاول مجددًا',
  'state.refresh': 'اسحب للتحديث',
};
