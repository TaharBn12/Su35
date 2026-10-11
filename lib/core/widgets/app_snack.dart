import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../failures/app_failure.dart';
import '../failures/failure_l10n.dart';

/// رسالة نجاح/معلومة سريعة.
void showAppSnack(BuildContext context, String message) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final ThemeData theme = Theme.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: theme.colorScheme.inverseSurface,
      showCloseIcon: true,
    ),
  );
}

/// رسالة خطأ مبنية على [AppFailure] مترجمة للمستخدم.
void showAppFailureSnack(BuildContext context, Object error) {
  final AppFailure failure = error is AppFailure
      ? error
      : AppFailure(kind: FailureKind.unknown, message: error.toString());
  final AppL10n l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        failure.localizedBody(l10n),
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
      backgroundColor: theme.colorScheme.errorContainer,
      showCloseIcon: true,
      closeIconColor: theme.colorScheme.onErrorContainer,
    ),
  );
}
