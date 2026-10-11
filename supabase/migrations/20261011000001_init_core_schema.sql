-- =====================================================================================
--  AeroNotes · Migration 1/2 · Core schema
-- =====================================================================================
--  Workspace  ->  Notebooks  ->  Pages  ->  Blocks
--                              Pages  ->  Attachments
--                              Pages  <-> Tags (page_tags)
--
--  Every content table carries `user_id`, `created_at` and `updated_at`.
--  Row Level Security is enabled on every table: a user can only ever touch
--  their own rows (`auth.uid() = user_id`).
--
--  Run with the Supabase CLI:
--      supabase db push
--  or paste the whole file into Dashboard -> SQL Editor -> Run.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 0. Extensions
-- -------------------------------------------------------------------------------------
create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- trigram indexes for ILIKE filters
create extension if not exists "unaccent";   -- accent-insensitive full text search

-- -------------------------------------------------------------------------------------
-- 1. Enums
-- -------------------------------------------------------------------------------------
-- NOTE: enums are created in `public` so PostgREST exposes them through the OpenAPI spec.
do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'block_type' and n.nspname = 'public') then
    create type public.block_type as enum (
      'paragraph', 'heading1', 'heading2', 'heading3',
      'bullet_list', 'numbered_list', 'checklist',
      'table', 'image', 'pdf', 'code', 'divider', 'callout', 'page'
    );
  end if;

  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'attachment_kind' and n.nspname = 'public') then
    create type public.attachment_kind as enum (
      'image', 'pdf', 'diagram', 'document', 'other'
    );
  end if;

  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where t.typname = 'notebook_role' and n.nspname = 'public') then
    create type public.notebook_role as enum ('owner', 'editor', 'viewer');
  end if;
end
$$;

-- -------------------------------------------------------------------------------------
-- 2. Generic helpers
-- -------------------------------------------------------------------------------------
-- Keeps `updated_at` fresh on every UPDATE (idempotent: never moves it backwards).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  if new.updated_at is null or new.updated_at < old.updated_at then
    new.updated_at := now();
  end if;
  return new;
end;
$$;

-- True when the row belongs to the caller. Used inside policies.
create or replace function public.is_own_uid(uid uuid)
returns boolean
language sql
stable
as $$
  select coalesce(uid = auth.uid(), false);
$$;

-- -------------------------------------------------------------------------------------
-- 3. profiles  (1:1 with auth.users)
-- -------------------------------------------------------------------------------------
create table if not exists public.profiles (
  id                uuid primary key references auth.users (id) on delete cascade,
  user_id           uuid not null default auth.uid(),
  email             text,
  full_name         text,
  avatar_url        text,
  theme_mode        text not null default 'system'
                    check (theme_mode in ('system', 'light', 'dark')),
  locale            text not null default 'en'
                    check (locale in ('en', 'ar')),
  is_email_verified boolean not null default false,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- `id` is the identity of the row; `user_id` exists so every table in the app
-- follows the same RLS shape. They are always equal here.
alter table public.profiles drop constraint if exists profiles_user_id_matches_id;
alter table public.profiles add constraint profiles_user_id_matches_id check (id = user_id);

create index if not exists profiles_email_idx on public.profiles (email);

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- Create the profile row the moment a user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (
    id, user_id, email, full_name, is_email_verified
  )
  values (
    new.id,
    new.id, -- user_id: set explicitly, `auth.uid()` is not available inside this trigger
    new.email,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      split_part(coalesce(new.email, ''), '@', 1)
    ),
    new.email_confirmed_at is not null
  )
  on conflict (id) do update
    set email             = excluded.email,
        is_email_verified = excluded.is_email_verified,
        updated_at        = now();

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert or update of email, email_confirmed_at, raw_user_meta_data
  on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated using (public.is_own_uid(id));

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check (public.is_own_uid(id));

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (public.is_own_uid(id))
  with check (public.is_own_uid(id));

-- No delete policy: profiles disappear through the FK cascade when the
-- auth.users row is deleted (Supabase Dashboard -> Authentication -> Users).

