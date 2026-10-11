import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/models/page.dart';

/// One row in the notebook's page tree.
///
/// [depth] drives the indentation for nested (sub) pages; [hasChildren] shows
/// the expand/collapse caret.
class PageTile extends StatelessWidget {
  const PageTile({
    required this.page,
    required this.depth,
    required this.onTap,
    required this.onAddChild,
    required this.onRename,
    required this.onDelete,
    super.key,
    this.hasChildren = false,
    this.expanded = false,
    this.onToggleExpand,
    this.busy = false,
  });

  final NotePage page;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onAddChild;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onToggleExpand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    final l10n = context.l10n;
    final chips = page.metadataChips;

    return Padding(
      // Nested pages are indented; RTL handled by paddingDirectional.
      padding: EdgeInsetsDirectional.only(start: depth * 16.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
            child: Row(
              children: <Widget>[
                if (hasChildren)
                  IconButton(
                    tooltip: expanded
                        ? t.get('generic.close')
                        : t.get('pages.subPages'),
                    visualDensity: VisualDensity.compact,
                    onPressed: (busy || onToggleExpand == null)
                        ? null
                        : onToggleExpand,
                    icon: Icon(
                      expanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 22,
                    ),
                  )
                else
                  const SizedBox(width: 40),
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    (page.icon ?? AppConstants.defaultPageIcon).trim().isEmpty
                        ? AppConstants.defaultPageIcon
                        : page.icon!.trim(),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        page.title.trim().isEmpty
                            ? t.get('pages.untitled')
                            : page.title.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            l10n.timeAgo(page.updatedAt),
                            style: theme.textTheme.labelSmall,
                          ),
                          if (page.templateKey != null)
                            _MetaChip(
                              label: t.get('template.${page.templateKey}'),
                              icon: Icons.auto_awesome_rounded,
                            ),
                          ...chips.map(
                            (chip) => _MetaChip(label: chip),
                          ),
                          if (hasChildren)
                            _MetaChip(
                              label: '${t.get('pages.subPages')}: ${page.childCount}',
                              icon: Icons.account_tree_outlined,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  PopupMenuButton<_PageAction>(
                    tooltip: t.get('generic.edit'),
                    icon: const Icon(Icons.more_horiz_rounded),
                    onSelected: (action) {
                      switch (action) {
                        case _PageAction.open:
                          onTap();
                        case _PageAction.addChild:
                          onAddChild();
                        case _PageAction.rename:
                          onRename();
                        case _PageAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (menuContext) =>
                        <PopupMenuEntry<_PageAction>>[
                      PopupMenuItem<_PageAction>(
                        value: _PageAction.open,
                        child: _MenuRow(
                          icon: Icons.open_in_new_rounded,
                          label: menuContext.t.get('pages.openPage'),
                        ),
                      ),
                      PopupMenuItem<_PageAction>(
                        value: _PageAction.addChild,
                        child: _MenuRow(
                          icon: Icons.playlist_add_rounded,
                          label: menuContext.t.get('pages.newSubPage'),
                        ),
                      ),
                      PopupMenuItem<_PageAction>(
                        value: _PageAction.rename,
                        child: _MenuRow(
                          icon: Icons.drive_file_rename_outline_rounded,
                          label: menuContext.t.get('generic.rename'),
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<_PageAction>(
                        value: _PageAction.delete,
                        child: _MenuRow(
                          icon: Icons.delete_outline_rounded,
                          label: menuContext.t.get('generic.delete'),
                          destructive: true,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? theme.colorScheme.error : null;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

enum _PageAction { open, addChild, rename, delete }
