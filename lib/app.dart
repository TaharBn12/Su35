import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/settings_controller.dart';
import 'core/theme/app_theme.dart';
import 'l10n/l10n.dart';

/// جذر التطبيق: يربط المظهر واللغة (عربي/إنجليزي + RTL) بالموجّه.
///
/// - `themeMode` و `locale` يأتيان من [settingsControllerProvider] المحفوظ محليًا.
/// - تُضاف مندوبات ترجمة محرّر Quill إلى جانب مندوبات التطبيق.
/// - دعم RTL يحدث تلقائيًا لأن اللغة العربية ضمن `supportedLocales`
///   ومندوبات الترجمة الرسمية (GlobalMaterialLocalizations) تُطبّق الاتجاه.
class Su35App extends ConsumerWidget {
  const Su35App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final GoRouter router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppL10n.supportedLocales,
      // مندوبات التطبيق + مندوبات محرّر Quill (غالبًا ما يحتاجها المحرّر
      // لأزراره ونصوصه الداخلية).
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        ...AppL10n.localizationsDelegates,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (BuildContext context, Widget? child) {
        // نحافظ على حجم خط النظام: لا تكبير تلقائي عند تغيير اللغة.
        return MediaQuery.withClampedTextScaling(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.6,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
