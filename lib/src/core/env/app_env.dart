import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thrown when the bundled `.env` file is missing or still contains the
/// placeholder values shipped with the repository.
class EnvNotConfiguredException implements Exception {
  const EnvNotConfiguredException(this.message);

  /// Human readable explanation shown on the "configuration" error screen.
  final String message;

  @override
  String toString() => 'EnvNotConfiguredException: $message';
}

/// Typed access to the environment variables loaded from `assets/env/.env`.
///
/// No Supabase credential is ever hard-coded in Dart source: everything is
/// read from the dotenv bundle at startup (see `main.dart`).
class AppEnv {
  AppEnv._({
    required this.supabaseUrl,
    required this.supabaseKey,
    required this.attachmentsBucket,
    required this.usesPublishableKey,
    this.anonKey,
    this.publishableKey,
  });

  /// e.g. `https://abcdefgh.supabase.co`
  final String supabaseUrl;

  /// The publishable key (`sb_publishable_...`) when available, otherwise the
  /// legacy anon key (`eyJhbGci...`).
  final String supabaseKey;

  /// Storage bucket name used for page attachments (images / PDFs).
  final String attachmentsBucket;

  /// Legacy anon key (JWT) when that is what the project uses.
  ///
  /// `Supabase.initialize(anonKey:)` is deprecated in supabase_flutter 2.18+,
  /// so `main.dart` picks the right named parameter based on
  /// [usesPublishableKey].
  final String? anonKey;

  /// New-style publishable key (`sb_publishable_...`).
  final String? publishableKey;

  /// `true` when [supabaseKey] is a new-style publishable key.
  final bool usesPublishableKey;

  static const String _envPath = 'assets/env/.env';

  /// Loads and validates the environment. Must be awaited before
  /// `Supabase.initialize`.
  static Future<AppEnv> load({String path = _envPath}) async {
    try {
      await dotenv.load(fileName: path);
    } catch (error) {
      throw EnvNotConfiguredException(
        'Could not read "$path". Make sure the file exists and is declared '
        'under flutter > assets in pubspec.yaml.\n$error',
      );
    }

    final url = _read('SUPABASE_URL');
    final publishable = _read('SUPABASE_PUBLISHABLE_KEY');
    final anon = _read('SUPABASE_ANON_KEY');
    final bucket = _read('SUPABASE_STORAGE_BUCKET');

    if (url == null) {
      throw const EnvNotConfiguredException(
        'SUPABASE_URL is missing from assets/env/.env',
      );
    }
    if (!Uri.tryParse(url)?.isAbsolute ?? true) {
      throw EnvNotConfiguredException('SUPABASE_URL is not a valid URL: $url');
    }
    if (url.contains('YOUR-PROJECT-REF')) {
      throw const EnvNotConfiguredException(
        'SUPABASE_URL still contains the placeholder "YOUR-PROJECT-REF". '
        'Open assets/env/.env and paste your real project URL.',
      );
    }

    final key = publishable ?? anon;
    if (key == null) {
      throw const EnvNotConfiguredException(
        'Neither SUPABASE_PUBLISHABLE_KEY nor SUPABASE_ANON_KEY is set in '
        'assets/env/.env',
      );
    }
    if (key.contains('YOUR-ANON-KEY')) {
      throw const EnvNotConfiguredException(
        'SUPABASE_ANON_KEY still contains the placeholder "YOUR-ANON-KEY". '
        'Open assets/env/.env and paste your real anon/publishable key.',
      );
    }
    if (key.startsWith('eyJ') == false && !key.startsWith('sb_')) {
      throw const EnvNotConfiguredException(
        'The supplied key does not look like a Supabase client key. '
        'Use the "anon public" key (JWT, starts with "eyJ") or the new '
        'publishable key (starts with "sb_publishable_").',
      );
    }

    return AppEnv._(
      supabaseUrl: url,
      supabaseKey: key,
      attachmentsBucket: bucket ?? 'attachments',
      usesPublishableKey: publishable != null,
      anonKey: publishable == null ? anon : null,
      publishableKey: publishable,
    );
  }

  static String? _read(String key) {
    final value = dotenv.env[key]?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
