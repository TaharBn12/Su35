import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../domain/block.dart';
import 'block_style.dart';

/// الإجراءات المتاحة على الكتلة من قائمتها.
enum BlockAction { insertAfter, moveUp, moveDown, changeType, delete }

/// إطار الكتلة داخل المحرّر: شريط أنواع + قائمة إجراءات + محتوى الكتلة نفسه.
///
/// الإطار لا يعرف شيئًا عن محتوى الكتلة؛ الشاشة هي التي تبني المحتوى حسب النوع
/// وتمرّره كـ [child]، فيبقى هذا الملف مسؤولًا عن التنقّل والقائمة فقط.
class BlockTile extends StatelessWidget {
  const BlockTile({
    super.key,
    required this.block,
    required this.index,
    required this.total,
    required this.child,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onAction,
    this.focused = false,
  });

  final NoteBlock block;
  final int index;
  final int total;
  final Widget child;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<BlockAction> onAction;

  /// هل هذه الكتلة النصية هي المُركَّز عليها الآن؟ (تُبرز الإطار)
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppL10n l10n = context.l10n;
    final Color accent = blockTypeColor(block.type);
    final bool isDivider = block.type == BlockType.divider;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: focused ? accent.withValues(alpha: 0.05) : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? accent.withValues(alpha: 0.55)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: focused ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 10, end: 4, top: 2),
            child: Row(
              children: <Widget>[
                Icon(block.type.icon, size: 15, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    blockTypeLabel(block.type, l10n),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!block.hasServerId)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                _BlockMenu(
                  l10n: l10n,
                  canMoveUp: canMoveUp,
                  canMoveDown: canMoveDown,
                  onSelected: onAction,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              10,
              isDivider ? 0 : 2,
              10,
              isDivider ? 4 : 10,
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BlockMenu extends StatelessWidget {
  const _BlockMenu({
    required this.l10n,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onSelected,
  });

  final AppL10n l10n;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<BlockAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<BlockAction>(
      tooltip: l10n.blockMenuTooltip,
      padding: EdgeInsets.zero,
      iconSize: 18,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<BlockAction>>[
        _item(
          value: BlockAction.insertAfter,
          icon: Icons.add_rounded,
          label: l10n.editorInsertAfter,
        ),
        _item(
          value: BlockAction.moveUp,
          icon: Icons.arrow_upward_rounded,
          label: l10n.editorMoveUp,
          enabled: canMoveUp,
        ),
        _item(
          value: BlockAction.moveDown,
          icon: Icons.arrow_downward_rounded,
          label: l10n.editorMoveDown,
          enabled: canMoveDown,
        ),
        _item(
          value: BlockAction.changeType,
          icon: Icons.swap_vert_rounded,
          label: l10n.editorChangeType,
        ),
        const PopupMenuDivider(),
        _item(
          value: BlockAction.delete,
          icon: Icons.delete_outline_rounded,
          label: l10n.actionDelete,
          destructive: true,
        ),
      ],
    );
  }

  PopupMenuItem<BlockAction> _item({
    required BlockAction value,
    required IconData icon,
    required String label,
    bool enabled = true,
    bool destructive = false,
  }) {
    return PopupMenuItem<BlockAction>(
      value: value,
      enabled: enabled,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: destructive
                  ? const TextStyle(color: Color(0xFFB3261E))
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
