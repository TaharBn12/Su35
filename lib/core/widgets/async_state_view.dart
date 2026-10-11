import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../failures/app_failure.dart';
import '../failures/error_mapper.dart';
import 'app_empty_view.dart';
import 'app_error_view.dart';
import 'app_loading_view.dart';

/// عرض موحّد لأي [AsyncValue]:
///  • تحميل → [AppLoadingView]
///  • خطأ   → [AppErrorView] مع زر إعادة المحاولة
///  • بيانات → الباني الممرَّر (مع احتمال حالة «فارغ»).
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.isEmpty,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) builder;
  final Future<void> Function()? onRetry;
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, AppFailure failure)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (T data) {
        if (isEmpty != null && isEmpty!(data)) {
          return emptyBuilder?.call(context) ??
              AppEmptyView(title: context.l10n.stateEmpty);
        }
        return builder(context, data);
      },
      error: (Object error, StackTrace stackTrace) {
        final AppFailure failure = ErrorMapper.map(error, stackTrace);
        if (errorBuilder != null) {
          return errorBuilder!(context, failure);
        }
        return AppErrorView(failure: failure, onRetry: onRetry);
      },
      loading: () => loadingBuilder?.call(context) ?? const AppLoadingView(),
    );
  }
}
