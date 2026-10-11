import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'setup_required_app.dart';

/// نقطة الدخول:
/// 1) قراءة الإعدادات من `.env` عبر [AppConfig].
/// 2) تهيئة Supabase (Auth + Postgres + Storage).
/// 3) تشغيل التطبيق داخل [ProviderScope] لـ Riverpod.
///
/// أي خلل في الإعداد يعرض شاشة إعداد واضحة بدل التعطّل.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.load();

  try {
    AppConfig.assertConfigured();

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // المفتاح الجديد القابل للنشر (sb_publishable_...)، ويقبل مفتاح anon القديم.
      publishableKey: AppConfig.supabasePublishableKey,
      debug: kDebugMode,
    );
  } on AppConfigException catch (error) {
    runApp(SetupRequiredApp(details: error.message));
    return;
  } catch (error) {
    runApp(SetupRequiredApp(details: error.toString()));
    return;
  }

  runApp(const ProviderScope(child: Su35App()));
}
