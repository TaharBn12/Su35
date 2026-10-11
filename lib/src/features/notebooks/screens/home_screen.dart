import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/notebook.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_snackbars.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/providers/profile_provider.dart';
import '../widgets/notebook_card.dart';
import '../widgets/notebook_dialogs.dart';

/// Workspace root: the list of notebooks.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await submitNotebookSheet(context, ref);
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Notebook notebook,
  ) async {
    await submitNotebookSheet(context, ref, existing: notebook);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Notebook notebook,
  ) async {
    final t = context.t;
    final confirmed = await showConfirmDialog(
      context,
      title: t.get('home.deleteNotebook'),
      message: t
          .get('home.deleteNotebookConfirm')
          .replaceFirst('{name}', notebook.name),
    );
    if (!confirmed || !context.mounted) return;

    final ok = await ref
        .read(collectionMutationsProvider.notifier)
        .deleteNotebook(notebook.id);
    if (!context.mounted) return;

    if (ok) {
      AppSnackbars.success(context, t.get('home.deletedOk'));
    } else {
      final failure = ref.read(collectionMutationsProvider.notifier).lastFailure;
      if (failure != null) {
        AppSnackbars.failure(context, failure);
      } else {
        AppSnackbars.info(context, t.get('error.generic'));
      }
    }
  }

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
      // The router redirect handles navigation back to /auth.
    } catch (error) {
      if (context.mounted) AppSnackbars.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final notebooks = ref.watch(notebooksProvider);
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(t.get('home.title')),
            Text(
              profile == null
                  ? t.get('app.tagline')
                  : '${t.get('settings.profile')}: ${profile.displayName}',
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: t.get('nav.settings'),
            onPressed: () {
              context.push(AppRoutes.settings);
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: t.get('auth.signOut'),
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncStateView<List<Notebook>>(
        value: notebooks,
        onRetry: () =>
            ref.read(notebooksProvider.notifier).reload(),
        emptyBuilder: () => EmptyStateView(
          icon: Icons.folder_off_rounded,
          title: t.get('home.emptyTitle'),
          message: t.get('home.emptyBody'),
          actionLabel: t.get('home.newNotebook'),
          onAction: () => _create(context, ref),
        ),
        builder: (items) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notebooksProvider.notifier).reload(),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      t.get('home.subtitle'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notebook = items[index];
                      return NotebookCard(
                        notebook: notebook,
                        busyDelete: ref
                            .watch(collectionMutationsProvider)
                            .value
                            ?.isBusy(notebook.id, BusyOp.delete) ??
                            false,
                        onTap: () {
                          context.go(
                            AppRoutes.notebook(notebook.id),
                            extra: notebook,
                          );
                        },
                        onRename: () => _rename(context, ref, notebook),
                        onDelete: () => _delete(context, ref, notebook),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(t.get('home.newNotebook')),
      ),
    );
  }
}
