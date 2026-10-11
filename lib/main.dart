import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app/app.dart';
import 'src/app/configuration_error_screen.dart';
import 'src/core/env/app_env.dart';
import 'src/features/settings/providers/settings_provider.dart';

Future<void> main() async {
  // `Supabase.initialize` touches platform channels (shared_preferences,
  // app_links), so bindings must be ready first.
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Environment -----------------------------------------------------------
  //    No credential is hard-coded anywhere: everything comes from the dotenv
  //    bundle declared in pubspec.yaml (assets/env/.env).
  late final AppEnv env;
  try {
    env = await AppEnv.load();
  } on EnvNotConfiguredException catch (error) {
    runApp(
      ConfigurationErrorScreen(
        title: 'Invalid environment configuration',
        message: error.message,
      ),
    );
    return;
  } catch (error) {
    runApp(
      ConfigurationErrorScreen(
        title: 'Could not read assets/env/.env',
        message: error.toString(),
      ),
    );
    return;
  }

  // 2) Supabase (Auth + Postgres + Storage + Realtime) -----------------------
  try {
    if (env.usesPublishableKey) {
      await Supabase.initialize(
        url: env.supabaseUrl,
        publishableKey: env.supabaseKey,
        debug: kDebugMode,
      );
    } else {
      // `anonKey` is deprecated in supabase_flutter 2.18+ but is still the
      // correct parameter for projects that have not migrated to the new
      // API keys yet.
      // ignore: deprecated_member_use
      await Supabase.initialize(
        url: env.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: env.supabaseKey,
        debug: kDebugMode,
      );
    }
  } catch (error) {
    runApp(
      ConfigurationErrorScreen(
        title: 'Supabase.initialize failed',
        message: '$error\n\nURL: ${env.supabaseUrl}',
      ),
    );
    return;
  }

  // 3) Root container --------------------------------------------------------
  //    Created before `runApp` so we can (a) preload persisted settings and
  //    (b) build the router once, keeping the navigator stable for the whole
  //    app lifetime.
  final container = ProviderContainer(observers: appProviderObservers);

  // Read the persisted theme/language before the first frame to avoid a flash
  // of the wrong theme or an LTR-to-RTL jump.
  await container.read(settingsControllerProvider).preload();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AvnotesApp(),
    ),
  );
}
