import 'package:supabase_flutter/supabase_flutter.dart';

import '../localization/app_localizations.dart';

/// A single, UI-friendly error type used across repositories and notifiers.
///
/// Screens never have to know about `PostgrestException` / `AuthException` /
/// `StorageException`: they receive an [AppFailure] whose [messageKey] is a key
/// into [AppTranslations] and whose [details] is the raw (developer facing)
/// message that can be logged or shown in a tooltip.
class AppFailure implements Exception {
  const AppFailure(
    this.messageKey, {
    this.details,
    this.statusCode,
    this.isNetwork = false,
    this.isAuth = false,
  });

  /// Translation key (see [AppTranslations]). Falls back to [details] when the
  /// key is unknown, so nothing is ever shown as "null".
  final String messageKey;

  /// Raw message coming from Supabase / Dart. Never shown as the primary text.
  final String? details;

  /// Postgres / PostgREST status code when available.
  final String? statusCode;

  /// `true` when the failure looks like a connectivity problem.
  final bool isNetwork;

  /// `true` when the failure comes from Supabase Auth.
  final bool isAuth;

  /// Human readable, localized message for the current [t].
  String message(AppTranslations t) => t.get(messageKey, details);

  @override
  String toString() =>
      'AppFailure(key: $messageKey, status: $statusCode, details: $details)';
}

/// Maps any thrown object to an [AppFailure].
AppFailure toAppFailure(Object error) {
  if (error is AppFailure) return error;

  if (error is AuthException) {
    return AppFailure(
      _authMessageKey(error.message),
      details: error.message,
      statusCode: error.statusCode,
      isAuth: true,
      isNetwork: _looksOffline(error.message),
    );
  }

  if (error is PostgrestException) {
    return AppFailure(
      _postgrestMessageKey(error),
      details: error.message,
      statusCode: error.code,
    );
  }

  if (error is StorageException) {
    return AppFailure(
      'error.storage',
      details: error.message,
      statusCode: error.statusCode,
    );
  }

  if (error is AuthRetryableFetchException || error is AuthUnknownException) {
    return AppFailure(
      'error.network',
      details: error.toString(),
      isNetwork: true,
    );
  }

  final text = error.toString();
  if (_looksOffline(text)) {
    return AppFailure('error.network', details: text, isNetwork: true);
  }
  if (text.contains('row-level security') || text.contains('RLS')) {
    return AppFailure('error.permission', details: text);
  }

  return AppFailure('error.generic', details: text);
}

bool _looksOffline(String message) {
  final lower = message.toLowerCase();
  return lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network') ||
      lower.contains('connection refused') ||
      lower.contains('timeout') ||
      lower.contains('clientexception');
}

String _authMessageKey(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('invalid login credentials') ||
      lower.contains('invalid credentials')) {
    return 'error.invalidCredentials';
  }
  if (lower.contains('email not confirmed')) {
    return 'error.emailNotConfirmed';
  }
  if (lower.contains('already registered') ||
      lower.contains('already been registered')) {
    return 'error.emailInUse';
  }
  if (lower.contains('password')) {
    return 'error.weakPassword';
  }
  if (lower.contains('email') || lower.contains('invalid email')) {
    return 'error.invalidEmail';
  }
  if (lower.contains('rate limit') || lower.contains('too many requests')) {
    return 'error.rateLimit';
  }
  if (lower.contains('session') || lower.contains('token')) {
    return 'error.sessionExpired';
  }
  if (_looksOffline(message)) {
    return 'error.network';
  }
  return 'error.auth';
}

String _postgrestMessageKey(PostgrestException error) {
  switch (error.code) {
    case '23505': // unique_violation
      return 'error.conflict';
    case '23503': // foreign_key_violation
      return 'error.foreignKey';
    case '23514': // check_violation
      return 'error.validation';
    case '42501': // insufficient_privilege (RLS)
    case 'PGRST301':
      return 'error.permission';
    case 'PGRST116': // 0 rows returned for `.single()`
      return 'error.notFound';
    default:
      if (_looksOffline(error.message)) return 'error.network';
      return 'error.database';
  }
}