-- -------------------------------------------------------------------------------------
-- 4. notebooks
-- -------------------------------------------------------------------------------------
create table if not exists public.notebooks (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name        text not null check (char_length(trim(name)) between 1 and 60),
  icon        text,
  color       text check (color is null or color ~* '^#[0-9a-f]{6}$'),
  description text,
  position    integer not null default 0,
  is_archived boolean not null default false,
  pages_count integer not null default 0 check (pages_count >= 0),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists notebooks_user_idx
  on public.notebooks (user_id, is_archived, position, created_at desc);
create index if not exists notebooks_user_name_trgm_idx
  on public.notebooks using gin (name gin_trgm_ops);

create trigger trg_notebooks_updated_at
  before update on public.notebooks
  for each row execute function public.set_updated_at();

alter table public.notebooks enable row level security;

drop policy if exists "notebooks_select_own" on public.notebooks;
create policy "notebooks_select_own" on public.notebooks
  for select to authenticated using (public.is_own_uid(user_id));

drop policy if exists "notebooks_insert_own" on public.notebooks;
create policy "notebooks_insert_own" on public.notebooks
  for insert to authenticated with check (public.is_own_uid(user_id));

drop policy if exists "notebooks_update_own" on public.notebooks;
create policy "notebooks_update_own" on public.notebooks
  for update to authenticated
  using (public.is_own_uid(user_id))
  with check (public.is_own_uid(user_id));

drop policy if exists "notebooks_delete_own" on public.notebooks;
create policy "notebooks_delete_own" on public.notebooks
  for delete to authenticated using (public.is_own_uid(user_id));

-- -------------------------------------------------------------------------------------
-- 5. pages (nested through parent_page_id)
-- -------------------------------------------------------------------------------------
create table if not exists public.pages (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  notebook_id    uuid not null references public.notebooks (id) on delete cascade,
  parent_page_id uuid references public.pages (id) on delete cascade,

  title          text not null default '' check (char_length(title) <= 160),
  icon           text,
  cover_url      text,
  summary        text,
  template_key   text,

  -- Aviation specific metadata -------------------------------------------------
  aircraft_type  text check (aircraft_type is null or char_length(aircraft_type) <= 24),
  registration   text check (registration  is null or char_length(registration)  <= 12),
  ata_chapter    text check (ata_chapter   is null or ata_chapter ~ '^[0-9]{2,3}$'),
  airport_icao   text check (airport_icao  is null or airport_icao  ~ '^[A-Z]{4}$'),
  departure_icao text check (departure_icao is null or departure_icao ~ '^[A-Z]{4}$'),
  arrival_icao   text check (arrival_icao   is null or arrival_icao   ~ '^[A-Z]{4}$'),
  flight_date    date,

  position       integer not null default 0,
  is_archived    boolean not null default false,
  is_favorite    boolean not null default false,
  child_count    integer not null default 0 check (child_count >= 0),

  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),

  -- A page always belongs to the same user as its notebook.
  constraint pages_same_owner_as_notebook foreign key (notebook_id, user_id)
    references public.notebooks (id, user_id) on delete cascade
);

-- Required by the composite FK above.
create unique index if not exists notebooks_id_user_id_key on public.notebooks (id, user_id);

create index if not exists pages_notebook_idx
  on public.pages (notebook_id, parent_page_id, position);
create index if not exists pages_user_updated_idx
  on public.pages (user_id, updated_at desc);
create index if not exists pages_parent_idx
  on public.pages (parent_page_id);
create index if not exists pages_user_aircraft_idx
  on public.pages (user_id, aircraft_type);
create index if not exists pages_user_ata_idx
  on public.pages (user_id, ata_chapter);
create index if not exists pages_user_flight_date_idx
  on public.pages (user_id, flight_date desc);
create index if not exists pages_user_template_idx
  on public.pages (user_id, template_key);
create index if not exists pages_title_trgm_idx
  on public.pages using gin (title gin_trgm_ops);

create trigger trg_pages_updated_at
  before update on public.pages
  for each row execute function public.set_updated_at();

-- 5a. Refuse cycles in the page tree (a page can never become its own ancestor).
create or replace function public.assert_no_page_cycle()
returns boolean
language plpgsql
stable
as $$
declare
  current_id uuid := new.parent_page_id;
  depth      integer := 0;
begin
  if current_id is null then
    return true;
  end if;

  if current_id = new.id then
    raise exception 'A page cannot be its own parent (id=%)', new.id
      using errcode = '23514';
  end if;

  while current_id is not null and depth < 64 loop
    select p.parent_page_id into current_id
    from public.pages p
    where p.id = current_id;

    if current_id = new.id then
      raise exception 'Moving this page would create a cycle in the page tree'
        using errcode = '23514';
    end if;

    depth := depth + 1;
  end loop;

  if depth >= 64 then
    raise exception 'Page tree is too deep (limit 64 levels)'
      using errcode = '23514';
  end if;

  return true;
