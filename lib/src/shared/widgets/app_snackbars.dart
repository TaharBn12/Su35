import 'package:flutter/material.dart';

import '../../core/errors/app_failure.dart';
import '../../core/localization/app_localizations.dart';

/// Snackbars with a consistent look for success / error / info.
class AppSnackbars {
  const AppSnackbars._();

  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      background: const Color(0xFF1F7A5C),
      foreground: Colors.white,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline_rounded,
      background: Theme.of(context).colorScheme.inverseSurface,
      foreground: Theme.of(context).colorScheme.onInverseSurface,
    );
  }

  /// Shows a localized error message derived from any thrown object.
  static void error(BuildContext context, Object error) {
    final t = context.t;
    final failure = toAppFailure(error);
    _show(
      context,
      message: failure.message(t),
      icon: Icons.error_outline_rounded,
      background: Theme.of(context).colorScheme.error,
      foreground: Theme.of(context).colorScheme.onError,
    );
  }

  static void failure(BuildContext context, AppFailure failure) {
    _show(
      context,
      message: failure.message(context.t),
      icon: Icons.error_outline_rounded,
      background: Theme.of(context).colorScheme.error,
      foreground: Theme.of(context).colorScheme.onError,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color background,
    required Color foreground,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: foreground),
                ),
              ),
            ],
          ),
          backgroundColor: background,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
        ),
      );
  }
}
