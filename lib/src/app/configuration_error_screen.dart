import 'package:flutter/material.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';

/// Shown when the app cannot start because `assets/env/.env` is missing or
/// still contains the placeholder values.
///
/// This screen deliberately does not depend on Riverpod or Supabase so it can
/// be rendered from a bare `MaterialApp` inside `main()`'s error path.
class ConfigurationErrorScreen extends StatelessWidget {
  const ConfigurationErrorScreen({
    required this.title,
    required this.message,
    super.key,
    this.locale,
  });

  final String title;
  final String message;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    final translations = locale != null && locale!.languageCode == 'ar'
        ? AppTranslations.arabic
        : AppTranslations.english;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildDark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
      ],
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 24),
                Icon(
                  Icons.settings_ethernet_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 20),
                Text(
                  translations.get('error.envNotConfigured'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  child: SelectableText(
                    message,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _StepsCard(translations: translations),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.translations});

  final AppTranslations translations;

  @override
  Widget build(BuildContext context) {
    final steps = <String>[
      '1. cp .env.example assets/env/.env',
      '2. Supabase Dashboard → Project Settings → API',
      '3. SUPABASE_URL=https://<project-ref>.supabase.co',
      '4. SUPABASE_ANON_KEY=<anon public key>',
      '5. flutter run',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps
            .map(
              (step) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
