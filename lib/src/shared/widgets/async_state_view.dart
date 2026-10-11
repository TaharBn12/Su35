import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_failure.dart';
import '../../core/localization/app_localizations.dart';

/// Renders the three universal states of an [AsyncValue]: loading, error and
/// data. Every list screen in the app goes through this widget so error and
/// empty handling stay consistent.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.value,
    required this.builder,
    super.key,
    this.onRetry,
    this.emptyBuilder,
    this.errorMessageOverride,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  /// Called by the retry button. When null the button is hidden.
  final VoidCallback? onRetry;

  /// Optional custom empty widget (used when `data` is an empty list).
  final Widget Function()? emptyBuilder;

  /// Overrides the derived error text (rarely needed).
  final String? errorMessageOverride;

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return value.when(
      // While refreshing we keep showing the old data (skipLoadingOnRefresh
      // defaults to true in Riverpod), so this is only the first load.
      loading: () => const CenteredProgress(),
      error: (error, stackTrace) => ErrorStateView(
        message:
            errorMessageOverride ?? toAppFailure(error).message(t),
        technicalDetails: '$error',
        stackTrace: stackTrace,
        onRetry: onRetry,
      ),
      data: (data) {
        if (emptyBuilder != null && _isEmpty(data)) return emptyBuilder!();
        return builder(data);
      },
    );
  }

  bool _isEmpty(T data) {
    if (data is List) return data.isEmpty;
    if (data is Map) return data.isEmpty;
    if (data == null) return true;
    return false;
  }
}

/// Full-screen (or inline) circular progress indicator.
class CenteredProgress extends StatelessWidget {
  const CenteredProgress({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state with a localized message, the raw technical detail (collapsed)
/// and a retry action.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    required this.message,
    super.key,
    this.technicalDetails,
    this.stackTrace,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final String? technicalDetails;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.t;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 16 : 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: theme.colorScheme.onErrorContainer,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              t.get('state.errorTitle'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(t.get('state.retry')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(180, 46),
                ),
              ),
            ],
            if (technicalDetails != null && technicalDetails!.isNotEmpty) ...<
                Widget>[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _showDetails(context),
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                label: Text(
                  'Details',
                  style: theme.textTheme.labelMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Technical details',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      '${technicalDetails ?? ''}\n\n'
                      '${stackTrace?.toString() ?? ''}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
