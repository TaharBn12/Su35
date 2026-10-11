import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../data/models/notebook.dart';

/// One notebook row: coloured icon tile, name, description and page count.
class NotebookCard extends StatelessWidget {
  const NotebookCard({
    required this.notebook,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
    super.key,
    this.busyDelete = false,
  });

  final Notebook notebook;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool busyDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;
    final accent = Color(notebook.colorValue);
    final l10n = context.l10n;

    final pagesLabel = switch (notebook.pagesCount) {
      0 => t.get('home.noPages'),
      1 => t.get('home.onePage'),
      final n => t.plural('home.pagesCount', n),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busyDelete ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Text(
                  (notebook.icon ?? '✈️').trim().isEmpty
                      ? '✈️'
                      : notebook.icon!.trim(),
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      notebook.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notebook.description?.trim().isNotEmpty == true
                          ? notebook.description!.trim()
                          : '$pagesLabel · ${l10n.timeAgo(notebook.updatedAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (busyDelete)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<_NotebookAction>(
                  tooltip: t.get('generic.edit'),
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) {
                    switch (action) {
                      case _NotebookAction.rename:
                        onRename();
                      case _NotebookAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (menuContext) =>
                      <PopupMenuEntry<_NotebookAction>>[
                    PopupMenuItem<_NotebookAction>(
                      value: _NotebookAction.rename,
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.drive_file_rename_outline_rounded,
                              size: 18),
                          const SizedBox(width: 12),
                          Text(context.t.get('generic.rename')),
                        ],
                      ),
                    ),
                    PopupMenuItem<_NotebookAction>(
                      value: _NotebookAction.delete,
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Theme.of(menuContext).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            menuContext.t.get('generic.delete'),
                            style: TextStyle(
                              color: Theme.of(menuContext).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 2),
              Directionality(
                // Always point "forward" regardless of RTL.
                textDirection: TextDirection.ltr,
                child: Icon(
                  context.isRtl
                      ? Icons.keyboard_arrow_left_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _NotebookAction { rename, delete }