end;
$$;

create or replace function public.check_page_parent()
returns trigger
language plpgsql
as $$
begin
  perform public.assert_no_page_cycle();
  return new;
end;
$$;

drop trigger if exists trg_pages_no_cycle on public.pages;
create trigger trg_pages_no_cycle
  before insert or update of parent_page_id on public.pages
  for each row execute function public.check_page_parent();

-- 5b. Keep `child_count` and `notebooks.pages_count` in sync.
create or replace function public.bump_page_parent_child_count()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op in ('INSERT', 'UPDATE') and new.parent_page_id is not null then
    update public.pages
       set child_count = child_count + 1
     where id = new.parent_page_id;
  end if;

  if tg_op in ('DELETE', 'UPDATE') and old.parent_page_id is not null then
    update public.pages
       set child_count = greatest(child_count - 1, 0)
     where id = old.parent_page_id;
  end if;

  if tg_op = 'INSERT' then
    return new;
  elsif tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_pages_child_count on public.pages;
create trigger trg_pages_child_count
  after insert or delete or update of parent_page_id on public.pages
  for each row execute function public.bump_page_parent_child_count();

create or replace function public.bump_notebook_pages_count()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    update public.notebooks
       set pages_count = pages_count + 1,
           updated_at  = now()
     where id = new.notebook_id;
    return new;
  end if;

  if tg_op = 'DELETE' then
    update public.notebooks
       set pages_count = greatest(pages_count - 1, 0),
           updated_at  = now()
     where id = old.notebook_id;
    return old;
  end if;

  -- UPDATE: only a notebook move changes the counters.
  if old.notebook_id <> new.notebook_id then
    update public.notebooks
       set pages_count = greatest(pages_count - 1, 0),
           updated_at  = now()
     where id = old.notebook_id;

    update public.notebooks
       set pages_count = pages_count + 1,
           updated_at  = now()
     where id = new.notebook_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_pages_notebook_count on public.pages;
create trigger trg_pages_notebook_count
  after insert or delete or update of notebook_id on public.pages
  for each row execute function public.bump_notebook_pages_count();

-- 5c. RLS
alter table public.pages enable row level security;

drop policy if exists "pages_select_own" on public.pages;
create policy "pages_select_own" on public.pages
  for select to authenticated using (public.is_own_uid(user_id));

drop policy if exists "pages_insert_own" on public.pages;
create policy "pages_insert_own" on public.pages
  for insert to authenticated with check (public.is_own_uid(user_id));

drop policy if exists "pages_update_own" on public.pages;
create policy "pages_update_own" on public.pages
  for update to authenticated
  using (public.is_own_uid(user_id))
  with check (public.is_own_uid(user_id));

drop policy if exists "pages_delete_own" on public.pages;
create policy "pages_delete_own" on public.pages
  for delete to authenticated using (public.is_own_uid(user_id));

-- -------------------------------------------------------------------------------------
-- 6. blocks (page content)
-- -------------------------------------------------------------------------------------
create table if not exists public.blocks (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users (id) on delete cascade,
  page_id         uuid not null references public.pages (id) on delete cascade,
  parent_block_id uuid references public.blocks (id) on delete cascade,

  type            public.block_type not null default 'paragraph',
  content         text,
  props           jsonb not null default '{}'::jsonb,
  is_checked      boolean,
  language        text,
  position        integer not null default 0,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  constraint blocks_same_owner_as_page foreign key (page_id, user_id)
    references public.pages (id, user_id) on delete cascade,
  constraint blocks_checklist_flag check (type <> 'checklist' or is_checked is not null)
);

create unique index if not exists blocks_id_user_id_key on public.blocks (id, user_id);
create index if not exists blocks_page_idx on public.blocks (page_id, position);
create index if not exists blocks_user_updated_idx on public.blocks (user_id, updated_at desc);
create index if not exists blocks_parent_idx on public.blocks (parent_block_id);
create index if not exists blocks_type_idx on public.blocks (page_id, type);

create trigger trg_blocks_updated_at
  before update on public.blocks
  for each row execute function public.set_updated_at();

alter table public.blocks enable row level security;

