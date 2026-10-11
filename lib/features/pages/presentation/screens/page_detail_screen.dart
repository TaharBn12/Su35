import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/aviation_data.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../core/widgets/app_snack.dart';
import '../../../../core/widgets/async_state_view.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../l10n/l10n.dart';
import '../../application/pages_providers.dart';
import '../../domain/note_page.dart';
import '../widgets/aviation_meta_chips.dart';
import '../widgets/page_form_sheet.dart';
import '../widgets/page_tree_tile.dart';

/// شاشة تفاصيل الصفحة: بيانات الطيران + الصفحات الفرعية + مكان المحرر.
class PageDetailScreen extends ConsumerWidget {
  const PageDetailScreen({super.key, required this.pageId});

  final String pageId;

  Future<void> _reload(WidgetRef ref) {
    ref.invalidate(pageProvider(pageId));
    return ref.read(pageProvider(pageId).future);
  }

  Future<void> _edit(
    BuildContext context,
    NotePage page,
  ) async {
    await showPageFormSheet(
      context,
      notebookId: page.notebookId,
      existing: page,
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    NotePage page,
  ) async {
    final AppL10n l10n = context.l10n;
    try {
      await ref.read(pageActionsProvider).toggleFavorite(page);
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
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    NotePage page,
  ) async {
    final AppL10n l10n = context.l10n;
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
      await ref.read(pageActionsProvider).deletePage(page);
      if (!context.mounted) {
        return;
      }
      showAppSnack(context, l10n.pagesDeleted);
      context.go(AppRoutes.notebookPagesPath(page.notebookId));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppFailureSnack(context, error);
    }
  }

  Future<void> _addSubPage(
    BuildContext context,
    NotePage page,
  ) async {
    await showPageFormSheet(
      context,
      notebookId: page.notebookId,
      parentPageId: page.id,
      parentTitle: page.title,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppL10n l10n = context.l10n;
    final AsyncValue<NotePage> pageState = ref.watch(pageProvider(pageId));
    final NotePage? page = pageState.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          page == null ? l10n.pagesTitle : page.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: <Widget>[
          if (page != null)
            IconButton(
              tooltip: page.isFavorite
                  ? l10n.pagesFavoriteRemove
                  : l10n.pagesFavoriteAdd,
              onPressed: () => _toggleFavorite(context, ref, page),
              icon: Icon(
                page.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: page.isFavorite ? const Color(0xFFF0A02A) : null,
              ),
            ),
          if (page != null)
            IconButton(
              tooltip: l10n.actionEdit,
              onPressed: () => _edit(context, page),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (page != null)
            IconButton(
              tooltip: l10n.actionDelete,
              onPressed: () => _delete(context, ref, page),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          IconButton(
            tooltip: l10n.actionRefresh,
            onPressed: () {
              _reload(ref);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: page == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addSubPage(context, page),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.pagesAddSubPage),
            ),
      body: AsyncStateView<NotePage>(
        value: pageState,
        onRetry: () => _reload(ref),
        builder: (BuildContext context, NotePage data) =>
            _PageDetailBody(page: data),
      ),
    );
  }
}

class _PageDetailBody extends ConsumerWidget {
  const _PageDetailBody({required this.page});

  final NotePage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool isArabic = context.isArabic;

    // الصفحات الفرعية تأتي من قائمة صفحات الدفتر المحمّلة (بلا طلب شبكة إضافي).
    final AsyncValue<List<NotePage>> siblingsState =
        ref.watch(notebookPagesProvider(page.notebookId));
    final List<NotePage> siblings = siblingsState.value ?? const <NotePage>[];
    final List<PageNode> children =
        PageTree.flatten(siblings, rootParentId: page.id);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                page.displayIcon,
                style: const TextStyle(fontSize: 26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    page.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AviationMetaChips(page: page, showEmptyLabel: true),
                ],
              ),
            ),
          ],
        ),
        if ((page.summary ?? '').trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                page.summary!.trim(),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SectionCard(
          title: l10n.pagesMetadataSectionTitle,
          subtitle: l10n.pagesMetadataSectionSubtitle,
          icon: Icons.flight_takeoff_rounded,
          child: Column(
            children: <Widget>[
              _DetailRow(
                icon: Icons.flight_rounded,
                label: l10n.fieldAircraftType,
                value: page.aircraftType,
                fallback: l10n.stateNotSet,
              ),
              _DetailRow(
                icon: Icons.confirmation_number_outlined,
                label: l10n.fieldTailNumber,
                value: page.tailNumber,
                fallback: l10n.stateNotSet,
                ltr: true,
              ),
              _DetailRow(
                icon: Icons.build_outlined,
                label: l10n.fieldAtaChapter,
                value: page.ataChapter == null
                    ? null
                    : AviationData.ataLabel(page.ataChapter, arabic: isArabic),
                fallback: l10n.stateNotSet,
              ),
              _DetailRow(
                icon: Icons.public_rounded,
                label: l10n.fieldAirport,
                value: page.airportIcao,
                fallback: l10n.stateNotSet,
                ltr: true,
              ),
              _DetailRow(
                icon: Icons.event_rounded,
                label: l10n.fieldFlightDate,
                value: page.flightDate == null
                    ? null
                    : AppDate.display(page.flightDate!, arabic: isArabic),
                fallback: l10n.stateNotSet,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: l10n.pagesBodySectionTitle,
          subtitle: l10n.pagesBodyComingTitle,
          icon: Icons.segment_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.pagesBodyComingBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _BlockChip(icon: Icons.notes_rounded, label: l10n.pagesTitle),
                  _BlockChip(icon: Icons.title_rounded, label: 'H1 / H2'),
                  _BlockChip(
                    icon: Icons.checklist_rounded,
                    label: l10n.pagesMetadataSectionTitle,
                  ),
                  _BlockChip(icon: Icons.table_chart_outlined, label: 'Table'),
                  _BlockChip(icon: Icons.image_outlined, label: 'Image'),
                  _BlockChip(icon: Icons.picture_as_pdf_outlined, label: 'PDF'),
                  _BlockChip(icon: Icons.code_rounded, label: 'Code'),
                  _BlockChip(icon: Icons.horizontal_rule_rounded, label: 'Divider'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: l10n.pagesSubPagesTitle,
          subtitle: children.isEmpty
              ? l10n.pagesNoSubPages
              : l10n.pagesCount(children.length),
          icon: Icons.account_tree_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final PageNode node in children) ...<Widget>[
                Padding(
                  padding: EdgeInsetsDirectional.only(start: node.depth * 16.0),
                  child: SubPageTile(
                    page: node.page,
                    onOpen: () =>
                        context.push(AppRoutes.pagePath(node.page.id)),
                    onAddChild: () => showPageFormSheet(
                      context,
                      notebookId: page.notebookId,
                      parentPageId: node.page.id,
                      parentTitle: node.page.title,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                onPressed: () => showPageFormSheet(
                  context,
                  notebookId: page.notebookId,
                  parentPageId: page.id,
                  parentTitle: page.title,
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.pagesAddSubPage),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          <String>[
            if (page.createdAt != null)
              l10n.pagesCreatedAtLabel(
                AppDate.displayWithTime(page.createdAt!, arabic: isArabic),
              ),
            if (page.updatedAt != null)
              l10n.pagesUpdatedAtLabel(
                AppDate.displayWithTime(page.updatedAt!, arabic: isArabic),
              ),
          ].join('\n'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.fallback,
    this.ltr = false,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String fallback;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasValue = (value ?? '').trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              hasValue ? value!.trim() : fallback,
              textDirection: ltr ? TextDirection.ltr : null,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                color: hasValue ? null : theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      labelStyle: theme.textTheme.labelSmall,
      visualDensity: VisualDensity.compact,
    );
  }
}
