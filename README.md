# AeroNotes ✈️ — Aviation notes workspace (Flutter + Supabase)

A Notion-style notes app specialised for aircraft & aviation: notebooks → pages → blocks,
nested pages, aviation metadata (aircraft type, registration, ATA chapter, ICAO, date),
templates (Flight Log, Maintenance, Pre-flight Checklist, Theory Lesson, Defect Report),
tags, full-text search, attachments and PDF export — with offline support.

| Layer        | Choice                                                                     |
| ------------ | -------------------------------------------------------------------------- |
| UI           | Flutter (stable), Material 3, **English + Arabic with full RTL**            |
| State        | **Riverpod 3** (`Notifier` / `AsyncNotifier`, no codegen)                   |
| Routing      | **go_router 18** (declarative + auth `redirect`)                            |
| Backend      | **Supabase**: Auth, Postgres (+ RLS), Storage, Realtime                     |
| Rich text    | flutter_quill *(Stage B)*                                                   |
| Offline      | Drift + later sync *(Stage D)*                                              |
| Secrets      | `flutter_dotenv` — **no key is ever hard-coded in Dart**                    |

---

## Delivery stages

| Stage | Scope | Status |
| ----- | ----- | ------ |
| **A** | Auth (sign in / sign up / reset / sign out), Notebooks, Pages (nested), aviation metadata fields, settings (dark mode + EN/AR RTL), **complete SQL schema with RLS + FTS**, project skeleton | ✅ **this delivery** |
| **B** | Block editor: rich text, headings, checklists, tables, code, dividers, images, PDF attachments, auto-save | ⏳ next |
| **C** | Templates gallery UI, tags + filters (aircraft / ATA), global search screen, attachment manager, PDF export | ⏳ |
| **D** | Drift local cache, offline-first reads/writes, conflict-aware sync queue, realtime | ⏳ |

> The database schema delivered in Stage A already contains everything Stages B–D need
> (`blocks`, `tags`, `page_tags`, `attachments`, `search_pages()`, template seeding),
> so later stages do **not** require destructive migrations.

---

## 1. Prerequisites

```bash
flutter --version        # Flutter 3.47 stable / Dart 3.13 (see docs/VERSIONS.md)
dart --version
supabase --version       # optional: only needed for `supabase db push`
```

Create the Flutter platform folders if you cloned only the source tree:

```bash
cd Su35
flutter create . --project-name avnotes --org app.aeronotes --platforms=android,ios,web,linux,macos,windows
```

`flutter create .` **does not** overwrite `lib/`, `pubspec.yaml`, `assets/`, `docs/`
or `supabase/`; it only adds the missing `android/`, `ios/`, `web/`, … directories.

---

## 2. Connect Supabase (5 minutes)

1. **Create the project** — <https://supabase.com/dashboard> → *New project*.
   Pick a strong DB password and the region closest to you.

2. **Run the SQL** — two options:

   *Dashboard* → SQL Editor → paste and run, **in this order**:
   1. `supabase/migrations/20261011000001_init_core_schema.sql`
   2. `supabase/migrations/20261011000002_search_and_templates.sql`

   *or CLI*:

   ```bash
   supabase login
   supabase link --project-ref <your-project-ref>
   supabase db push          # applies every file in supabase/migrations
   ```

3. **Create the `.env`** (this file is git-ignored):

   ```bash
   cp .env.example assets/env/.env
   ```

   Then fill it from *Dashboard → Project Settings → API*:

   ```dotenv
   SUPABASE_URL=https://<your-project-ref>.supabase.co
   SUPABASE_ANON_KEY=<anon public key>          # legacy projects (JWT starting with eyJ…)
   SUPABASE_PUBLISHABLE_KEY=                    # new projects (sb_publishable_…)
   SUPABASE_STORAGE_BUCKET=attachments
   ```

   * If your project shows **publishable / secret** keys, put the publishable key in
     `SUPABASE_PUBLISHABLE_KEY` — the app prefers it and avoids the deprecated
     `anonKey:` parameter.
   * Never put the `service_role`/secret key in the app. All security comes from RLS.

