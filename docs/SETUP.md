# Setup guide — Supabase + Flutter

## 0. Toolchain

```bash
flutter --version     # 3.47.x stable (Dart 3.13.x)
flutter doctor
```

Why 3.47 / Dart 3.13: see [`VERSIONS.md`](VERSIONS.md) — the pinned packages
(go_router 18, flutter_riverpod 3.4, google_fonts-era Material widgets such as
`RadioGroup`) raise the floor to Flutter 3.44–3.47.

## 1. Generate the platform folders

The repository ships source only (`lib/`, `assets/`, `supabase/`, `docs/`, `test/`).

```bash
cd Su35
flutter create . --project-name avnotes --org app.aeronotes \
  --platforms=android,ios,web,linux,macos,windows
```

`flutter create .` only adds what is missing; it will not touch `lib/` or `pubspec.yaml`.

Then:

```bash
flutter pub get
```

## 2. Create the Supabase project

1. <https://supabase.com/dashboard> → **New project**.
2. Note the **project ref** (the subdomain of your project URL).
3. Keep the generated DB password somewhere safe (the app never needs it).

## 3. Apply the database schema

### Option A — Dashboard SQL Editor

Run the two files **in order** (each one is idempotent, so re-running is safe):

1. `supabase/migrations/20261011000001_init_core_schema.sql`
2. `supabase/migrations/20261011000002_search_and_templates.sql`

### Option B — Supabase CLI

```bash
brew install supabase/tap/supabase        # or: npm i -g supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

### What the migrations create

| Object | Purpose |
| ------ | ------- |
| `public.profiles` | 1:1 with `auth.users`, auto-created by the `handle_new_user` trigger; stores `theme_mode` + `locale` |
| `public.notebooks` | workspace folders; `pages_count` kept by trigger |
| `public.pages` | pages + nested pages (`parent_page_id`, cycle-proof) + aviation metadata (`aircraft_type`, `registration`, `ata_chapter`, `airport_icao`, `departure_icao`, `arrival_icao`, `flight_date`) |
| `public.blocks` | content units (`paragraph`, `heading1..3`, `bullet_list`, `numbered_list`, `checklist`, `table`, `image`, `pdf`, `code`, `divider`, `callout`, `page`) |
| `public.tags` / `public.page_tags` | tags + many-to-many link, `usage_count` kept by trigger |
| `public.attachments` | Storage metadata (bucket, path, mime, kind, size, dimensions) |
| `public.page_templates` | the 5 aviation templates |
| `pages.search_vector` | STORED generated `tsvector` (title A · summary B · aviation fields C · block text D) + GIN index |
| `public.search_pages(...)` | ranked full-text search with `ts_headline` snippets, optional aircraft/ATA/notebook filters |
| `public.search_page_titles(...)` | trigram title autocomplete |
| `public.seed_template_blocks()` | trigger: inserting a page with `template_key` seeds its blocks automatically |
| `public.page_search`, `public.pages_with_tags` | `security_invoker` views |
| `storage.buckets.attachments` | private bucket, 50 MB limit, image/PDF/office mime allow-list |

### Row Level Security (all of it, spelled out)

Every table: `alter table … enable row level security;` plus

```sql
create policy "x_select_own" on public.x for select to authenticated using  (public.is_own_uid(user_id));
create policy "x_insert_own" on public.x for insert to authenticated with check (public.is_own_uid(user_id));
create policy "x_update_own" on public.x for update to authenticated using (public.is_own_uid(user_id)) with check (public.is_own_uid(user_id));
create policy "x_delete_own" on public.x for delete to authenticated using (public.is_own_uid(user_id));
```

`public.is_own_uid(uid)` is `coalesce(uid = auth.uid(), false)` — an anonymous
request therefore matches nothing. `profiles` uses `id` (its own PK) instead of
`user_id`, and has no delete policy (the auth cascade handles it).

Storage policies require the first path segment to be the caller's uuid:

```
attachments/<user-uuid>/<page-uuid>/<file-uuid>-<name>.png
```

Cross-user safety is reinforced by composite foreign keys
(`pages(notebook_id, user_id) → notebooks(id, user_id)`, same for blocks,
page_tags and attachments), so it is impossible to attach content to somebody
else's page even with a hand-crafted request.

## 4. Configure the app secrets

```bash
cp .env.example assets/env/.env
```

| Variable | Where to find it |
| -------- | ---------------- |
| `SUPABASE_URL` | Project Settings → API → Project URL |
| `SUPABASE_ANON_KEY` | Project Settings → API → **anon** **public** (JWT, starts with `eyJ`) |
| `SUPABASE_PUBLISHABLE_KEY` | Project Settings → API Keys → **publishable** (starts with `sb_publishable_`) |
| `SUPABASE_STORAGE_BUCKET` | `attachments` (matches the migration) |

`assets/env/.env` is in `.gitignore`. The app refuses to boot (and shows a
self-explanatory configuration screen) while the placeholders are still there.

## 5. Auth settings

* **Authentication → Providers → Email** → *Enable*.
* **Confirm email**:
  * *enabled* → `signUp` returns no session; the app shows “Check your email”
    and pre-fills the sign-in form.
  * *disabled* → `signUp` returns a session and the router redirects straight to
    `/home`. Both paths are implemented.
* Optional deep linking (password reset / OAuth) later:
  **Authentication → URL Configuration** → Site URL `https://<your-domain>` and
  add your app scheme to *Redirect URLs*.

## 6. Run

```bash
flutter run -d chrome        # fastest smoke test
flutter run                  # device/emulator
flutter test                 # unit tests (models, validators, env guard)
```

First-run checklist:

1. Create an account → a row appears in **Table Editor → profiles**.
2. Create a notebook → row in `notebooks`, `pages_count = 0`.
3. Create a page with the *Pre-flight Checklist* template → rows appear in
   `pages` **and** `blocks` (the trigger seeded them), and the viewer renders
   the checklist.
4. Toggle dark mode and switch to Arabic → the whole UI flips to RTL.
5. Sign out → you are redirected to `/auth` and the providers drop their data.

## 7. Troubleshooting

| Symptom | Cause / fix |
| ------- | ----------- |
| Red “Supabase is not configured yet” screen | `assets/env/.env` missing, not declared in `pubspec.yaml`, or still holding `YOUR-PROJECT-REF` / `YOUR-ANON-KEY`. |
| `AuthException: Invalid login credentials` | Wrong password, or the account exists with a different email case. Emails are lower-cased before sending. |
| Sign-up succeeds but you cannot sign in | Email confirmation is ON — open the confirmation link first. |
| `PostgrestException 42501 / row-level security policy` | The row's `user_id` is not your `auth.uid()` (e.g. data inserted from the SQL editor without a user). Client inserts always send `user_id`, so this normally means the migrations were only partially applied. |
| `relation "public.pages" does not exist` | Migration 1 was not run in that project/schema. |
| `function public.search_pages(...) does not exist` | Migration 2 was not run. |
| Notebook card shows `0 pages` after deleting a page tree | Run `select public.recount_all_counters();` (self-healing utility). |
| Uploads fail with 400 | Bucket mime/size limits: max 50 MB, images/PDF/office only, path must start with your uuid. |
| Arabic shows as boxes on Linux desktop | Install an Arabic-capable font (`fonts-noto-core`) or bundle one in `assets/fonts` and set `fontFamily` in `AppTheme`. |
| `flutter pub get` complains about the SDK | Your Flutter is older than 3.44; `flutter upgrade` or relax the constraints per `docs/VERSIONS.md`. |
