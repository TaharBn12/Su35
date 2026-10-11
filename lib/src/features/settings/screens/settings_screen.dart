import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_snackbars.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';

/// Appearance (dark mode), language (EN / AR with RTL), account and about.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final t = context.t;
    final confirmed = await showConfirmDialog(
      context,
      title: t.get('auth.signOut'),
      message: t.get('auth.signOutConfirm'),
      destructive: false,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(authRepositoryProvider).signOut();
      // The router redirect takes the user back to /auth.
    } catch (error) {
      if (context.mounted) AppSnackbars.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsControllerProvider);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;
    final sessionEmail = ref.watch(currentSessionProvider)?.user.email;

    return Scaffold(
      appBar: AppBar(title: Text(t.get('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          _SectionCard(
            title: t.get('settings.account'),
            icon: Icons.person_outline_rounded,
            children: <Widget>[
              _AccountTile(
                displayName: profile?.displayName ?? '—',
                email: profile?.email ?? sessionEmail ?? '—',
                isVerified: profile?.isEmailVerified ?? false,
                loading: profileAsync.isLoading && !profileAsync.hasValue,
              ),
              const Divider(),
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: t.get('auth.signOut'),
                destructive: true,
                onTap: () => _signOut(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: t.get('settings.appearance'),
            icon: Icons.dark_mode_outlined,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(t.get('settings.theme'),
                    style: theme.textTheme.labelMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: SegmentedButton<ThemeMode>(
                  segments: <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text(t.get('settings.theme.system')),
                      icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text(t.get('settings.theme.light')),
                      icon: const Icon(Icons.light_mode_rounded, size: 18),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text(t.get('settings.theme.dark')),
                      icon: const Icon(Icons.dark_mode_rounded, size: 18),
                    ),
                  ],
                  selected: <ThemeMode>{settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      controller.setThemeMode(selection.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: t.get('settings.language'),
            icon: Icons.translate_rounded,
            children: <Widget>[
              // Flutter 3.32+ : the group state lives in `RadioGroup`,
              // `RadioListTile.groupValue` / `.onChanged` are deprecated.
              RadioGroup<String>(
                groupValue: settings.locale.languageCode,
                onChanged: (value) {
                  if (value == 'ar') {
                    controller.setLocale(AppLocalizations.arabic);
                  } else {
                    controller.setLocale(AppLocalizations.english);
                  }
                },
                child: Column(
                  children: <Widget>[
                    RadioListTile<String>(
                      value: 'en',
                      title: Text(t.get('settings.language.en')),
                      subtitle: const Text('English · LTR'),
                    ),
                    RadioListTile<String>(
                      value: 'ar',
                      title: Text(t.get('settings.language.ar')),
                      subtitle: const Text('العربية · RTL'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: t.get('settings.offline'),
            icon: Icons.sync_outlined,
            children: <Widget>[
              _SettingsTile(
                icon: Icons.offline_bolt_outlined,
                title: t.get('generic.soon'),
                subtitle: t.get('settings.offlineHint'),
                onTap: () => AppSnackbars.info(context, t.get('generic.soon')),
              ),
              const Divider(),
              _SettingsTile(
                icon: Icons.search_rounded,
                title: t.get('nav.search'),
                subtitle: t.get('settings.searchHint'),
                onTap: () => AppSnackbars.info(context, t.get('generic.soon')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: t.get('settings.about'),
            icon: Icons.info_outline_rounded,
            children: <Widget>[
              _SettingsTile(
                icon: Icons.tag_rounded,
                title: t.get('settings.version'),
                subtitle: '${AppConstants.appName} ${AppConstants.appVersion}',
                onTap: () {},
              ),
              const Divider(),
              _SettingsTile(
                icon: Icons.fingerprint_rounded,
                title: t.get('settings.userId'),
                subtitle: profile?.id ?? '—',
                monospaceSubtitle: true,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: <Widget>[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.displayName,
    required this.email,
    required this.isVerified,
    required this.loading,
  });

  final String displayName;
  final String email;
  final bool isVerified;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;

    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              displayName.isEmpty ? '?' : displayName.characters.first,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 6),
                _VerifiedBadge(isVerified: isVerified),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    final color = isVerified
        ? const Color(0xFF1F7A5C)
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isVerified
                ? Icons.verified_rounded
                : Icons.gpp_maybe_outlined,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            isVerified
                ? t.get('settings.emailVerified')
                : t.get('settings.emailNotVerified'),
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.monospaceSubtitle = false,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool monospaceSubtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;

    return ListTile(
      leading: Icon(icon, size: 20, color: color),
      title: Text(title, style: theme.textTheme.bodyLarge?.copyWith(color: color)),
      subtitle: subtitle == null
          ? null
          : Directionality(
              textDirection: monospaceSubtitle
                  ? TextDirection.ltr
                  : Directionality.of(context),
              child: Text(
                subtitle!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: monospaceSubtitle ? 'monospace' : null,
                  color: color,
                ),
              ),
            ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
