import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/block_content.dart';
import 'auto_saving_text_field.dart';

/// كتلة «جدول» — أعمدة وصفوف قابلة للتحرير مباشرة مع إضافة/حذف صفوف وأعمدة.
class TableBlockField extends StatelessWidget {
  const TableBlockField({
    super.key,
    required this.data,
    required this.onChanged,
  });

  final TableData data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  static const double _cellWidth = 132;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final int columns = data.columns.isEmpty ? 1 : data.columns.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.blockTypeTable,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _TableMenu(
              l10n: l10n,
              onAddRow: () => onChanged(data.addRow().toJson()),
              onAddColumn: () => onChanged(data.addColumn().toJson()),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // صف العناوين
              Row(
                children: <Widget>[
                  for (int column = 0; column < columns; column++)
                    _cell(
                      context,
                      width: _cellWidth,
                      child: Stack(
                        alignment: AlignmentDirectional.centerEnd,
                        children: <Widget>[
                          AutoSavingTextField(
                            value: data.columns[column],
                            hintText: l10n.blockTableHeaderHint,
                            filled: false,
                            isDense: true,
                            textStyle: theme.textTheme.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            onChanged: (String value) =>
                                onChanged(data.setColumn(column, value).toJson()),
                          ),
                          if (columns > 1)
                            IconButton(
                              tooltip: l10n.blockTableDeleteColumn,
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.remove_circle_outline, size: 16),
                              onPressed: () => onChanged(
                                data.removeColumn(column).toJson(),
                              ),
                            ),
                        ],
                      ),
                      background: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                    ),
                ],
              ),
              // صفوف البيانات
              for (int row = 0; row < data.rows.length; row++)
                Row(
                  children: <Widget>[
                    for (int column = 0; column < columns; column++)
                      _cell(
                        context,
                        width: _cellWidth,
                        child: Stack(
                          alignment: AlignmentDirectional.centerEnd,
                          children: <Widget>[
                            AutoSavingTextField(
                              value: column < data.rows[row].length
                                  ? data.rows[row][column]
                                  : '',
                              hintText: l10n.blockTableCellHint,
                              filled: false,
                              isDense: true,
                              maxLines: 3,
                              onChanged: (String value) => onChanged(
                                data.setCell(row, column, value).toJson(),
                              ),
                            ),
                            if (data.rows.length > 1)
                              IconButton(
                                tooltip: l10n.blockTableDeleteRow,
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.remove_circle_outline, size: 16),
                                onPressed: () =>
                                    onChanged(data.removeRow(row).toJson()),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              Row(
                children: <Widget>[
                  for (int column = 0; column < columns; column++)
                    _cell(
                      context,
                      width: _cellWidth,
                      background: Colors.transparent,
                      child: const SizedBox.shrink(),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.blockTableAddRow),
              onPressed: () => onChanged(data.addRow().toJson()),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              icon: const Icon(Icons.view_column_outlined, size: 18),
              label: Text(l10n.blockTableAddColumn),
              onPressed: () => onChanged(data.addColumn().toJson()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cell(
    BuildContext context, {
    required double width,
    required Widget child,
    Color? background,
  }) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.7),
      ),
      child: child,
    );
  }
}

class _TableMenu extends StatelessWidget {
  const _TableMenu({
    required this.l10n,
    required this.onAddRow,
    required this.onAddColumn,
  });

  final AppL10n l10n;
  final VoidCallback onAddRow;
  final VoidCallback onAddColumn;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: l10n.blockMenuTooltip,
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
      onSelected: (String value) {
        if (value == 'row') {
          onAddRow();
        } else if (value == 'column') {
          onAddColumn();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'row',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_rounded, size: 18),
            title: Text(l10n.blockTableAddRow),
          ),
        ),
        PopupMenuItem<String>(
          value: 'column',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.view_column_outlined, size: 18),
            title: Text(l10n.blockTableAddColumn),
          ),
        ),
      ],
    );
  }
}
