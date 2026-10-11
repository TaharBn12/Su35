import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/notebook.dart';
import '../../../data/models/page.dart';
import '../../../router/app_router.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_snackbars.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../widgets/page_dialogs.dart';
import '../widgets/page_tile.dart';

/// A page plus its depth in the tree, after flattening.
class _FlatPage {
  const _FlatPage(this.page, this.depth, this.hasChildren, this.expanded);

  final NotePage page;
  final int depth;
  final bool hasChildren;
  final bool expanded;
}

/// All pages of one notebook, rendered as a collapsible tree.
class PagesScreen extends ConsumerStatefulWidget {
  const PagesScreen({required this.notebookId, super.key, this.notebook});

  final String notebookId;

  /// Passed through `extra` for an instant title (the list is refetched
  /// anyway, so a stale copy is harmless).
  final Notebook? notebook;

  @override
  ConsumerState<PagesScreen> createState() => _PagesScreenState();
}

class _PagesScreenState extends ConsumerState<PagesScreen> {
  /// Page ids the user expanded (collapsed by default for a clean tree).
  final Set<String> _expanded = <String>{};

  Notebook? get _notebook {
    final fromExtra = widget.notebook;
    final notebooks = ref.watch(notebooksProvider).value;
    if (notebooks != null) {
      for (final notebook in notebooks) {
        if (notebook.id == widget.notebookId) return notebook;
      }
    }
    return fromExtra;
  }

  Future<void> _createPage({NotePage? parent}) async {
    final created = await createPageFromSheet(
      context,
      ref,
      notebookId: widget.notebookId,
      parentPageId: parent?.id,
      parentPageTitle: parent?.title,
    );
    if (created != null && parent != null && mounted) {
      setState(() => _expanded.add(parent.id));
    }
  }

  Future<void> _rename(NotePage page) async {
    await renamePageFromSheet(context, ref, page);
  }

  Future<void> _delete(NotePage page) async {
    final t = context.t;
    final confirmed = await showConfirmDialog(
      context,
      title: t.get('pages.deletePage'),
      message: t
          .get('pages.deletePageConfirm')
          .replaceFirst('{name}', page.title.trim().isEmpty ? t.get('pages.untitled') : page.title.trim()),
    );
    if (!confirmed || !context.mounted) return;

    final ok = await ref
        .read(collectionMutationsProvider.notifier)
        .deletePage(page.id, notebookId: widget.notebookId);

    if (!context.mounted) return;
    if (ok) {
      AppSnackbars.success(context, t.get('pages.deletedOk'));
      setState(() => _expanded.remove(page.id));
    } else {
      final failure =
          ref.read(collectionMutationsProvider.notifier).lastFailure;
      if (failure != null) {
        AppSnackbars.failure(context, failure);
      } else {
        AppSnackbars.info(context, t.get('error.generic'));
      }
    }
  }

  void _open(NotePage page) {
    context.push(
      AppRoutes.pageViewer(page.id, widget.notebookId),
      extra: PageViewerArgs(notebookId: widget.notebookId, page: page),
    );
  }

  List<_FlatPage> _flatten(List<NotePage> pages) {
    final byParent = <String?, List<NotePage>>{};
    for (final page in pages) {
      byParent.putIfAbsent(page.parentPageId, () => <NotePage>[]).add(page);
    }
    for (final siblings in byParent.values) {
      siblings.sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        if (byPosition != 0) return byPosition;
        return a.createdAt.compareTo(b.createdAt);
      });
    }

    final result = <_FlatPage>[];

    void walk(String? parentId, int depth) {
      if (depth > AppConstants.maxPageDepth) return;
      final children = byParent[parentId] ?? const <NotePage>[];
      for (final child in children) {
        final grandchildren = byParent[child.id] ?? const <NotePage>[];
        final hasChildren = grandchildren.isNotEmpty;
        final expanded = _expanded.contains(child.id);
        result.add(_FlatPage(child, depth, hasChildren, expanded));
        if (hasChildren && expanded) walk(child.id, depth + 1);
      }
    }

    walk(null, 0);

    // Orphans (their parent is archived or filtered out) are shown at the root
    // so nothing ever disappears silently.
    final seen = result.map((item) => item.page.id).toSet();
    for (final page in pages) {
      if (!seen.contains(page.id)) {
        result.add(_FlatPage(page, 0, false, false));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = Theme.of(context);
    final pages = ref.watch(notebookPagesProvider(widget.notebookId));
    final busy = ref.watch(collectionMutationsProvider).value;
    final notebook = _notebook;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              notebook == null
                  ? t.get('pages.title')
                  : '${notebook.icon ?? '✈️'}  ${notebook.name}',
            ),
            Text(
              t.get('pages.title'),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: t.get('generic.retry'),
            onPressed: () => ref
                .read(notebookPagesProvider(widget.notebookId).notifier)
                .reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: t.get('nav.settings'),
            onPressed: () {
              context.push(AppRoutes.settings);
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncStateView<List<NotePage>>(
        value: pages,
        onRetry: () => ref
            .read(notebookPagesProvider(widget.notebookId).notifier)
            .reload(),
        emptyBuilder: () => EmptyStateView(
          icon: Icons.notes_rounded,
          title: t.get('pages.emptyTitle'),
          message: t.get('pages.emptyBody'),
          actionLabel: t.get('pages.newPage'),
          onAction: () => _createPage(),
        ),
        builder: (items) {
          final flat = _flatten(items);
          return RefreshIndicator(
            onRefresh: () => ref
                .read(notebookPagesProvider(widget.notebookId).notifier)
                .reload(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
              itemCount: flat.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = flat[index];
                final page = item.page;
                return PageTile(
                  page: page,
                  depth: item.depth,
                  hasChildren: item.hasChildren,
                  expanded: item.expanded,
                  busy: busy?.isBusy(page.id, BusyOp.delete) ?? false,
                  onToggleExpand: () {
                    setState(() {
                      if (!_expanded.remove(page.id)) _expanded.add(page.id);
                    });
                  },
                  onTap: () => _open(page),
                  onAddChild: () => _createPage(parent: page),
                  onRename: () => _rename(page),
                  onDelete: () => _delete(page),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createPage(),
        icon: const Icon(Icons.add_rounded),
        label: Text(t.get('pages.newPage')),
      ),
    );
  }
}

/// Payload passed through `extra` to the page viewer so it can render
/// immediately while the fresh copy loads.
class PageViewerArgs {
  const PageViewerArgs({required this.notebookId, required this.page});

  final String notebookId;
  final NotePage page;
}
