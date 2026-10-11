# Verified package versions

All versions below were checked against the packages' **own sources** (pubspecs on
their default/release branches) — not guessed. The toolchain floor comes from the
strictest of them.

## Toolchain

| | Version | Note |
| --- | --- | --- |
| Flutter stable | **3.47.x** | release-candidate branch of the stable commit is `flutter-3.47-candidate.0` |
| Dart | **3.13.x** | `google_fonts`/`go_router` on `flutter/packages@main` require Dart ≥ 3.12–3.13 |

`pubspec.yaml` therefore declares:

```yaml
environment:
  sdk: ^3.13.0
  flutter: ">=3.47.0"
```

## Dependencies used in Stage A

| Package | Constraint | Verified latest | Source of truth |
| ------- | ---------- | --------------- | --------------- |
| `flutter_riverpod` | `^3.4.3` | 3.4.3 | `rrousselGit/riverpod@master → packages/flutter_riverpod/pubspec.yaml` |
| `go_router` | `^18.0.2` | 18.0.2 | `flutter/packages@main → packages/go_router/pubspec.yaml` (18.0.0 = "Migrates to material_ui and cupertino_ui, min Flutter 3.44/Dart 3.12") |
| `supabase_flutter` | `^2.18.2` | 2.18.2 | `supabase-community/supabase-flutter@release/supabase_flutter-2.17.x → packages/supabase_flutter/pubspec.yaml` (deps: supabase 2.16.4, shared_preferences ^2.5.5) |
| `flutter_dotenv` | `^5.2.1` | 5.2.1 | package mirror `onyx144/Fluter-plugin → flutter_dotenv-5.2.1/pubspec.yaml` (sdk `>=2.12.0-0 <4.0.0`) |
| `shared_preferences` | `^2.5.6` | 2.5.6 | `flutter/packages@main → packages/shared_preferences/shared_preferences/pubspec.yaml` |
| `intl` | `^0.20.2` | 0.20.x | `flutter_localizations` pins `intl`; `DateFormat.yMMMd('ar')` used for dates |
| `uuid` | `^4.6.0` | 4.6.0 | `Daegalus/dart-uuid@main → pubspec.yaml` |

### Dev dependencies

| Package | Constraint | Verified latest | Source |
| ------- | ---------- | --------------- | ------ |
| `flutter_lints` | `^6.0.0` | 6.0.0 | `flutter/packages@main → packages/flutter_lints/pubspec.yaml` |

## Reserved for the next stages (commented in `pubspec.yaml`)

| Stage | Package | Verified latest | Source |
| ----- | ------- | --------------- | ------ |
| B | `flutter_quill` | 11.x | rich-text editor; verify the exact minor with `flutter pub add flutter_quill` before Stage B |
| C | `cached_network_image` | 4.0.4 | `Baseflow/flutter_cached_network_image@main` (needs Flutter ≥ 3.44 — compatible) |
| C | `pdf` / `printing` | 3.x / 5.x | page → PDF export |
| C | `file_picker` | 10.x | attachment picker |
| D | `drift` | 2.35.2 | `simolus3/drift@develop → drift/pubspec.yaml` (sdk ≥ 3.10) |
| D | `drift_flutter` | 0.3.1 | `simolus3/drift@develop → drift_flutter/pubspec.yaml` |
| D | `drift_dev` | 2.35.1 | `simolus3/drift@develop → drift_dev/pubspec.yaml` |
| D | `path_provider` | 2.1.6 | `flutter/packages@main` |
| D | `build_runner` | 2.16.2 | `dart-lang/build@master` shows `2.16.3-wip`; pin `^2.16.2` and let pub resolve |

Deliberately **not** used:

* `google_fonts` (9.0.0) — it downloads fonts at runtime (needs network) or requires
  bundled `.ttf` assets. The app uses platform fonts so Arabic works offline out of the
  box. To brand the typography, drop `Cairo`/`IBM Plex Sans Arabic` into `assets/fonts`
  and set `fontFamily` in `AppTheme._base`.
* `freezed` / `json_serializable` / `riverpod_generator` — the models are small, hand
  written and fully explicit; no build step is required until Stage D (Drift).

## API differences this codebase is written against

Verified in the sources, because they differ from Riverpod 2 / older Flutter guides:

| Area | Riverpod 3.4 / Flutter 3.47 reality |
| ---- | ----------------------------------- |
| `Ref` | non-generic (`Ref`, not `Ref<T>`); `ref.read/watch/invalidate/listen/onDispose/mounted` |
| Providers | `Provider`, `FutureProvider`, `StreamProvider`, `NotifierProvider`, `AsyncNotifierProvider`, `StreamNotifierProvider` |
| Legacy | `StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider` moved to `package:flutter_riverpod/legacy.dart` — **not used here** |
| `AsyncValue` | `.value` is nullable (old `valueOrNull` is gone), `.requireValue`, `.when(data/error/loading)`, `.copyWithPrevious`, `AsyncValue.guard` |
| Family notifiers | the argument is passed to the **notifier constructor**: `AsyncNotifierProvider.autoDispose.family<N, T, Arg>((arg) => N(arg))` |
| `ProviderObserver` | `didUpdateProvider(ProviderObserverContext context, Object? previousValue, Object? newValue)` |
| `RadioListTile` | `groupValue`/`onChanged` deprecated → wrap in `RadioGroup<T>(groupValue:, onChanged:, child:)` |
| `CardTheme` / `DialogTheme` | the `ThemeData` fields take `CardThemeData` / `DialogThemeData` |
| Colors | `Color.withValues(alpha: …)` and `Color.toARGB32()` (the old `withOpacity`/`.value` are deprecated) |
| Supabase | `Supabase.initialize(publishableKey:)` preferred; `anonKey:` still supported but deprecated. `PostgrestQueryBuilder.select()` returns `List<Map<String,dynamic>>`, `.single()` a `Map<String,dynamic>`, `.maybeSingle()` a nullable map |

## If `flutter pub get` reports a conflict

```bash
flutter pub upgrade --major-versions      # then re-check the API notes above
```

or lower the floor to your installed toolchain, e.g. for Flutter 3.44:

```yaml
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
```

`go_router 18`, `flutter_riverpod 3.4` and `supabase_flutter 2.18` all work there —
only `google_fonts`-era packages that need Dart 3.13 would have to be dropped (none
are used).
