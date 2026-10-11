import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/data_providers.dart';
import '../../../data/models/page.dart';
import '../../../data/models/page_block.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/app_snackbars.dart';
import '../../../shared/widgets/async_state_view.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../widgets/page_dialogs.dart';
import 'pages_screen.dart' show PageViewerArgs;

/// Read-only page view for Stage A.
///
/// It renders the page metadata (aircraft type, registration, ATA chapter,
/// ICAO, date) and the text blocks that the template triggers seeded, so a
/// freshly created "Pre-flight Checklist" already looks like something. The
/// full block editor (rich text, checklists you can tick, tables, images, PDF
/// attachments) replaces this screen in Stage B.
class PageViewerScreen extends ConsumerWidget {
  const PageViewerScreen({
    required this.pageId,
    super.key,
    this.notebookId,
    this.initialPage,
  });

  final String pageId;
  final String? notebookId;
  final NotePage? initialPage;

  Future<void> _createSubPage(
    BuildContext context,
    WidgetRef ref,
    NotePage parent,
    String notebookId,
  ) async {
    final created = await createPageFromSheet(
      context,
      ref,
      notebookId: notebookId,
      parentPageId: parent.id,
      parentPageTitle: parent.title,
    );
    if (created != null && context.mounted) {
      ref.invalidate(notebookPagesProvider(notebookId));
      ref.invalidate(pageProvider(parent.id));
      context.push(
        AppRoutes.pageViewer(created.id, notebookId),
        extra: PageViewerArgs(notebookId: notebookId, page: created),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    NotePage page,
    String notebookId,
  ) async {
    final t = context.t;
    final confirmed = await showConfirmDialog(
      context,
      title: t.get('pages.deletePage'),
      message: t.get('pages.deletePageConfirm').replaceFirst(
            '{name}',
            page.title.trim().isEmpty ? t.get('pages.untitled') : page.title,
          ),
    );
    if (!confirmed || !context.mounted) return;

    final ok = await ref
        .read(collectionMutationsProvider.notifier)
        .deletePage(page.id, notebookId: notebookId);
    if (!context.mounted) return;

    if (ok) {
      context.pop();
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final pageAsync = ref.watch(pageProvider(pageId));
    final blocksAsync = ref.watch(pageBlocksProvider(pageId));
    final busy = ref.watch(collectionMutationsProvider).value;

    // Fall back to the page object handed over by the list screen while the
    // network request is in flight (instant paint, no skeleton flash).
    final page = pageAsync.value ?? initialPage;
    final resolvedNotebookId =
        notebookId ?? page?.notebookId ?? initialPage?.notebookId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          page == null || page.title.trim().isEmpty
              ? t.get('pages.untitled')
              : page.title.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          if (page != null)
            IconButton(
              tooltip: t.get('generic.edit'),
              onPressed: (busy?.isBusy(page.id, BusyOp.delete) ?? false)
                  ? null
                  : () async {
                      final updated =
                          await editPageMetadataFromSheet(context, ref, page);
                      if (updated != null && context.mounted) {
                        ref.invalidate(pageProvider(pageId));
                      }
                    },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (page != null && resolvedNotebookId != null)
            IconButton(
              tooltip: t.get('generic.delete'),
              onPressed: () =>
                  _delete(context, ref, page, resolvedNotebookId),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: AsyncStateView<NotePage>(
        value: pageAsync,
        onRetry: () => ref.invalidate(pageProvider(pageId)),
        builder: (currentPage) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pageProvider(pageId));
              ref.invalidate(pageBlocksProvider(pageId));
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
              children: <Widget>[
                _PageHeader(page: currentPage),
                const SizedBox(height: 16),
                _StageBanner(
                  icon: Icons.construction_rounded,
                  text: t.get('pages.viewerBanner'),
                ),
                const SizedBox(height: 18),
                AsyncStateView<List<PageBlock>>(
                  value: blocksAsync,
                  onRetry: () => ref.invalidate(pageBlocksProvider(pageId)),
                  emptyBuilder: () => EmptyStateView(
                    icon: Icons.edit_note_rounded,
                    title: t.get('pages.noContent'),
                    message: t.get('pages.viewerBanner'),
                  ),
                  builder: (blocks) => _BlockList(blocks: blocks),
                ),
                const SizedBox(height: 24),
                Text(
                  '${t.get('pages.createdAt')}: '
                  '${l10n.formatDateTime(currentPage.createdAt)}',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${t.get('pages.updatedAt')}: '
                  '${l10n.formatDateTime(currentPage.updatedAt)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
          page == null || resolvedNotebookId == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _createSubPage(
                    context,
                    ref,
                    page,
                    resolvedNotebookId,
                  ),
                  icon: const Icon(Icons.subdirectory_arrow_right_rounded),
                  label: Text(t.get('pages.newSubPage')),
                ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.page});

  final NotePage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    final l10n = context.l10n;

    final rows = <_HeaderRow>[
      if (page.templateKey != null)
        _HeaderRow(
          icon: Icons.auto_awesome_rounded,
          label: t.get('pages.template'),
          value: t.get('template.${page.templateKey}'),
        ),
      if (page.aircraftType != null)
        _HeaderRow(
          icon: Icons.flight_rounded,
          label: t.get('pages.aircraftType'),
          value: page.aircraftType!,
        ),
      if (page.registration != null)
        _HeaderRow(
          icon: Icons.confirmation_number_outlined,
          label: t.get('pages.registration'),
          value: page.registration!,
          monospace: true,
        ),
      if (page.ataChapter != null)
        _HeaderRow(
          icon: Icons.category_outlined,
          label: t.get('pages.ataChapter'),
          value: 'ATA ${page.ataChapter} · ${AtaChapters.label(page.ataChapter!)}',
        ),
      if (page.departureIcao != null || page.arrivalIcao != null)
        _HeaderRow(
          icon: Icons.alt_route_rounded,
          label: '${t.get('pages.departure')} → ${t.get('pages.arrival')}',
          value:
              '${page.departureIcao ?? '—'} → ${page.arrivalIcao ?? '—'}',
          monospace: true,
        ),
      if (page.airportIcao != null)
        _HeaderRow(
          icon: Icons.location_on_outlined,
          label: t.get('pages.airport'),
          value: page.airportIcao!,
          monospace: true,
        ),
      if (page.flightDate != null)
        _HeaderRow(
          icon: Icons.event_rounded,
          label: t.get('pages.flightDate'),
          value: l10n.formatDate(page.flightDate),
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  (page.icon ?? AppConstants.defaultPageIcon).trim(),
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    page.title.trim().isEmpty
                        ? t.get('pages.untitled')
                        : page.title.trim(),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            if (page.summary != null && page.summary!.trim().isNotEmpty) ...<
                Widget>[
              const SizedBox(height: 10),
              Text(
                page.summary!.trim(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (rows.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 6),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: row,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 17, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Text(label, style: theme.textTheme.labelMedium),
        ),
        Expanded(
          flex: 3,
          child: Directionality(
            // Registrations, ICAO codes and ATA chapters always read LTR.
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
                letterSpacing: monospace ? 0.6 : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StageBanner extends StatelessWidget {
  const _StageBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: theme.colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Minimal read-only renderer for the block types seeded by the templates.
class _BlockList extends StatelessWidget {
  const _BlockList({required this.blocks});

  final List<PageBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks.map((block) {
        switch (block.type) {
          case BlockTypes.heading1:
            return Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text(
                block.content ?? '',
                style: theme.textTheme.titleLarge,
              ),
            );
          case BlockTypes.heading2:
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                block.content ?? '',
                style: theme.textTheme.titleMedium,
              ),
            );
          case BlockTypes.heading3:
            return Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Text(
                block.content ?? '',
                style: theme.textTheme.titleSmall,
              ),
            );
          case BlockTypes.checklist:
            return _ChecklistRow(block: block);
          case BlockTypes.bulletList:
            return _BulletRow(block: block, ordered: false);
          case BlockTypes.numberedList:
            return _BulletRow(block: block, ordered: true);
          case BlockTypes.divider:
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            );
          case BlockTypes.code:
            return _CodeRow(block: block);
          case BlockTypes.callout:
            return _CalloutRow(block: block);
          default:
            if (!block.isTextual) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                block.content ?? '',
                style: theme.textTheme.bodyLarge,
              ),
            );
        }
      }).toList(growable: false),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.block});

  final PageBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checked = block.isChecked ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            checked
                ? Icons.check_box_rounded
                : Icons.check_box_outline_blank_rounded,
            size: 20,
            color: checked
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              block.content ?? '',
              style: theme.textTheme.bodyLarge?.copyWith(
                decoration: checked ? TextDecoration.lineThrough : null,
                color: checked
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.block, required this.ordered});

  final PageBlock block;
  final bool ordered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 24,
            child: Text(
              ordered ? '${block.position + 1}.' : '•',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(block.content ?? '', style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.block});

  final PageBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (block.language != null)
            Text(
              block.language!.toUpperCase(),
              style: theme.textTheme.labelSmall,
            ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              block.content ?? '',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalloutRow extends StatelessWidget {
  const _CalloutRow({required this.block});

  final PageBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline_rounded, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(block.content ?? '', style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
