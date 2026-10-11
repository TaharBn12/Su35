import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';

/// Destructive-action confirmation. Returns `true` only when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  bool destructive = true,
}) async {
  final t = context.t;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.get('generic.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              minimumSize: const Size(110, 44),
              backgroundColor: destructive ? theme.colorScheme.error : null,
              foregroundColor: destructive ? theme.colorScheme.onError : null,
            ),
            child: Text(
              confirmLabel ??
                  (destructive
                      ? t.get('generic.delete')
                      : t.get('generic.yes')),
            ),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Information dialog with a single OK button (used after signup, resets, ...).
Future<void> showInfoDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? actionLabel,
}) async {
  final t = context.t;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: Text(actionLabel ?? t.get('generic.done')),
          ),
        ],
      );
    },
  );
}
