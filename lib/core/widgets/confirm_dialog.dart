import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// نافذة تأكيد موحّدة (تُستخدم قبل الحذف أو تسجيل الخروج).
/// تُعيد true إذا أكّد المستخدم.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String? confirmLabel,
  bool destructive = true,
  IconData? icon,
}) async {
  final ThemeData theme = Theme.of(context);
  final AppL10n l10n = context.l10n;

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        icon: icon == null
            ? null
            : Icon(
                icon,
                color: destructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  )
                : null,
            child: Text(confirmLabel ?? l10n.actionDelete),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
