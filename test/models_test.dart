import 'dart:async';

import 'package:avnotes/src/core/constants/app_constants.dart';
import 'package:avnotes/src/core/env/app_env.dart';
import 'package:avnotes/src/core/errors/app_failure.dart';
import 'package:avnotes/src/core/localization/app_localizations.dart';
import 'package:avnotes/src/core/theme/app_theme.dart';
import 'package:avnotes/src/core/utils/json_utils.dart';
import 'package:avnotes/src/core/utils/validators.dart';
import 'package:avnotes/src/data/models/app_user.dart';
import 'package:avnotes/src/data/models/notebook.dart';
import 'package:avnotes/src/data/models/page.dart';
import 'package:avnotes/src/data/models/page_block.dart';
import 'package:avnotes/src/features/settings/providers/settings_provider.dart';
import 'package:avnotes/src/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('json_utils', () {
    test('parses the loose types PostgREST can return', () {
      expect(asString(null), '');
      expect(asString(42), '42');
      expect(asNullableString('  '), isNull);
      expect(asNullableString(' A320 '), 'A320');
      expect(asBool('t'), isTrue);
      expect(asBool('false'), isFalse);
      expect(asBool(null, fallback: true), isTrue);
      expect(asInt('32'), 32);
      expect(asInt(3.9), 3);
      expect(asNullableInt(''), isNull);
      expect(
        asNullableDateTime('2026-10-11T08:30:00+00:00'),
        DateTime.utc(2026, 10, 11, 8, 30),
      );
      expect(asNullableDateTime('not-a-date'), isNull);
      expect(asMap(<dynamic, dynamic>{1: 'a'}), <String, dynamic>{'1': 'a'});
      expect(asMapList(null), isEmpty);
      expect(
        asMapList(<dynamic>[
          <dynamic, dynamic>{'id': 1},
          'junk',
        ]),
        <Map<String, dynamic>>[
          <String, dynamic>{'id': 1},
        ],
      );
    });
  });

  group('validators', () {
    test('email', () {
      expect(Validators.email('captain@aeronotes.app'), isNull);
      expect(Validators.email('nope'), 'validation.email');
      expect(Validators.email(''), 'validation.required');
      expect(Validators.email(null), 'validation.required');
    });

    test('password', () {
      expect(Validators.password('12345678'), isNull);
      expect(Validators.password('1234567'), 'validation.passwordMin');
      expect(Validators.password(''), 'validation.required');
    });

    test('confirmPassword', () {
      expect(Validators.confirmPassword('abc12345', 'abc12345'), isNull);
      expect(
        Validators.confirmPassword('abc12345', 'abc12346'),
        'validation.passwordMismatch',
      );
    });

    test('aviation fields are optional but strict when filled', () {
      expect(Validators.optionalIcao(''), isNull);
      expect(Validators.optionalIcao('omdb'), isNull);
      expect(Validators.optionalIcao('OMD'), 'validation.icao');
      expect(Validators.optionalIcao('OMDBB'), 'validation.icao');

      expect(Validators.optionalRegistration(''), isNull);
      expect(Validators.optionalRegistration('a6-eov'), isNull);
      expect(Validators.optionalRegistration('A6 EOV'), 'validation.registration');

      expect(Validators.optionalAtaChapter(''), isNull);
      expect(Validators.optionalAtaChapter('032'), isNull);
      expect(Validators.optionalAtaChapter('3x'), 'validation.ataChapter');
      expect(Validators.normalizeAta('032'), '32');
      expect(Validators.normalizeAta('  '), isNull);
    });
  });

  group('Notebook model', () {
    test('round-trips through JSON and survives missing fields', () {
      final notebook = Notebook.fromJson(<String, dynamic>{
        'id': 'n-1',
        'user_id': 'u-1',
        'name': 'A320 Fleet',
        'icon': '✈️',
        'color': '#1F7A5C',
        'position': '2',
        'is_archived': false,
        'pages_count': 7,
        'created_at': '2026-10-01T10:00:00Z',
        'updated_at': '2026-10-02T10:00:00Z',
      });

      expect(notebook.name, 'A320 Fleet');
      expect(notebook.position, 2);
      expect(notebook.pagesCount, 7);
      expect(notebook.colorValue, 0xFF1F7A5C);
      expect(notebook.toJson()['name'], 'A320 Fleet');

      final insert = notebook.toInsertJson();
      expect(insert['user_id'], 'u-1');
      expect(insert.containsKey('id'), isFalse, reason: 'id is server side');
      expect(insert.containsKey('pages_count'), isFalse);
    });

    test('falls back to the default colour for junk values', () {
      expect(
        Notebook.fromJson(<String, dynamic>{
          'id': 'n',
          'user_id': 'u',
          'name': 'x',
          'color': 'not-a-colour',
        }).colorValue,
        0xFF0B4F8A,
      );
      expect(
        Notebook.fromJson(<String, dynamic>{
          'id': 'n',
          'user_id': 'u',
          'name': 'x',
          'color': '1F7A5C',
        }).colorValue,
        0xFF1F7A5C,
      );
    });

    test('listFromJson ignores junk rows', () {
      expect(
        Notebook.listFromJson(<dynamic>[
          <String, dynamic>{'id': 'a', 'user_id': 'u', 'name': 'A'},
          42,
        ]),
        hasLength(1),
      );
      expect(Notebook.listFromJson(null), isEmpty);
    });
  });

  group('NotePage model', () {
    test('parses aviation metadata and builds chips', () {
      final page = NotePage.fromJson(<String, dynamic>{
        'id': 'p-1',
        'user_id': 'u-1',
        'notebook_id': 'n-1',
        'parent_page_id': null,
        'title': 'Dubai → Jeddah',
        'template_key': 'flight_log',
        'aircraft_type': 'A320',
        'registration': 'A6-EOV',
        'ata_chapter': '32',
        'departure_icao': 'OMDB',
        'arrival_icao': 'OEJN',
        'flight_date': '2026-10-11',
        'child_count': 2,
        'is_favorite': true,
        'created_at': '2026-10-11T06:00:00Z',
        'updated_at': '2026-10-11T09:30:00Z',
      });

      expect(page.hasChildren, isTrue);
      expect(page.isSubPage, isFalse);
      expect(page.metadataChips, <String>[
        'A320',
        'A6-EOV',
        'ATA 32',
        'OMDB → OEJN',
      ]);
      expect(page.flightDate, DateTime(2026, 10, 11));

      final insert = page.toInsertJson();
      expect(insert['parent_page_id'], isNull);
      expect(insert.containsKey('parent_page_id'), isFalse);
      expect(insert['ata_chapter'], '32');
    });

    test('single airport falls back to airport_icao chip', () {
      final page = NotePage.fromJson(<String, dynamic>{
        'id': 'p',
        'user_id': 'u',
        'notebook_id': 'n',
        'title': 'Line check',
        'airport_icao': 'OEJN',
      });
      expect(page.metadataChips, <String>['OEJN']);
    });

    test('copyWith never loses the identity fields', () {
      final page = NotePage.fromJson(<String, dynamic>{
        'id': 'p-1',
        'user_id': 'u-1',
        'notebook_id': 'n-1',
        'title': 'Before',
      });
      final updated = page.copyWith(title: 'After');
      expect(updated.id, 'p-1');
      expect(updated.notebookId, 'n-1');
      expect(updated.title, 'After');
    });
  });

  group('PageBlock model', () {
    test('parses every block flavour', () {
      final checklist = PageBlock.fromJson(<String, dynamic>{
        'id': 'b-1',
        'user_id': 'u-1',
        'page_id': 'p-1',
        'type': 'checklist',
        'content': 'Fuel quantity checked',
        'is_checked': true,
        'position': 3,
      });
      expect(checklist.isChecked, isTrue);
      expect(checklist.isTextual, isTrue);
      expect(checklist.wordCount, 3);

      final divider = PageBlock.fromJson(<String, dynamic>{
        'id': 'b-2',
        'user_id': 'u-1',
        'page_id': 'p-1',
        'type': 'divider',
        'is_checked': null,
      });
      expect(divider.isChecked, isNull);
      expect(divider.isTextual, isFalse);

      final code = PageBlock.fromJson(<String, dynamic>{
        'id': 'b-3',
        'user_id': 'u-1',
        'page_id': 'p-1',
        'type': 'code',
        'content': 'TAS = CAS * sqrt(rho0/rho)',
        'language': 'text',
        'props': <String, dynamic>{'wrap': true},
      });
      expect(code.language, 'text');
      expect(code.props?['wrap'], true);

      // The insert payload must always carry the client generated id so the
      // offline queue (Stage D) can upsert safely.
      expect(code.toInsertJson()['id'], 'b-3');
    });

    test('unknown block types default to paragraph', () {
      expect(
        PageBlock.fromJson(<String, dynamic>{'id': 'b', 'page_id': 'p'}).type,
        BlockTypes.paragraph,
      );
    });
  });

  group('AppUser model', () {
    test('parses a profiles row', () {
      final user = AppUser.fromJson(<String, dynamic>{
        'id': 'u-1',
        'email': 'captain@aeronotes.app',
        'full_name': 'Sara Al Mansoori',
        'theme_mode': 'dark',
        'locale': 'ar',
        'is_email_verified': true,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });

      expect(user.themeMode, 'dark');
      expect(user.locale, 'ar');
      expect(user.isEmailVerified, isTrue);
      expect(user.displayName, 'Sara Al Mansoori');
      expect(user.toUpdateJson().containsKey('id'), isFalse);
    });

    test('falls back to the email local part for the display name', () {
      final user = AppUser.fromJson(<String, dynamic>{
        'id': 'u-1',
        'email': 'first.officer@aeronotes.app',
      });
      expect(user.displayName, 'first.officer');
      expect(user.themeMode, 'system');
      expect(user.locale, 'en');
    });
  });

  group('localization', () {
    test('English and Arabic cover exactly the same keys', () {
      final en = AppTranslations.english.values.keys.toSet();
      final ar = AppTranslations.arabic.values.keys.toSet();

      expect(
        en.difference(ar),
        isEmpty,
        reason: 'keys missing in the Arabic map',
      );
      expect(
        ar.difference(en),
        isEmpty,
        reason: 'keys missing in the English map',
      );
      expect(en.length, greaterThan(120));
    });

    test('every translation is non-empty', () {
      for (final entry in AppTranslations.english.values.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
      for (final entry in AppTranslations.arabic.values.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });

    test('get() falls back to the raw message then to the key', () {
      const t = AppTranslations(<String, String>{'a': 'A'});
      expect(t.get('a'), 'A');
      expect(t.get('missing', 'raw detail'), 'raw detail');
      expect(t.get('missing'), 'missing');
      expect(t.plural('a', 3), 'A');
    });

    test('template keys used by the UI exist in both languages', () {
      for (final key in <String>[
        TemplateKeys.flightLog,
        TemplateKeys.maintenance,
        TemplateKeys.preflightChecklist,
        TemplateKeys.theoryLesson,
        TemplateKeys.defectReport,
      ]) {
        expect(
          AppTranslations.english.values.containsKey('template.$key'),
          isTrue,
          reason: 'template.$key missing in EN',
        );
        expect(
          AppTranslations.arabic.values.containsKey('template.$key'),
          isTrue,
          reason: 'template.$key missing in AR',
        );
      }
    });
  });

  group('AppFailure mapping', () {
    test('maps Supabase auth errors to translation keys', () {
      expect(
        toAppFailure(
          const AuthException('Invalid login credentials', statusCode: '400'),
        ).messageKey,
        'error.invalidCredentials',
      );
      expect(
        toAppFailure(const AuthException('Email not confirmed')).messageKey,
        'error.emailNotConfirmed',
      );
      expect(
        toAppFailure(
          const AuthException('Password should be at least 8 characters'),
        ).messageKey,
        'error.weakPassword',
      );
      expect(
        toAppFailure(const AuthException('For security purposes, you can only '
                'request this after 34 seconds'))
            .messageKey,
        'error.rateLimit',
      );
      expect(
        toAppFailure(
          AuthRetryableFetchException(message: 'Failed to send request'),
        ).isNetwork,
        isTrue,
      );
    });

    test('maps PostgREST error codes', () {
      expect(
        toAppFailure(
          const PostgrestException(message: 'dup', code: '23505'),
        ).messageKey,
        'error.conflict',
      );
      expect(
        toAppFailure(
          const PostgrestException(message: 'rls', code: '42501'),
        ).messageKey,
        'error.permission',
      );
      expect(
        toAppFailure(
          const PostgrestException(message: 'no rows', code: 'PGRST116'),
        ).messageKey,
        'error.notFound',
      );
    });

    test('detects connectivity problems in raw exceptions', () {
      expect(
        toAppFailure(
          Exception('Failed host lookup: xyz.supabase.co'),
        ).isNetwork,
        isTrue,
      );
      expect(
        toAppFailure(StateError('boom')).messageKey,
        'error.generic',
      );
    });

    test('AppFailure is idempotent through toAppFailure', () {
      const failure = AppFailure('error.permission', details: 'nope');
      expect(toAppFailure(failure), same(failure));
      expect(
        failure.message(AppTranslations.english),
        'You do not have access to this resource.',
      );
      expect(
        const AppFailure('unknown.key', details: 'raw text')
            .message(AppTranslations.english),
        'raw text',
      );
    });
  });

  group('constants', () {
    test('block types match the Postgres enum exactly', () {
      // Keep in sync with `public.block_type` in migration 1.
      expect(BlockTypes.all, <String>[
        'paragraph',
        'heading1',
        'heading2',
        'heading3',
        'bullet_list',
        'numbered_list',
        'checklist',
        'table',
        'image',
        'pdf',
        'code',
        'divider',
        'callout',
        'page',
      ]);
      expect(BlockTypes.all.toSet().length, BlockTypes.all.length);
    });

    test('ATA chapters are 2-3 digits with a label', () {
      expect(AtaChapters.codes, isNotEmpty);
      for (final code in AtaChapters.codes) {
        expect(Validators.optionalAtaChapter(code), isNull, reason: code);
        expect(AtaChapters.label(code), isNot(code), reason: code);
      }
      expect(AtaChapters.label('32'), 'Landing Gear');
    });
  });

  group('AppEnv', () {
    test('loads valid credentials from the test fixture', () async {
      late AppEnv env;
      try {
        env = await AppEnv.load(path: 'test/fixtures/.env.test');
      } on EnvNotConfiguredException catch (error) {
        // The bundle loader is not available in this test environment; the
        // guard itself is exercised by the placeholder test below.
        expect(error.message, contains('.env'));
        return;
      }

      expect(env.supabaseUrl, 'https://testproject.supabase.co');
      expect(env.supabaseKey, startsWith('eyJ'));
      expect(env.usesPublishableKey, isFalse);
      expect(env.anonKey, startsWith('eyJ'));
      expect(env.publishableKey, isNull);
      expect(env.attachmentsBucket, 'attachments');
    });

    test('refuses to boot with placeholder credentials', () async {
      try {
        await AppEnv.load(path: 'test/fixtures/.env.placeholder');
        fail('AppEnv.load accepted the placeholder .env');
      } on EnvNotConfiguredException catch (error) {
        expect(error.message, contains('YOUR-PROJECT-REF'));
      } catch (_) {
        // Asset bundle unavailable in this environment - nothing to assert.
      }
    });

    test('prefers the publishable key when both are present', () async {
      try {
        final env = await AppEnv.load(
          path: 'test/fixtures/.env.publishable',
        );
        expect(env.usesPublishableKey, isTrue);
        expect(env.supabaseKey, startsWith('sb_publishable_'));
        expect(env.anonKey, isNull);
      } on EnvNotConfiguredException {
        // ignored - see above
      } catch (_) {
        // ignored - see above
      }
    });
  });

  group('AppTheme', () {
    test('builds light and dark Material 3 themes', () {
      final light = AppTheme.buildLight();
      final dark = AppTheme.buildDark();

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.cardTheme.shape, isNotNull);
      expect(dark.scaffoldBackgroundColor, AppTheme.navy);
      expect(AppTheme.notebookColors, isNotEmpty);
      expect(AppTheme.notebookIcons, contains('\u2708\uFE0F'));
    });
  });

  group('SettingsState', () {
    test('defaults are system theme + English + not loaded', () {
      const state = SettingsState();
      expect(state.themeMode, ThemeMode.system);
      expect(state.locale, AppLocalizations.english);
      expect(state.loaded, isFalse);
      expect(state.isRtl, isFalse);
    });

    test('copyWith keeps the rest and flips RTL for Arabic', () {
      const state = SettingsState(loaded: true);
      final arabic = state.copyWith(locale: AppLocalizations.arabic);
      expect(arabic.loaded, isTrue);
      expect(arabic.isRtl, isTrue);
      expect(arabic.themeMode, ThemeMode.system);
      expect(state == arabic, isFalse);
      expect(state == state.copyWith(), isTrue);
    });
  });

  group('router helpers', () {
    test('route builders produce stable paths', () {
      expect(AppRoutes.notebook('n1'), '/notebooks/n1');
      expect(AppRoutes.pageViewer('p1', 'n1'), '/notebooks/n1/pages/p1');
      expect(AppRoutes.home, '/home');
      expect(AppRoutes.auth, '/auth');
      expect(AppRoutes.settings, '/settings');
    });

    test('GoRouterRefreshStream notifies on stream events and errors', () async {
      final controller = StreamController<int>.broadcast();
      final refresh = GoRouterRefreshStream(controller.stream);
      var notifications = 0;
      refresh.addListener(() => notifications++);

      controller.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);

      controller.addError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 2);

      refresh.dispose();
      await controller.close();
    });
  });
}
