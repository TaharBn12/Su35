import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/block_content.dart';
import 'auto_saving_text_field.dart';

/// كتلة «قائمة تحقّق» — بنود بعلامة إنجاز وشريط تقدّم.
class ChecklistBlockField extends StatelessWidget {
  const ChecklistBlockField({
    super.key,
    required this.data,
    required this.onChanged,
  });

  final ChecklistData data;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<ChecklistItem> items = data.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < items.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Checkbox(
                  value: items[index].checked,
                  visualDensity: VisualDensity.compact,
                  onChanged: (bool? checked) => onChanged(
                    data
                        .updateItem(items[index].id, checked: checked ?? false)
                        .toJson(),
                  ),
                ),
                Expanded(
                  child: AutoSavingTextField(
                    value: items[index].text,
                    hintText: l10n.blockChecklistItemHint,
                    filled: false,
                    textStyle: theme.textTheme.bodyLarge!.copyWith(
                      height: 1.4,
                      decoration: items[index].checked
                          ? TextDecoration.lineThrough
                          : null,
                      color: items[index].checked
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                    ),
                    onChanged: (String value) => onChanged(
                      data.updateItem(items[index].id, text: value).toJson(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.actionDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: items.length <= 1
                      ? null
                      : () => onChanged(data.removeItem(items[index].id).toJson()),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(l10n.blockChecklistAddItem),
              onPressed: () => onChanged(data.addItem().toJson()),
            ),
            const Spacer(),
            if (items.isNotEmpty)
              Text(
                l10n.blockChecklistProgress(data.doneCount, data.total),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        if (items.isNotEmpty) ...<Widget>[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: data.progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );
  }
}
