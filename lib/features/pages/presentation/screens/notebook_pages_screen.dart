import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/aviation_data.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/l10n.dart';
import '../../../notebooks/application/notebooks_controller.dart';
import '../../../notebooks/domain/notebook.dart';
import '../../application/pages_providers.dart';
import '../../domain/note_page.dart';
import '../widgets/page_form_sheet.dart';
import '../widgets/page_tree_tile.dart';

/// قائمة صفحات دفتر معيّن (شجرة متداخلة).
class NotebookPagesScreen extends ConsumerWidget {
  const NotebookPagesScreen({super.key, required this.notebookId});

  final String notebookId;

  Future<void> _refresh(WidgetRef ref) {
    ref.invalidate(notebookPagesProvider(notebookId));
    return ref.read(notebookPagesProvider(notebookId).future);
  }

  Future<void> _createPage(
    BuildContext context,
    WidgetRef ref, {
    String? parentPageId,
    String? parentTitle,
  }) async {
    await showPageFormSheet(
      context,
      notebookId: notebookId,
      parentPageId: parentPageId,
      parentTitle: parentTitle,
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    NotePage page,
    PageAction action,
  ) async {
    final AppL10n l10n = context.l10n;
    final PageActions actions = ref.read(pageActionsProvider);

    if (action == PageAction.open) {
      context.push(AppRoutes.pagePath(page.id));
      return;
    }

    if (action == PageAction.edit) {
      await showPageFormSheet(
        context,
        notebookId: notebookId,
        existing: page,
      );
      return;
    }

    if (action == PageAction.addSubPage) {
      await _createPage(
        context,
        ref,
        parentPageId: page.id,
        parentTitle: page.title,
      );
      return;
    }

    if (action == PageAction.toggleFavorite) {
      try {
        await actions.toggleFavorite(page);
        if (!context.mounted) {
          return;
        }
        showAppSnack(
          context,
          page.isFavorite ? l10n.pagesUnfavorited : l10n.pagesFavorited,
        );
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        showAppFailureSnack(context, error);
      }
      return;
    }

    if (action == PageAction.delete) {
      final bool confirmed = await showConfirmDialog(
        context,
        title: l10n.actionDelete,
        body: l10n.pagesDeleteConfirmBody,
        icon: Icons.delete_outline_rounded,
      );
      if (!confirmed || !context.mounted) {
        return;
      }
      try {
        await actions.deletePage(page);
        if (!context.mounted) {
          return;
        }
        showAppSnack(context, l10n.pagesDeleted);
      } catch (error) {
        if (!context.mounted) {
          return;
        }
        showAppFailureSnack(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final Notebook? notebook = ref.watch(notebookByIdProvider(notebookId));
    final AsyncValue<List<NotePage>> pagesState =
        ref.watch(notebookPagesProvider(notebookId));

    final List<NotePage> pages = pagesState.value ?? const <NotePage>[];
    final List<PageNode> nodes = PageTree.flatten(pages);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              notebook == null
                  ? l10n.pagesTitle
                  : '${notebook.displayIcon}  ${notebook.title}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              l10n.pagesCount(pages.length),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.actionRefresh,
            onPressed: () {
              _refresh(ref);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _createPage(context, ref);
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.pagesNewTitle),
      ),
      body: AsyncStateView<List<NotePage>>(
        value: pagesState,
        onRetry: () => _refresh(ref),
        isEmpty: (List<NotePage> data) => data.isEmpty,
        emptyBuilder: (BuildContext context) => AppEmptyView(
          icon: Icons.description_outlined,
          title: l10n.pagesEmptyTitle,
          body: l10n.pagesEmptyBody,
          actionLabel: l10n.pagesEmptyCta,
          onAction: () {
            _createPage(context, ref);
          },
        ),
        builder: (BuildContext context, List<NotePage> data) {
          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: nodes.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int index) {
                final PageNode node = nodes[index];
                return PageTreeTile(
                  node: node,
                  onAction: (PageAction action) {
                    _handleAction(context, ref, node.page, action);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// شريط معلومات علوي يُستخدم في شاشة التفاصيل (اختصار بصري).
class NotebookHeaderChip extends StatelessWidget {
  const NotebookHeaderChip({
    super.key,
    required this.notebook,
  });

  final Notebook notebook;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AviationData.colorFromHex(notebook.color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(notebook.displayIcon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            notebook.title,
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
