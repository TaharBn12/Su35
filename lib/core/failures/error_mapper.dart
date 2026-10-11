import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'app_failure.dart';

/// تحويل أي استثناء قادم من Supabase/الشبكة إلى [AppFailure] موحّد.
///
/// ملاحظة مهمة: لا نستورد `dart:io` حتى يبقى المشروع قابلًا للبناء على الويب،
/// لذلك نتعرّف على أخطاء الشبكة عبر أنواع الاستثناءات القياسية واسم النوع.
class ErrorMapper {
  const ErrorMapper._();

  static AppFailure map(Object error, [StackTrace? stackTrace]) {
    if (error is AppFailure) {
      return error;
    }
    if (error is PostgrestException) {
      return _fromPostgrest(error);
    }
    if (error is AuthException) {
      return _fromAuth(error);
    }
    if (error is StorageException) {
      return AppFailure(
        kind: FailureKind.unknown,
        message: 'StorageException: ${error.message}',
      );
    }
    if (error is AppConfigException) {
      return AppFailure(
        kind: FailureKind.config,
        message: error.message,
      );
    }
    if (error is TimeoutException) {
      return const AppFailure(
        kind: FailureKind.network,
        message: 'Request timed out',
      );
    }
    if (_looksLikeNetworkError(error)) {
      return AppFailure(
        kind: FailureKind.network,
        message: error.toString(),
      );
    }
    if (error is ArgumentError) {
      return AppFailure(
        kind: FailureKind.validation,
        message: error.message?.toString() ?? 'Invalid argument',
      );
    }
    if (error is StateError) {
      return AppFailure(
        kind: FailureKind.unknown,
        message: error.message,
      );
    }

    return AppFailure(
      kind: FailureKind.unknown,
      message: error.toString(),
    );
  }

  static AppFailure _fromPostgrest(PostgrestException error) {
    final code = error.code ?? '';
    FailureKind kind = FailureKind.unknown;

    // رموز PostgreSQL / PostgREST الشائعة
    if (code == '23505') {
      kind = FailureKind.conflict; // unique_violation
    } else if (code == '23503' ||
        code == '23514' ||
        code == '22P02' ||
        code == '22001') {
      kind = FailureKind.validation; // قيود مرجعية/تحقق/أنواع
    } else if (code == '42501') {
      kind = FailureKind.permission; // insufficient_privilege (RLS)
    } else if (code == 'PGRST116') {
      kind = FailureKind.notFound; // لا نتائج حيث كان متوقعًا صف واحد
    } else if (code == 'PGRST301') {
      kind = FailureKind.auth; // JWT منتهي أو غير مصرّح
    } else if (code.startsWith('42')) {
      kind = FailureKind.permission;
    }

    return AppFailure(
      kind: kind,
      message: error.message,
      code: error.code,
      details: error.details?.toString() ?? error.hint,
    );
  }

  static AppFailure _fromAuth(AuthException error) {
    final message = error.message.toLowerCase();
    FailureKind kind = FailureKind.auth;

    if (message.contains('failed host lookup') ||
        message.contains('socket') ||
        message.contains('connection') ||
        message.contains('network')) {
      kind = FailureKind.network;
    } else if (message.contains('rate limit') || message.contains('too many')) {
      kind = FailureKind.permission;
    }

    return AppFailure(
      kind: kind,
      message: error.message,
      code: error.statusCode,
    );
  }

  static bool _looksLikeNetworkError(Object error) {
    final name = error.runtimeType.toString();
    return name == 'SocketException' ||
        name == 'ClientException' ||
        name == 'HttpException' ||
        name == 'HandshakeException' ||
        name == 'AuthRetryableFetchException' ||
        name == 'AuthRetryableFetchError';
  }
}