4. **Auth settings** — *Authentication → Providers → Email*:
   * enable **Email**,
   * for a quick local test you may disable **Confirm email** (sign-up then returns a
     session immediately); with confirmation enabled the app shows a
     "check your email" dialog — both paths are handled.

5. **Verify the schema** — *Database → Tables* should list:
   `profiles`, `notebooks`, `pages`, `blocks`, `tags`, `page_tags`, `attachments`,
   `page_templates`, plus the views `page_search` and `pages_with_tags`.
   *Authentication → Policies* should show 4 policies per content table
   (select/insert/update/delete) and 4 for `storage.objects`.

---

## 3. Run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # only needed from Stage D on
flutter run                                                # or: flutter run -d chrome
```

First launch → **Create account** → the `handle_new_user` trigger creates your
`profiles` row → you land on the notebooks screen.

### Smoke test

```bash
flutter test
```

`test/models_test.dart` covers JSON parsing of every model, the validators
(email / password / ICAO / registration / ATA) and the `.env` guard that refuses
to boot with placeholder credentials.

---

## 4. Folder structure (feature-first)

```
Su35/
├── .env.example                     # template, committed
├── assets/env/.env                  # real keys, git-ignored
├── docs/
│   ├── SETUP.md                     # Supabase wiring, troubleshooting, SQL checklist
│   ├── FOLDER_STRUCTURE.md          # full tree + what belongs where per stage
│   └── VERSIONS.md                  # verified package versions & why
├── supabase/migrations/
│   ├── 20261011000001_init_core_schema.sql
│   └── 20261011000002_search_and_templates.sql
├── lib/
│   ├── main.dart                    # bootstrap: dotenv → Supabase → ProviderContainer → app
│   └── src/
│       ├── app/                     # root widget, provider observers, config error screen
│       ├── core/                    # constants, env, errors, l10n (EN/AR), theme, utils
│       ├── data/                    # models, repositories (+ Supabase impls), providers
│       ├── features/
│       │   ├── auth/                # providers, screens (sign in / sign up), widgets
│       │   ├── notebooks/           # home screen, notebook card, create/edit sheet
│       │   ├── pages/               # pages tree screen, page viewer, page sheet, tile
│       │   └── settings/            # theme + language + account + about
│       ├── router/                  # go_router config, auth redirect, splash, 404
│       └── shared/widgets/          # AsyncStateView, EmptyStateView, dialogs, snackbars…
└── test/
```

Full details in **[`docs/FOLDER_STRUCTURE.md`](docs/FOLDER_STRUCTURE.md)**.

---

## 5. Architecture notes

* **Repositories, not screens, talk to Supabase.** Every Supabase call lives in
  `data/repositories/supabase_*` and throws `AppFailure` (a single UI-friendly error
  type). Stage D swaps these implementations for Drift-backed ones without touching
  a single widget.
* **Errors & loading are handled everywhere.** `AsyncStateView` renders
  loading / error(+retry+technical details) / data / empty from one `AsyncValue`, so
  no screen can forget a state.
* **Localization** is plain Dart maps (`AppTranslations.english` / `.arabic`) plus the
  Flutter Global\* delegates for Material widgets, date pickers and RTL. Switching to
  Arabic flips the whole UI (`Directionality`) — ICAO codes, registrations and ATA
  chapters are pinned to LTR with explicit `Directionality` widgets.
* **Security** = RLS. Every policy is `auth.uid() = user_id`; Storage objects must live
  under `<user-uuid>/…`. The client sends `user_id` explicitly on inserts so the
  `WITH CHECK` policy always matches.
* **Denormalised counters** (`notebooks.pages_count`, `pages.child_count`,
  `tags.usage_count`) and the **search vector** (`pages.search_vector`) are maintained
  by triggers, so the app never has to count or re-index client-side.

---

## 6. What Stage B will add

`features/editor/` (flutter_quill document, block toolbar, auto-save with the
`AppConstants.autosaveDebounce` debounce), image/PDF upload through
`SupabaseStorageClient` into `attachments/<uid>/<pageId>/…`, and the
`attachments` UI. The read-only `PageViewerScreen` from Stage A is replaced by
`PageEditorScreen` behind the same route.

Say the word and Stage B starts.
