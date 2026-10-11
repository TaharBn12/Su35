import 'package:flutter/material.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'l10n/l10n.dart';

/// تطبيق مصغّر يُعرض فقط عندما يكون الإعداد ناقصًا (لا يوجد `.env` صالح)،
/// بدل أن يسقط التطبيق باستثناء غامض. لا يعتمد على Supabase ولا على الموجّه.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key, required this.details});

  /// نص الخطأ (AppConfigException أو خطأ تهيئة Supabase).
  final String details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale(AppInfo.defaultLocale),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: AppL10n.localizationsDelegates,
      home: SetupRequiredScreen(details: details),
    );
  }
}

/// شاشة إعداد واضحة: ماذا ينقص وكيف يُصلَح خطوة بخطوة.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key, required this.details});

  final String details;

  static const String _envTemplate = <String>[
    'SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co',
    'SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxxxxx',
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Icon(
                    Icons.settings_suggest_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.startupFailedTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        details,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.setupRequiredSteps,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.8),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConfig.envFileName,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _envTemplate,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'flutter pub get\nflutter gen-l10n\nflutter run',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
