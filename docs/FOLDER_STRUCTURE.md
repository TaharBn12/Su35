# Folder structure (feature-first)

```
Su35/
│
├── .env.example                                  # committed template
├── .gitignore                                    # ignores assets/env/.env, build output, *.g.dart
├── analysis_options.yaml                         # flutter_lints 6 + strict-casts/inference
├── pubspec.yaml                                  # pinned, version-verified dependencies
├── README.md
│
├── assets/
│   └── env/
│       └── .env                                  # ⚠ git-ignored – real Supabase URL + key
│
├── docs/
│   ├── FOLDER_STRUCTURE.md                       # this file
│   ├── SETUP.md                                  # Supabase wiring + troubleshooting
│   └── VERSIONS.md                               # verified package versions
│
├── supabase/
│   ├── config.toml                               # optional, for `supabase start` / `db push`
│   └── migrations/
│       ├── 20261011000001_init_core_schema.sql   # tables, enums, triggers, RLS, storage
│       └── 20261011000002_search_and_templates.sql # tsvector, search_pages(), templates
│
├── lib/
│   ├── main.dart                                 # bootstrap (env → Supabase → container → app)
│   │
│   └── src/
│       ├── app/
│       │   ├── app.dart                          # AvnotesApp: theme + l10n + routerConfig
│       │   └── configuration_error_screen.dart   # shown when .env is missing/placeholder
│       │
│       ├── core/                                 # no feature may be imported from here
│       │   ├── constants/app_constants.dart      # table names, block types, ATA chapters, aircraft
│       │   ├── env/app_env.dart                  # dotenv loader + validation (EnvNotConfiguredException)
│       │   ├── errors/app_failure.dart           # AppFailure + toAppFailure(Object) mapper
│       │   ├── localization/app_localizations.dart # AppLocalizations, delegate, EN + AR maps
│       │   ├── theme/app_theme.dart              # Material 3 light/dark, notebook palette
│       │   └── utils/
│       │       ├── json_utils.dart               # defensive PostgREST row parsing
│       │       └── validators.dart               # email/password/ICAO/registration/ATA validators
│       │
│       ├── data/
│       │   ├── supabase_providers.dart           # supabaseClientProvider (+ auth/storage)
│       │   ├── data_providers.dart               # read providers (families) + CollectionMutations
│       │   ├── models/
│       │   │   ├── app_user.dart                 # profiles row
│       │   │   ├── notebook.dart
│       │   │   ├── page.dart                     # NotePage (incl. aviation metadata)
│       │   │   └── page_block.dart
│       │   └── repositories/
│       │       ├── auth_repository.dart          # interface
│       │       ├── supabase_auth_repository.dart
│       │       ├── notebooks_repository.dart     # interface
│       │       ├── supabase_notebooks_repository.dart
│       │       ├── pages_repository.dart         # interface (+ PageSearchResult)
│       │       ├── supabase_pages_repository.dart
│       │       ├── blocks_repository.dart        # interface (used by Stage B)
│       │       ├── supabase_blocks_repository.dart
│       │       └── supabase_profiles_repository.dart
│       │
│       ├── features/
│       │   ├── auth/
│       │   │   ├── providers/auth_providers.dart # AuthStatus sealed type, session, auth repo
│       │   │   ├── screens/
│       │   │   │   ├── auth_screen.dart          # hosts both modes on the single /auth route
│       │   │   │   ├── sign_in_form.dart
│       │   │   │   └── sign_up_form.dart
│       │   │   └── widgets/auth_scaffold.dart    # shared chrome + language toggle
│       │   │
│       │   ├── notebooks/
│       │   │   ├── screens/home_screen.dart      # workspace root (notebook list)
│       │   │   └── widgets/
│       │   │       ├── notebook_card.dart
│       │   │       └── notebook_dialogs.dart     # create/edit sheet + submit helper
│       │   │
│       │   ├── pages/
│       │   │   ├── screens/
│       │   │   │   ├── pages_screen.dart         # collapsible tree of nested pages
│       │   │   │   └── page_viewer_screen.dart   # read-only view (replaced in Stage B)
│       │   │   └── widgets/
│       │   │       ├── page_dialogs.dart         # create/rename/metadata sheet
│       │   │       └── page_tile.dart
│       │   │
│       │   ├── settings/
│       │   │   ├── providers/
│       │   │   │   ├── settings_provider.dart    # SettingsController (theme + locale, persisted)
│       │   │   │   └── profile_provider.dart     # profiles row + updates
│       │   │   └── screens/settings_screen.dart
│       │   │
│       │   │  ── Stage B ──────────────────────────────────────────────
│       │   ├── editor/                           # quill document ↔ blocks mapping, toolbar,
│       │   │   ├── screens/page_editor_screen.dart   # auto-save, checklists, tables, code
│       │   │   └── widgets/…
│       │   │  ── Stage C ──────────────────────────────────────────────
│       │   ├── templates/                        # template gallery (page_templates table)
│       │   ├── tags/                             # tag editor, tag chips, tag filters
│       │   ├── search/                           # global search screen (search_pages RPC)
│       │   ├── attachments/                      # upload/preview images + PDF (signed URLs)
│       │   └── export/                           # page → PDF (pdf + printing)
│       │   │  ── Stage D ──────────────────────────────────────────────
│       │   └── sync/                             # offline queue, conflict resolution, realtime
│       │
│       ├── local/                                # Stage D: Drift database
│       │   ├── tables/…                          # mirrors of notebooks/pages/blocks/…
│       │   ├── app_database.dart                 # @DriftDatabase
│       │   ├── app_database.g.dart               # generated (build_runner)
│       │   ├── local_*_repository.dart           # cache-first implementations
│       │   └── sync/sync_service.dart            # pending-changes queue → Supabase
│       │
│       ├── router/app_router.dart                # AppRoutes, GoRouter, redirect, splash, 404
│       │
│       └── shared/
│           └── widgets/
│               ├── app_dialogs.dart              # confirm / info dialogs
│               ├── app_logo.dart
│               ├── app_snackbars.dart            # success / info / error (localized)
│               ├── app_text_field.dart           # label + translated validator key
│               ├── async_state_view.dart         # loading / error(+retry) / data / empty
│               └── empty_state_view.dart
│
└── test/
    ├── fixtures/.env.test                        # fake credentials for the env test
    └── models_test.dart                          # parsing, validators, env guard
```

## Dependency rules

```
features  →  data  →  core
   ↘          ↘
     shared      router
```

* `core/` imports **nothing** from the app (only packages).
* `data/` may import `core/`, never `features/` or `shared/`.
* `features/` may import `core/`, `data/`, `shared/` — and never another feature's
  *screens* (providers are fine, e.g. `pages` reads `notebooksProvider`).
* `router/` is the only place allowed to know every feature's entry screen.

Keeping these arrows one-directional is what lets Stage D replace `data/` with a
Drift-backed implementation without touching a single widget.
