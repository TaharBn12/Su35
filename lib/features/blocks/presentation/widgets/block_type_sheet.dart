import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/block.dart';
import 'block_style.dart';

/// يفتح ورقة اختيار نوع الكتلة (للإضافة أو لتغيير نوع كتلة قائمة).
/// تُعيد النوع المختار أو null إن أُغلقت الورقة.
Future<BlockType?> showBlockTypeSheet(
  BuildContext context, {
  String? title,
  BlockType? current,
}) {
  return showModalBottomSheet<BlockType>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext sheetContext) =>
        BlockTypeSheet(title: title, current: current),
  );
}

/// ورقة اختيار نوع الكتلة، مقسّمة إلى مجموعات (أساسية / مرفقات / متقدمة).
class BlockTypeSheet extends StatelessWidget {
  const BlockTypeSheet({super.key, this.title, this.current});

  final String? title;
  final BlockType? current;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title ?? l10n.blockTypeSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final BlockTypeGroup group in BlockTypeGroup.values) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                group.label(l10n),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final BlockType type in group.types)
                    _BlockTypeChip(
                      type: type,
                      selected: type == current,
                      onTap: () => Navigator.of(context).pop(type),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BlockTypeChip extends StatelessWidget {
  const _BlockTypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final BlockType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppL10n l10n = context.l10n;
    final Color color = blockTypeColor(type);
    return ActionChip(
      avatar: Icon(
        type.icon,
        size: 18,
        color: selected ? color : color.withValues(alpha: 0.85),
      ),
      label: Text(blockTypeLabel(type, l10n)),
      onPressed: onTap,
      backgroundColor: selected ? color.withValues(alpha: 0.16) : null,
      side: selected ? BorderSide(color: color, width: 1.4) : null,
    );
  }
}

/// ورقة اختيار المستوى للعناوين (1..3).
Future<int?> showHeadingLevelSheet(BuildContext context, int current) {
  return showModalBottomSheet<int>(
    context: context,
    builder: (BuildContext sheetContext) {
      final AppL10n l10n = sheetContext.l10n;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.blockHeadingLevel,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (int level = 1; level <= 3; level++)
              ListTile(
                leading: Icon(
                  Icons.title_rounded,
                  size: 18 + level * 4,
                ),
                title: Text(l10n.blockHeadingLevelValue(level)),
                trailing: level == current ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.of(sheetContext).pop(level),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/// صف اختيار بسيط يُستخدم داخل نماذج صغيرة (يُعرَّف هنا لتقليل التكرار).
class BlockOptionRow extends StatelessWidget {
  const BlockOptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: theme.colorScheme.primary),
      title: Text(label),
      trailing: selected ? const Icon(Icons.check_rounded, size: 18) : null,
      onTap: onTap,
    );
  }
}
