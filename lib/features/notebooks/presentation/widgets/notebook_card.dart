import 'package:flutter/material.dart';

import '../../../../core/constants/aviation_data.dart';
import '../../../../core/utils/app_date.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/notebook.dart';

/// إجراءات بطاقة الدفتر (تُنفَّذ في الشاشة).
enum NotebookAction { edit, toggleFavorite, toggleArchive, delete }

/// بطاقة دفتر واحدة في الصفحة الرئيسية.
class NotebookCard extends StatelessWidget {
  const NotebookCard({
    super.key,
    required this.notebook,
    required this.onTap,
    required this.onAction,
  });

  final Notebook notebook;
  final VoidCallback onTap;
  final ValueChanged<NotebookAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppL10n l10n = context.l10n;
    final bool isArabic = context.isArabic;
    final Color accent = AviationData.colorFromHex(notebook.color);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  notebook.displayIcon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            notebook.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (notebook.isFavorite)
                          const Icon(
                            Icons.star_rounded,
                            size: 18,
                            color: Color(0xFFF0A02A),
                          ),
                      ],
                    ),
                    if ((notebook.description ?? '').trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        notebook.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _MetaChip(
                          icon: Icons.description_outlined,
                          label: l10n.notebooksPagesCount(notebook.pagesCount),
                        ),
                        if ((notebook.aircraftType ?? '').trim().isNotEmpty)
                          _MetaChip(
                            icon: Icons.flight_rounded,
                            label: notebook.aircraftType!.trim(),
                          ),
                        if (notebook.lastPageUpdate != null)
                          _MetaChip(
                            icon: Icons.schedule_rounded,
                            label: AppDate.display(
                              notebook.lastPageUpdate!,
                              arabic: isArabic,
                            ),
                          ),
                        if (notebook.isArchived)
                          _MetaChip(
                            icon: Icons.inventory_2_outlined,
                            label: l10n.notebooksArchivedBadge,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<NotebookAction>(
                tooltip: l10n.actionEdit,
                onSelected: onAction,
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<NotebookAction>>[
                  PopupMenuItem<NotebookAction>(
                    value: NotebookAction.edit,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_outlined),
                      title: Text(l10n.actionEdit),
                    ),
                  ),
                  PopupMenuItem<NotebookAction>(
                    value: NotebookAction.toggleFavorite,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        notebook.isFavorite
                            ? Icons.star_border_rounded
                            : Icons.star_rounded,
                      ),
                      title: Text(
                        notebook.isFavorite
                            ? l10n.pagesFavoriteRemove
                            : l10n.pagesFavoriteAdd,
                      ),
                    ),
                  ),
                  PopupMenuItem<NotebookAction>(
                    value: NotebookAction.toggleArchive,
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(
                        notebook.isArchived
                            ? l10n.notebooksUnarchiveAction
                            : l10n.notebooksArchiveAction,
                      ),
                    ),
                  ),
                  PopupMenuItem<NotebookAction>(
                    value: NotebookAction.delete,
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
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
