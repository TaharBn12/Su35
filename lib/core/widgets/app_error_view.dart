import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../failures/app_failure.dart';
import '../failures/failure_l10n.dart';
import 'app_loading_view.dart';

/// عرض خطأ موحّد لكل الشاشات: رسالة مفهومة + إعادة محاولة + تفاصيل تقنية.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.failure,
    this.onRetry,
    this.compact = false,
  });

  final AppFailure failure;
  final Future<void> Function()? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppL10n l10n = context.l10n;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: EdgeInsets.all(compact ? 14 : 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                failure.iconData ?? Icons.error_outline_rounded,
                size: compact ? 26 : 36,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              failure.localizedTitle(l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              failure.localizedBody(l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  onRetry!();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.actionRetry),
              ),
            ],
            const SizedBox(height: 12),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  l10n.stateTechnicalDetails,
                  style: theme.textTheme.labelLarge,
                ),
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      'kind: ${failure.kind.name}\n'
                      'code: ${failure.code ?? '-'}\n'
                      '${failure.message}'
                      '${failure.details == null ? '' : '\n${failure.details}'}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// بطاقة خطأ صغيرة تُستخدم داخل القوائم الطويلة دون احتلال الشاشة كلها.
class AppInlineErrorCard extends StatelessWidget {
  const AppInlineErrorCard({super.key, required this.failure, this.onRetry});

  final AppFailure failure;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppL10n l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                failure.localizedBody(l10n),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  onRetry!();
                },
                child: Text(l10n.actionRetry),
              ),
          ],
        ),
      ),
    );
  }
}

/// يُستخدم أثناء إعادة المحاولة داخل الشاشة.
class AppRetryOverlay extends StatelessWidget {
  const AppRetryOverlay({super.key, required this.child, required this.isBusy});

  final Widget child;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (!isBusy) {
      return child;
    }
    return Stack(
      children: <Widget>[
        child,
        const Positioned.fill(
          child: ColoredBox(
            color: Color(0x66000000),
            child: AppLoadingView(),
          ),
        ),
      ],
    );
  }
}
