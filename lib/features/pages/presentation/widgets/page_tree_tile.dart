import 'package:flutter/material.dart';

import '../../../../core/constants/aviation_data.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/note_page.dart';
import 'aviation_meta_chips.dart';

/// إجراءات صفحة في القوائم.
enum PageAction { open, edit, addSubPage, toggleFavorite, delete }

/// صف صفحة في شجرة صفحات الدفتر (مع إزاحة بصرية للصفحات الفرعية).
class PageTreeTile extends StatelessWidget {
  const PageTreeTile({
    super.key,
    required this.node,
    required this.onAction,
  });

  final PageNode node;
  final ValueChanged<PageAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppL10n l10n = context.l10n;
    final NotePage page = node.page;
    final bool isArabic = context.isArabic;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: node.depth * 18.0),
      child: Card(
        child: InkWell(
          onTap: () => onAction(PageAction.open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (node.depth > 0)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6, top: 10),
                    child: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    page.displayIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              page.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (page.isFavorite)
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF0A02A),
                            ),
                        ],
                      ),
                      if ((page.summary ?? '').trim().isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          page.summary!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      AviationMetaChips(page: page, wrap: false),
                      const SizedBox(height: 4),
                      Text(
                        page.updatedAt == null
                            ? ''
                            : l10n.pagesUpdatedAtLabel(
                                AppDate.display(page.updatedAt!, arabic: isArabic),
                              ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<PageAction>(
                  tooltip: l10n.pagesOpenHint,
                  onSelected: onAction,
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<PageAction>>[
                    PopupMenuItem<PageAction>(
                      value: PageAction.open,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.open_in_new_rounded),
                        title: Text(l10n.pagesOpenHint),
                      ),
                    ),
                    PopupMenuItem<PageAction>(
                      value: PageAction.edit,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(l10n.actionEdit),
                      ),
                    ),
                    PopupMenuItem<PageAction>(
                      value: PageAction.addSubPage,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.subdirectory_arrow_right_rounded),
                        title: Text(l10n.pagesAddSubPage),
                      ),
                    ),
                    PopupMenuItem<PageAction>(
                      value: PageAction.toggleFavorite,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          page.isFavorite
                              ? Icons.star_border_rounded
                              : Icons.star_rounded,
                        ),
                        title: Text(
                          page.isFavorite
                              ? l10n.pagesFavoriteRemove
                              : l10n.pagesFavoriteAdd,
                        ),
                      ),
                    ),
                    PopupMenuItem<PageAction>(
                      value: PageAction.delete,
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.delete_outline_rounded,
                          color: theme.colorScheme.error,
                        ),
                        title: Text(
                          l10n.actionDelete,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
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

/// بطاقة صغيرة لصفحة فرعية داخل شاشة تفاصيل الصفحة.
class SubPageTile extends StatelessWidget {
  const SubPageTile({
    super.key,
    required this.page,
    required this.onOpen,
    required this.onAddChild,
  });

  final NotePage page;
  final VoidCallback onOpen;
  final VoidCallback onAddChild;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppL10n l10n = context.l10n;
    return Card(
      child: ListTile(
        onTap: onOpen,
        leading: Text(page.displayIcon, style: const TextStyle(fontSize: 20)),
        title: Text(
          page.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: page.hasAviationDetails
            ? AviationMetaChips(page: page, wrap: false)
            : null,
        trailing: IconButton(
          tooltip: l10n.pagesAddSubPage,
          onPressed: onAddChild,
          icon: const Icon(Icons.add_rounded),
        ),
      ),
    );
  }
}