drop policy if exists "blocks_select_own" on public.blocks;
create policy "blocks_select_own" on public.blocks
  for select to authenticated using (public.is_own_uid(user_id));

drop policy if exists "blocks_insert_own" on public.blocks;
create policy "blocks_insert_own" on public.blocks
  for insert to authenticated with check (public.is_own_uid(user_id));

drop policy if exists "blocks_update_own" on public.blocks;
create policy "blocks_update_own" on public.blocks
  for update to authenticated
  using (public.is_own_uid(user_id))
  with check (public.is_own_uid(user_id));

drop policy if exists "blocks_delete_own" on public.blocks;
create policy "blocks_delete_own" on public.blocks
  for delete to authenticated using (public.is_own_uid(user_id));

-- -------------------------------------------------------------------------------------
-- 7. tags + page_tags
-- -------------------------------------------------------------------------------------
create table if not exists public.tags (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name         text not null check (char_length(trim(name)) between 1 and 32),
  color        text check (color is null or color ~* '^#[0-9a-f]{6}$'),
  usage_count  integer not null default 0 check (usage_count >= 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create unique index if not exists tags_user_name_key
  on public.tags (user_id, lower(trim(name)));
create index if not exists tags_user_usage_idx
  on public.tags (user_id, usage_count desc, created_at desc);

create trigger trg_tags_updated_at
  before update on public.tags
  for each row execute function public.set_updated_at();

create table if not exists public.page_tags (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
  page_id    uuid not null references public.pages (id) on delete cascade,
  tag_id     uuid not null references public.tags (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint page_tags_same_owner_as_page foreign key (page_id, user_id)
    references public.pages (id, user_id) on delete cascade,
  constraint page_tags_same_owner_as_tag foreign key (tag_id, user_id)
    references public.tags (id, user_id) on delete cascade,
  constraint page_tags_unique unique (page_id, tag_id)
);

create index if not exists page_tags_tag_idx on public.page_tags (tag_id);
create index if not exists page_tags_user_idx on public.page_tags (user_id, created_at desc);

create trigger trg_page_tags_updated_at
  before update on public.page_tags
  for each row execute function public.set_updated_at();

create or replace function public.bump_tag_usage_count()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    update public.tags set usage_count = usage_count + 1 where id = new.tag_id;
    return new;
  end if;

  if tg_op = 'DELETE' then
    update public.tags
       set usage_count = greatest(usage_count - 1, 0)
     where id = old.tag_id;
    return old;
  end if;

  -- UPDATE (re-tagging): decrement the old tag, increment the new one.
  if old.tag_id <> new.tag_id then
    update public.tags set usage_count = greatest(usage_count - 1, 0) where id = old.tag_id;
    update public.tags set usage_count = usage_count + 1 where id = new.tag_id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_page_tags_count on public.page_tags;
create trigger trg_page_tags_count
  after insert or delete or update of tag_id on public.page_tags
  for each row execute function public.bump_tag_usage_count();

-- When a tag is deleted its `page_tags` rows cascade, so the counter of the
-- deleted tag is irrelevant; no extra trigger needed.

alter table public.tags enable row level security;

drop policy if exists "tags_select_own" on public.tags;
create policy "tags_select_own" on public.tags
  for select to authenticated using (public.is_own_uid(user_id));

drop policy if exists "tags_insert_own" on public.tags;
create policy "tags_insert_own" on public.tags
  for insert to authenticated with check (public.is_own_uid(user_id));

drop policy if exists "tags_update_own" on public.tags;
create policy "tags_update_own" on public.tags
  for update to authenticated
  using (public.is_own_uid(user_id))
  with check (public.is_own_uid(user_id));

drop policy if exists "tags_delete_own" on public.tags;
create policy "tags_delete_own" on public.tags
  for delete to authenticated using (public.is_own_uid(user_id));

alter table public.page_tags enable row level security;

drop policy if exists "page_tags_select_own" on public.page_tags;
create policy "page_tags_select_own" on public.page_tags
  for select to authenticated using (public.is_own_uid(user_id));

drop policy if exists "page_tags_insert_own" on public.page_tags;
create policy "page_tags_insert_own" on public.page_tags
  for insert to authenticated with check (public.is_own_uid(user_id));

drop policy if exists "page_tags_update_own" on public.page_tags;
create policy "page_tags_update_own" on public.page_tags
  for update to authenticated
  using (public.is_own_uid(user_id))
  with check (public.is_own_uid(user_id));

drop policy if exists "page_tags_delete_own" on public.page_tags;
create policy "page_tags_delete_own" on public.page_tags
  for delete to authenticated using (public.is_own_uid(user_id));

-- -------------------------------------------------------------------------------------
-- 8. attachments (Storage metadata)
-- -------------------------------------------------------------------------------------
create table if not exists public.attachments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  page_id       uuid references public.pages (id) on delete cascade,
  block_id      uuid references public.blocks (id) on delete cascade,

  bucket_id     text not null default 'attachments',
  storage_path  text not null check (char_length(storage_path) > 0),
  file_name     text not null check (char_length(file_name) > 0),
  mime_type     text,
  kind          public.attachment_kind not null default 'other',
  size_bytes    bigint not null default 0 check (size_bytes >= 0),
  width         integer,
  height        integer,
  checksum      text,

  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),

  constraint attachments_same_owner_as_page foreign key (page_id, user_id)
    references public.pages (id, user_id) on delete cascade,
  constraint attachments_unique_path unique (bucket_id, storage_path)
);

create index if not exists attachments_page_idx on public.attachments (page_id, created_at desc);
create index if not exists attachments_user_idx on public.attachments (user_id, created_at desc);
create index if not exists attachments_kind_idx on public.attachments (user_id, kind);

create trigger trg_attachments_updated_at
  before update on public.attachments
  for each row execute function public.set_updated_at();

alter table public.attachments enable row level security;

drop policy if exists "attachments_select_own" on public.attachments;
create policy "attachments_select_own" on public.attachments
  for select to authenticated using (public.is_own_uid(user_id));

drop policy if exists "attachments_insert_own" on public.attachments;
create policy "attachments_insert_own" on public.attachments
  for insert to authenticated with check (public.is_own_uid(user_id));

drop policy if exists "attachments_update_own" on public.attachments;
create policy "attachments_update_own" on public.attachments
  for update to authenticated
  using (public.is_own_uid(user_id))
  with check (public.is_own_uid(user_id));

drop policy if exists "attachments_delete_own" on public.attachments;
create policy "attachments_delete_own" on public.attachments
  for delete to authenticated using (public.is_own_uid(user_id));

-- Deleting the Storage object does NOT happen from a trigger on purpose:
-- deleting inside `storage.objects` from a `public` trigger would need a
-- SECURITY DEFINER function with access to another user's schema. The Flutter
-- client removes the object first (`storage.from(bucket).remove([path])`) and
-- then deletes this row (Stage C).

-- -------------------------------------------------------------------------------------
-- 9. Storage bucket + storage.objects policies
-- -------------------------------------------------------------------------------------
-- Layout convention enforced by the policies below:
--     attachments/<user-uuid>/<page-uuid>/<file-uuid>-<name>.png
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  false,                                   -- private: the app uses signed URLs
  52428800,                                -- 50 MB per file
  array[
    'image/png', 'image/jpeg', 'image/webp', 'image/gif', 'image/heic',
    'application/pdf',
    'text/plain', 'text/csv', 'application/json',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  ]
)
on conflict (id) do update
  set public            = excluded.public,
      file_size_limit   = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- The first path segment must be the caller's uuid.
drop policy if exists "attachments_storage_select_own" on storage.objects;
create policy "attachments_storage_select_own" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "attachments_storage_insert_own" on storage.objects;
create policy "attachments_storage_insert_own" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "attachments_storage_update_own" on storage.objects;
create policy "attachments_storage_update_own" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "attachments_storage_delete_own" on storage.objects;
create policy "attachments_storage_delete_own" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- -------------------------------------------------------------------------------------
-- 10. Grants
-- -------------------------------------------------------------------------------------
grant usage on schema public to anon, authenticated, service_role;
grant all on all tables in schema public to anon, authenticated, service_role;
grant all on all sequences in schema public to anon, authenticated, service_role;
grant usage on all sequences in schema public to authenticated;
grant usage on type public.block_type to anon, authenticated, service_role;
grant usage on type public.attachment_kind to anon, authenticated, service_role;
grant usage on type public.notebook_role to anon, authenticated, service_role;

-- Anything created later in `public` is usable by the API roles as well.
alter default privileges in schema public
  grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema public
  grant execute on functions to anon, authenticated, service_role;
