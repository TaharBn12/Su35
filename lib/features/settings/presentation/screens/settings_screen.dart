import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/settings/settings_controller.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/application/app_auth_state.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/app_user.dart';
import '../../../auth/presentation/widgets/role_selector.dart';
import '../widgets/profile_edit_sheet.dart';

/// الإعدادات: المظهر (وضع ليلي)، اللغة (عربي/إنجليزي + RTL)، الحساب، وعن التطبيق.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final AppL10n l10n = context.l10n;
    final bool confirmed = await showConfirmDialog(
      context,
      title: l10n.authSignOutButton,
      body: l10n.authSignOutConfirmBody,
      confirmLabel: l10n.authSignOutButton,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(authControllerProvider.notifier).signOut();
      if (!context.mounted) {
        return;
      }
      showAppSnack(context, l10n.authSignedOutMessage);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppFailureSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool isArabic = context.isArabic;
    final AppSettings settings = ref.watch(settingsControllerProvider);
    final AppAuthState auth = ref.watch(authControllerProvider);
    final AppUser? user = auth.user;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: <Widget>[
          if (auth.failure != null) ...<Widget>[
            AppInlineErrorCard(
              failure: auth.failure!,
              onRetry: () =>
                  ref.read(authControllerProvider.notifier).refreshProfile(),
            ),
            const SizedBox(height: 16),
          ],
          _SectionTitle(
            icon: Icons.palette_outlined,
            title: l10n.settingsAppearanceSection,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.settingsThemeLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: <ButtonSegment<ThemeMode>>[
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          label: Text(l10n.settingsThemeSystem),
                          icon: const Icon(Icons.brightness_auto_rounded),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          label: Text(l10n.settingsThemeLight),
                          icon: const Icon(Icons.light_mode_rounded),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          label: Text(l10n.settingsThemeDark),
                          icon: const Icon(Icons.dark_mode_rounded),
                        ),
                      ],
                      selected: <ThemeMode>{settings.themeMode},
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setThemeMode(selection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.settingsLanguageLabel,
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: <ButtonSegment<String>>[
                        ButtonSegment<String>(
                          value: 'ar',
                          label: Text(l10n.settingsLanguageArabic),
                        ),
                        ButtonSegment<String>(
                          value: 'en',
                          label: Text(l10n.settingsLanguageEnglish),
                        ),
                      ],
                      selected: <String>{settings.locale.languageCode},
                      onSelectionChanged: (Set<String> selection) {
                        ref
                            .read(settingsControllerProvider.notifier)
                            .setLocale(Locale(selection.first));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.account_circle_outlined,
            title: l10n.settingsAccountSection,
          ),
          Card(
            child: Column(
              children: <Widget>[
                _InfoTile(
                  icon: Icons.alternate_email_rounded,
                  label: l10n.settingsEmailLabel,
                  value: user?.email ?? l10n.stateNotSet,
                  ltr: true,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.person_outline_rounded,
                  label: l10n.authDisplayNameLabel,
                  value: user?.displayName ?? l10n.stateNotSet,
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.work_outline_rounded,
                  label: l10n.settingsRoleLabel,
                  value: user == null
                      ? l10n.stateNotSet
                      : roleLabel(user.role, l10n),
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.event_available_outlined,
                  label: l10n.settingsMemberSinceLabel,
                  value: user?.memberSince == null
                      ? l10n.stateNotSet
                      : AppDate.display(user!.memberSince!, arabic: isArabic),
                ),
                const Divider(height: 1),
                _InfoTile(
                  icon: Icons.public_rounded,
                  label: l10n.fieldAirport,
                  value: user?.homeBaseIcao ?? l10n.stateNotSet,
                  ltr: true,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.settingsEditProfile),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: user == null
                      ? null
                      : () => showProfileEditSheet(context, user),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.info_outline_rounded,
            title: l10n.settingsAboutSection,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.appName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.appVersion(AppInfo.version),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.settingsAboutBody,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            icon: Icons.cloud_sync_outlined,
            title: l10n.settingsDataSection,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                l10n.settingsOfflineState,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
            icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
            label: Text(
              l10n.authSignOutButton,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.ltr = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        value,
        textDirection: ltr ? TextDirection.ltr : null,
        style: theme.textTheme.bodyLarge,
      ),
    );
  }
}
