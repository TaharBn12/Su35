import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/failures/app_failure.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/l10n.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/domain/app_user.dart';
import '../../application/notebooks_controller.dart';
import '../../domain/notebook.dart';
import '../widgets/notebook_card.dart';
import '../widgets/notebook_form_sheet.dart';

/// الشاشة الرئيسية: كل دفاتر المستخدم.
class NotebooksScreen extends ConsumerStatefulWidget {
  const NotebooksScreen({super.key});

  @override
  ConsumerState<NotebooksScreen> createState() => _NotebooksScreenState();
}

class _NotebooksScreenState extends ConsumerState<NotebooksScreen> {
  bool _showArchived = false;

  Future<void> _reload() =>
      ref.read(notebooksControllerProvider.notifier).reload();

  Future<void> _openCreateSheet() async {
    await showNotebookFormSheet(context);
  }

  Future<void> _handleAction(Notebook notebook, NotebookAction action) async {
    final AppL10n l10n = context.l10n;
    final NotebooksController controller =
        ref.read(notebooksControllerProvider.notifier);

    if (action == NotebookAction.edit) {
      await showNotebookFormSheet(context, existing: notebook);
      return;
    }

    if (action == NotebookAction.toggleFavorite) {
      try {
        await controller.toggleFavorite(notebook);
        if (!mounted) {
          return;
        }
        showAppSnack(
          context,
          notebook.isFavorite ? l10n.pagesUnfavorited : l10n.pagesFavorited,
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        showAppFailureSnack(context, error);
      }
      return;
    }

    if (action == NotebookAction.toggleArchive) {
      try {
        await controller.setArchived(notebook, !notebook.isArchived);
        if (!mounted) {
          return;
        }
        showAppSnack(
          context,
          notebook.isArchived
              ? l10n.notebooksUnarchiveAction
              : l10n.notebooksArchiveAction,
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        showAppFailureSnack(context, error);
      }
      return;
    }

    if (action == NotebookAction.delete) {
      final bool confirmed = await showConfirmDialog(
        context,
        title: l10n.actionDelete,
        body: l10n.notebooksDeleteConfirmBody,
        icon: Icons.delete_outline_rounded,
      );
      if (!confirmed || !mounted) {
        return;
      }
      try {
        await controller.delete(notebook.id);
        if (!mounted) {
          return;
        }
        showAppSnack(context, l10n.notebooksDeleted);
      } catch (error) {
        if (!mounted) {
          return;
        }
        showAppFailureSnack(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<Notebook>> notebooksState =
        ref.watch(notebooksControllerProvider);
    final AppUser? user = ref.watch(currentUserProvider);
    final AppFailure? profileFailure =
        ref.watch(authControllerProvider).failure;

    final List<Notebook> all = notebooksState.value ?? const <Notebook>[];
    final List<Notebook> visible = all
        .where((Notebook notebook) =>
            _showArchived ? true : !notebook.isArchived)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              user == null
                  ? l10n.notebooksTitle
                  : l10n.authWelcomeMessage(user.displayLabel),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              l10n.notebooksSubtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.notebooksShowArchived,
            onPressed: () =>
                setState(() => _showArchived = !_showArchived),
            icon: Icon(
              _showArchived
                  ? Icons.inventory_2_rounded
                  : Icons.inventory_2_outlined,
            ),
          ),
          IconButton(
            tooltip: l10n.actionRefresh,
            onPressed: () {
              _reload();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: l10n.settingsTitle,
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openCreateSheet();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.notebooksNewTitle),
      ),
      body: Column(
        children: <Widget>[
          if (profileFailure != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppInlineErrorCard(
                failure: profileFailure,
                onRetry: () =>
                    ref.read(authControllerProvider.notifier).refreshProfile(),
              ),
            ),
          Expanded(
            child: AsyncStateView<List<Notebook>>(
              value: notebooksState,
              onRetry: _reload,
              isEmpty: (List<Notebook> _) => visible.isEmpty,
              emptyBuilder: (BuildContext context) => AppEmptyView(
                icon: Icons.menu_book_rounded,
                title: l10n.notebooksEmptyTitle,
                body: l10n.notebooksEmptyBody,
                actionLabel: l10n.notebooksEmptyCta,
                onAction: () {
                  _openCreateSheet();
                },
              ),
              builder: (BuildContext context, List<Notebook> data) {
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: visible.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final Notebook notebook = visible[index];
                      return NotebookCard(
                        notebook: notebook,
                        onTap: () => context.push(
                          AppRoutes.notebookPagesPath(notebook.id),
                        ),
                        onAction: (NotebookAction action) {
                          _handleAction(notebook, action);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
