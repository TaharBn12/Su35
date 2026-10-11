import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'app_failure.dart';

/// ترجمة تصنيف الخطأ إلى نص يفهَمه المستخدم (بدل رسائل الخادم التقنية).
extension AppFailureL10n on AppFailure {
  String localizedBody(AppL10n l10n) {
    if (kind == FailureKind.network) {
      return l10n.errorNetworkBody;
    }
    if (kind == FailureKind.auth) {
      return l10n.errorAuthBody;
    }
    if (kind == FailureKind.permission) {
      return l10n.errorPermissionBody;
    }
    if (kind == FailureKind.notFound) {
      return l10n.errorNotFoundBody;
    }
    if (kind == FailureKind.conflict) {
      return l10n.errorConflictBody;
    }
    if (kind == FailureKind.validation) {
      return l10n.errorValidationBody;
    }
    if (kind == FailureKind.config) {
      return l10n.setupRequiredBody;
    }
    return l10n.errorUnknownBody;
  }

  String localizedTitle(AppL10n l10n) {
    if (kind == FailureKind.config) {
      return l10n.setupRequiredTitle;
    }
    return l10n.errorGenericTitle;
  }

  /// أيقونة مناسبة لنوع الخطأ (تعود للواجهة لتزيين شاشة الخطأ).
  IconData? get iconData {
    if (kind == FailureKind.network) {
      return Icons.wifi_off_rounded;
    }
    if (kind == FailureKind.permission) {
      return Icons.lock_outline_rounded;
    }
    if (kind == FailureKind.notFound) {
      return Icons.search_off_rounded;
    }
    if (kind == FailureKind.config) {
      return Icons.settings_suggest_rounded;
    }
    return Icons.error_outline_rounded;
  }
}
