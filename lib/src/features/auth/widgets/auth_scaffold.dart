import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../settings/providers/settings_provider.dart';

/// Shared chrome for the sign-in / sign-up screens:
/// a language switcher in the corner, the logo, a title and the form.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              PositionedDirectional(
                top: 8,
                end: 8,
                child: LanguageToggleButton(currentLocale: locale),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const AppLogo(size: 64, showTagline: true),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),
                        child,
                        if (footer != null) ...<Widget>[
                          const SizedBox(height: 24),
                          footer!,
                        ],
                        const SizedBox(height: 32),
                        const Center(child: AppVersionLabel()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact EN / AR switch used on the auth screens.
class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({required this.currentLocale, super.key});

  final Locale currentLocale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = currentLocale.languageCode == 'ar';
    return TextButton.icon(
      onPressed: () {
        ref.read(settingsControllerProvider).setLocale(
              isArabic ? AppLocalizations.english : AppLocalizations.arabic,
            );
      },
      icon: const Icon(Icons.translate_rounded, size: 18),
      label: Text(isArabic ? 'English' : 'العربية'),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}
