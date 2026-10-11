-- =====================================================================================
--  AeroNotes · Migration 2/2 · Full-text search, template seeding, helper views
-- =====================================================================================
--  Depends on: 20261011000001_init_core_schema.sql
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- 1. Search columns (tsvector) --------------------------------------------------------
-- -------------------------------------------------------------------------------------
-- `pages.search_vector` is a STORED GENERATED column combining:
--    A · title          (weight A - most important)
--    B · summary        (weight B)
--    C · aircraft type, registration, ATA chapter, ICAO codes, template key
--    D · every text block of the page (maintained by trg_blocks_sync_page_search)
--
-- 'simple' is used as the text-search configuration on purpose: it is language
-- independent, so Arabic notes are searchable too (Arabic stemming would need
-- a dedicated extension that hosted Supabase does not ship).

alter table public.pages
  add column if not exists blocks_text text not null default '',
  add column if not exists search_vector tsvector
    generated always as (
      setweight(to_tsvector('simple', coalesce(title, '')), 'A')
      || setweight(to_tsvector('simple', coalesce(summary, '')), 'B')
      || setweight(
           to_tsvector('simple',
             coalesce(aircraft_type, '') || ' ' ||
             coalesce(registration, '') || ' ' ||
             coalesce(ata_chapter, '') || ' ' ||
             coalesce(airport_icao, '') || ' ' ||
             coalesce(departure_icao, '') || ' ' ||
             coalesce(arrival_icao, '') || ' ' ||
             coalesce(template_key, '')
           ), 'C')
      || setweight(to_tsvector('simple', coalesce(blocks_text, '')), 'D')
    ) stored;

create index if not exists pages_search_vector_idx
  on public.pages using gin (search_vector);

-- Trigram index for "starts with / fuzzy" title search in the UI.
create index if not exists pages_blocks_text_trgm_idx
  on public.pages using gin (blocks_text gin_trgm_ops);

-- Rebuild `pages.blocks_text` (and therefore `search_vector`) from the blocks.
create or replace function public.refresh_page_search(p_page_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  aggregated text;
begin
  select coalesce(string_agg(coalesce(b.content, ''), ' ' order by b.position), '')
    into aggregated
  from public.blocks b
  where b.page_id = p_page_id
    and b.parent_block_id is null
    and b.content is not null
    and b.type <> 'divider';

  update public.pages
     set blocks_text = coalesce(aggregated, '')
   where id = p_page_id;
end;
$$;

-- Any content change keeps the parent page's search vector (and updated_at) fresh.
create or replace function public.sync_page_search_from_block()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_page uuid;
begin
  if tg_op = 'DELETE' then
    target_page := old.page_id;
  else
    target_page := new.page_id;
  end if;

  perform public.refresh_page_search(target_page);

  update public.pages
     set updated_at = now()
   where id = target_page;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_blocks_sync_page_search on public.blocks;
create trigger trg_blocks_sync_page_search
  after insert or update of content or delete on public.blocks
  for each row execute function public.sync_page_search_from_block();

-- -------------------------------------------------------------------------------------
-- 2. search_pages() - the global full-text search used by the app ---------------------
-- -------------------------------------------------------------------------------------
-- Returns ranked hits with a highlighted snippet. Called from Dart with:
--   supabase.rpc('search_pages', params: {'p_query': 'hydraulic', ...})
--
-- RLS applies to `public.pages` inside the function (it is NOT security
-- definer), so a user only ever gets their own rows back.

create or replace function public.search_pages(
  p_query         text,
  p_aircraft_type text    default null,
  p_ata_chapter   text    default null,
  p_notebook_id   uuid    default null,
  p_limit         integer default 30
)
returns table (
  id             uuid,
  notebook_id    uuid,
  parent_page_id uuid,
  title          text,
  icon           text,
  template_key   text,
  aircraft_type  text,
  registration   text,
  ata_chapter    text,
  airport_icao   text,
  departure_icao text,
  arrival_icao   text,
  flight_date    date,
  position       integer,
  is_archived    boolean,
  is_favorite    boolean,
  child_count    integer,
  summary        text,
  created_at     timestamptz,
  updated_at     timestamptz,
  user_id        uuid,
  rank           double precision,
  snippet        text
)
language plpgsql
stable
as $$
declare
  normalized text;
  query      tsquery;
begin
  normalized := trim(coalesce(p_query, ''));
  if char_length(normalized) = 0 then
    return;
  end if;

  -- `websearch` accepts natural input ("A320 hydraulic pump -fuel") and never
  -- throws on malformed syntax, unlike `plainto_tsquery` with special chars.
  query := websearch_to_tsquery('simple', normalized);

  return query
    select
      p.id,
      p.notebook_id,
      p.parent_page_id,
      p.title,
      p.icon,
      p.template_key,
      p.aircraft_type,
      p.registration,
      p.ata_chapter,
      p.airport_icao,
      p.departure_icao,
      p.arrival_icao,
      p.flight_date,
      p.position,
      p.is_archived,
      p.is_favorite,
      p.child_count,
      p.summary,
      p.created_at,
      p.updated_at,
      p.user_id,
      -- Boost title matches so "A320" in a title outranks a body mention.
      ts_rank(
        setweight(to_tsvector('simple', coalesce(p.title, '')), 'A') || p.search_vector,
        query,
        1
      ) as rank,
      ts_headline(
        'simple',
        coalesce(p.title, '') || E'\n' || coalesce(p.summary, '') || E'\n' || coalesce(p.blocks_text, ''),
        query,
        'StartSel=<b>, StopSel=</b>, MaxWords=28, MinWords=8, ShortWord=4, HighlightAll=false'
      ) as snippet
    from public.pages p
    where p.search_vector @@ query
      and p.is_archived = false
      and (p_aircraft_type is null or upper(p.aircraft_type) = upper(p.aircraft_type))
      and (p_ata_chapter   is null or p.ata_chapter = ltrim(p_ata_chapter, '0'))
      and (p_notebook_id   is null or p.notebook_id = p_notebook_id)
    order by rank desc, p.updated_at desc
    limit greatest(1, least(coalesce(p_limit, 30), 100));
end;
$$;

revoke all on function public.search_pages(text, text, text, uuid, integer) from public;
grant execute on function public.search_pages(text, text, text, uuid, integer) to authenticated;

-- Cheap title-only autocomplete (no tsvector needed, uses the trigram index).
create or replace function public.search_page_titles(
  p_query text,
  p_limit integer default 20
)
returns table (
  id          uuid,
  notebook_id uuid,
  title       text,
  icon        text,
  updated_at  timestamptz
)
language plpgsql
stable
as $$
begin
  if char_length(trim(coalesce(p_query, ''))) = 0 then
    return;
  end if;

  return query
    select p.id, p.notebook_id, p.title, p.icon, p.updated_at
    from public.pages p
    where p.is_archived = false
      and p.title ilike '%' || trim(p_query) || '%'
    order by p.updated_at desc
    limit greatest(1, least(coalesce(p_limit, 20), 100));
end;
$$;

revoke all on function public.search_page_titles(text, integer) from public;
grant execute on function public.search_page_titles(text, integer) to authenticated;

-- -------------------------------------------------------------------------------------
-- 3. Helper views ---------------------------------------------------------------------
-- -------------------------------------------------------------------------------------
-- security_invoker = true keeps the view subject to the *caller's* RLS policies,
-- so it can never leak another user's rows.

drop view if exists public.page_search;
create view public.page_search
with (security_invoker = on)
as
select
  p.id,
  p.user_id,
  p.notebook_id,
  p.parent_page_id,
  p.title,
  p.icon,
  p.template_key,
  p.aircraft_type,
  p.registration,
  p.ata_chapter,
  p.airport_icao,
  p.departure_icao,
  p.arrival_icao,
  p.flight_date,
  p.is_favorite,
  p.is_archived,
  p.child_count,
  p.summary,
  p.created_at,
  p.updated_at,
  p.search_vector
from public.pages p;

-- Pages joined with their tags - used by the tag filter UI (Stage C).
drop view if exists public.pages_with_tags;
create view public.pages_with_tags
with (security_invoker = on)
as
select
  p.id            as page_id,
  p.user_id,
  p.notebook_id,
  p.title,
  p.aircraft_type,
  p.ata_chapter,
  p.updated_at,
  t.id            as tag_id,
  t.name          as tag_name,
  t.color         as tag_color
from public.pages p
join public.page_tags pt on pt.page_id = p.id
join public.tags t       on t.id = pt.tag_id;

-- -------------------------------------------------------------------------------------
-- 4. Consistency helpers (self-healing counters) --------------------------------------
-- -------------------------------------------------------------------------------------
-- Deleting a page cascades to its whole subtree, which decrements
-- `notebooks.pages_count` once per descendant row. `greatest(..., 0)` already
-- keeps the value legal; this trigger makes it exact again.
create or replace function public.recount_notebook_pages()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'DELETE' then
    update public.notebooks n
       set pages_count = (
             select count(*)::integer from public.pages p where p.notebook_id = n.id
           )
     where n.id = old.notebook_id;
    return old;
  end if;

  update public.notebooks n
     set pages_count = (
           select count(*)::integer from public.pages p where p.notebook_id = n.id
         )
   where n.id = new.notebook_id;

  return new;
end;
$$;

drop trigger if exists trg_pages_recount_notebook on public.pages;
create trigger trg_pages_recount_notebook
  after delete or update of notebook_id on public.pages
  for each row execute function public.recount_notebook_pages();

-- Manual repair utility (safe to run at any time).
create or replace function public.recount_all_counters()
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.notebooks n
     set pages_count = (select count(*)::integer from public.pages p where p.notebook_id = n.id);

  update public.pages p
     set child_count = (select count(*)::integer from public.pages c where c.parent_page_id = p.id);

  update public.tags t
     set usage_count = (select count(*)::integer from public.page_tags pt where pt.tag_id = t.id);

  update public.pages p
     set blocks_text = (
       select coalesce(string_agg(coalesce(b.content, ''), ' ' order by b.position), '')
       from public.blocks b
       where b.page_id = p.id and b.parent_block_id is null and b.type <> 'divider'
     );
end;
$$;

revoke all on function public.recount_all_counters() from public;
grant execute on function public.recount_all_counters() to authenticated;

-- -------------------------------------------------------------------------------------
-- 5. Templates ------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------
-- Template *definitions* are global (not per user), everything else in the app is.
create table if not exists public.page_templates (
  id          uuid primary key default gen_random_uuid(),
  key         text not null unique,
  title       text not null,
  description text,
  icon        text,
  position    integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.page_templates enable row level security;

drop policy if exists "page_templates_select_all" on public.page_templates;
create policy "page_templates_select_all" on public.page_templates
  for select to authenticated, anon using (is_active);

-- Only the service role (or a SQL editor session) can change templates: no
-- insert/update/delete policy exists for `authenticated`, and RLS blocks them.

insert into public.page_templates (key, title, description, icon, position) values
  ('flight_log',           'Flight Log',           'Route, times, fuel, crew and remarks for one flight.', '🛫', 0),
  ('maintenance_note',     'Maintenance Note',     'Work performed, ATA chapter, parts and sign-off.',      '🛠️', 1),
  ('preflight_checklist',  'Pre-flight Checklist', 'Walk-around and cockpit checks as a checklist.',        '✅', 2),
  ('theory_lesson',        'Theory Lesson',        'Lesson summary with headings, key points, questions.',  '📚', 3),
  ('defect_report',        'Defect Report',        'Defect, severity, MEL reference and corrective action.','🧯', 4)
on conflict (key) do update
  set title       = excluded.title,
      description = excluded.description,
      icon        = excluded.icon,
      position    = excluded.position,
      updated_at  = now();

create trigger trg_page_templates_updated_at
  before update on public.page_templates
  for each row execute function public.set_updated_at();

-- 5a. The seeder ----------------------------------------------------------------------
-- Inserting a page with `template_key` set automatically creates its blocks, so the
-- Flutter client only sends one INSERT and gets a ready-made page back.
create or replace function public.seed_template_blocks()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.template_key is null or trim(new.template_key) = '' then
    return new;
  end if;

  -- Never seed twice (e.g. when a client updates template_key later).
  if exists (select 1 from public.blocks b where b.page_id = new.id) then
    return new;
  end if;

  case new.template_key
    -- ---------------------------------------------------------------- Flight Log
    when 'flight_log' then
      insert into public.blocks (user_id, page_id, type, content, props, is_checked, position) values
        (new.user_id, new.id, 'heading1',   'Flight Details',                       '{}'::jsonb, null,  0),
        (new.user_id, new.id, 'paragraph',  'Route:  → ',                           '{}'::jsonb, null,  1),
        (new.user_id, new.id, 'paragraph',  'Date: ',                               '{}'::jsonb, null,  2),
        (new.user_id, new.id, 'paragraph',  'Aircraft / Registration: ',            '{}'::jsonb, null,  3),
        (new.user_id, new.id, 'paragraph',  'Crew (PIC / SIC / Cabin): ',           '{}'::jsonb, null,  4),
        (new.user_id, new.id, 'divider',    null,                                   '{}'::jsonb, null,  5),
        (new.user_id, new.id, 'heading2',   'Times',                                '{}'::jsonb, null,  6),
        (new.user_id, new.id, 'checklist',  'Out / Off / On / In recorded',         '{}'::jsonb, false, 7),
        (new.user_id, new.id, 'checklist',  'Block time and flight time computed',  '{}'::jsonb, false, 8),
        (new.user_id, new.id, 'divider',    null,                                   '{}'::jsonb, null,  9),
        (new.user_id, new.id, 'heading2',   'Fuel',                                 '{}'::jsonb, null, 10),
        (new.user_id, new.id, 'paragraph',  'Uplift:            kg / lb',           '{}'::jsonb, null, 11),
        (new.user_id, new.id, 'paragraph',  'Burn:              kg / lb',           '{}'::jsonb, null, 12),
        (new.user_id, new.id, 'paragraph',  'Remaining on arrival:',                '{}'::jsonb, null, 13),
        (new.user_id, new.id, 'divider',    null,                                   '{}'::jsonb, null, 14),
        (new.user_id, new.id, 'heading2',   'Weather',                              '{}'::jsonb, null, 15),
        (new.user_id, new.id, 'paragraph',  'Departure METAR / TAF:',               '{}'::jsonb, null, 16),
        (new.user_id, new.id, 'paragraph',  'Arrival METAR / TAF:',                 '{}'::jsonb, null, 17),
        (new.user_id, new.id, 'paragraph',  'En-route (wind, turbulence, icing):',  '{}'::jsonb, null, 18),
        (new.user_id, new.id, 'divider',    null,                                   '{}'::jsonb, null, 19),
        (new.user_id, new.id, 'heading2',   'Remarks / Lessons learned',            '{}'::jsonb, null, 20),
        (new.user_id, new.id, 'paragraph',  '',                                     '{}'::jsonb, null, 21);

    -- ------------------------------------------------------------- Maintenance
    when 'maintenance_note' then
      insert into public.blocks (user_id, page_id, type, content, props, is_checked, position) values
        (new.user_id, new.id, 'heading1',   'Maintenance Record',                   '{}'::jsonb, null,  0),
        (new.user_id, new.id, 'paragraph',  'Aircraft / Registration:',             '{}'::jsonb, null,  1),
        (new.user_id, new.id, 'paragraph',  'ATA Chapter:',                         '{}'::jsonb, null,  2),
        (new.user_id, new.id, 'paragraph',  'Date / Station (ICAO):',               '{}'::jsonb, null,  3),
        (new.user_id, new.id, 'paragraph',  'Work order / Task card:',              '{}'::jsonb, null,  4),
        (new.user_id, new.id, 'divider',    null,                                   '{}'::jsonb, null,  5),
        (new.user_id, new.id, 'heading2',   'Findings',                             '{}'::jsonb, null,  6),
        (new.user_id, new.id, 'paragraph',  '',                                     '{}'::jsonb, null,  7),
        (new.user_id, new.id, 'heading2',   'Work Performed',                       '{}'::jsonb, null,  8),
        (new.user_id, new.id, 'paragraph',  '',                                     '{}'::jsonb, null,  9),
        (new.user_id, new.id, 'heading2',   'Parts Used',                           '{}'::jsonb, null, 10),
        (new.user_id, new.id, 'paragraph',  'P/N · S/N · Qty · Condition',          '{}'::jsonb, null, 11),
        (new.user_id, new.id, 'heading2',   'References',                           '{}'::jsonb, null, 12),
        (new.user_id, new.id, 'paragraph',  'AMM / IPC / SRM task:',                '{}'::jsonb, null, 13),
        (new.user_id, new.id, 'heading2',   'Sign-off',                             '{}'::jsonb, null, 14),
        (new.user_id, new.id, 'checklist',  'Functional test completed',            '{}'::jsonb, false, 15),
        (new.user_id, new.id, 'checklist',  'Entry recorded in the tech log',       '{}'::jsonb, false, 16),
        (new.user_id, new.id, 'checklist',  'Certifying staff signature + license', '{}'::jsonb, false, 17);

    -- ------------------------------------------------------- Pre-flight checks
    when 'preflight_checklist' then
      insert into public.blocks (user_id, page_id, type, content, props, is_checked, position) values
        (new.user_id, new.id, 'heading1',   'Pre-flight Checklist',                 '{}'::jsonb, null,  0),
        (new.user_id, new.id, 'paragraph',  'Aircraft / Registration:',             '{}'::jsonb, null,  1),
        (new.user_id, new.id, 'paragraph',  'Date / Station:',                      '{}'::jsonb, null,  2),
        (new.user_id, new.id, 'divider',    null,                                   '{}'::jsonb, null,  3),
        (new.user_id, new.id, 'heading2',   'Documents',                            '{}'::jsonb, null,  4),
        (new.user_id, new.id, 'checklist',  'Airworthiness certificate on board',   '{}'::jsonb, false, 5),
        (new.user_id, new.id, 'checklist',  'Registration certificate on board',    '{}'::jsonb, false, 6),
        (new.user_id, new.id, 'checklist',  'Flight manual / QRH available',        '{}'::jsonb, false, 7),
        (new.user_id, new.id, 'checklist',  'Tech log reviewed - no open defects',  '{}'::jsonb, false, 8),
        (new.user_id, new.id, 'checklist',  'MEL / CDL items verified',             '{}'::jsonb, false, 9),
        (new.user_id, new.id, 'heading2',   'Exterior walk-around',                 '{}'::jsonb, null, 10),
        (new.user_id, new.id, 'checklist',  'Fuel quantity and quality checked',    '{}'::jsonb, false, 11),
        (new.user_id, new.id, 'checklist',  'Oil / hydraulic levels',               '{}'::jsonb, false, 12),
        (new.user_id, new.id, 'checklist',  'Tyres, brakes and wheels',             '{}'::jsonb, false, 13),
        (new.user_id, new.id, 'checklist',  'Control surfaces and hinges',          '{}'::jsonb, false, 14),
        (new.user_id, new.id, 'checklist',  'Lights, pitot and static ports',       '{}'::jsonb, false, 15),
        (new.user_id, new.id, 'checklist',  'Landing gear, pins and covers removed','{}'::jsonb, false, 16),
        (new.user_id, new.id, 'heading2',   'Cockpit preparation',                  '{}'::jsonb, null, 17),
        (new.user_id, new.id, 'checklist',  'FMS route and performance data',       '{}'::jsonb, false, 18),
        (new.user_id, new.id, 'checklist',  'Altimeters and STD setting',           '{}'::jsonb, false, 19),
        (new.user_id, new.id, 'checklist',  'Radios, transponder and squawk',       '{}'::jsonb, false, 20),
        (new.user_id, new.id, 'checklist',  'Take-off briefing completed',          '{}'::jsonb, false, 21),
        (new.user_id, new.id, 'callout',    'Any doubt - stop and re-check. Never accept an unexplained warning.',
                                                                                   '{"kind":"warning"}'::jsonb, null, 22);

    -- ---------------------------------------------------------- Theory lesson
    when 'theory_lesson' then
      insert into public.blocks (user_id, page_id, type, content, props, is_checked, position) values
        (new.user_id, new.id, 'heading1',   'Lesson Summary',                       '{}'::jsonb, null,  0),
        (new.user_id, new.id, 'paragraph',  'Subject / ATPL syllabus reference:',   '{}'::jsonb, null,  1),
        (new.user_id, new.id, 'paragraph',  'Instructor / Source:',                 '{}'::jsonb, null,  2),
        (new.user_id, new.id, 'paragraph',  'Date:',                                '{}'::jsonb, null,  3),
        (new.user_id, new.id, 'divider',    null,                                   '{}'::jsonb, null,  4),
        (new.user_id, new.id, 'heading2',   'Key points',                           '{}'::jsonb, null,  5),
        (new.user_id, new.id, 'bullet_list','Point 1',                              '{}'::jsonb, null,  6),
        (new.user_id, new.id, 'bullet_list','Point 2',                              '{}'::jsonb, null,  7),
        (new.user_id, new.id, 'bullet_list','Point 3',                              '{}'::jsonb, null,  8),
        (new.user_id, new.id, 'heading2',   'Definitions',                          '{}'::jsonb, null,  9),
        (new.user_id, new.id, 'paragraph',  'Term → meaning',                       '{}'::jsonb, null, 10),
        (new.user_id, new.id, 'heading2',   'Formulas / limits',                    '{}'::jsonb, null, 11),
        (new.user_id, new.id, 'code',       'TAS = CAS × √(ρ0/ρ)',                  '{"language":"text"}'::jsonb, null, 12),
        (new.user_id, new.id, 'heading2',   'Exam questions to review',             '{}'::jsonb, null, 13),
        (new.user_id, new.id, 'checklist',  'Question 1',                           '{}'::jsonb, false, 14),
        (new.user_id, new.id, 'checklist',  'Question 2',                           '{}'::jsonb, false, 15);

    -- ----------------------------------------------------------- Defect report
    when 'defect_report' then
      insert into public.blocks (user_id, page_id, type, content, props, is_checked, position) values
        (new.user_id, new.id, 'heading1',   'Defect Report',                        '{}'::jsonb, null,  0),
        (new.user_id, new.id, 'paragraph',  'Aircraft / Registration:',             '{}'::jsonb, null,  1),
        (new.user_id, new.id, 'paragraph',  'ATA Chapter:',                         '{}'::jsonb, null,  2),
        (new.user_id, new.id, 'paragraph',  'Date / Flight / Leg:',                 '{}'::jsonb, null,  3),
        (new.user_id, new.id, 'paragraph',  'Reported by:',                         '{}'::jsonb, null,  4),
        (new.user_id, new.id, 'divider',    null,                                   '{}'::jsonb, null,  5),
        (new.user_id, new.id, 'heading2',   'Severity',                             '{}'::jsonb, null,  6),
        (new.user_id, new.id, 'bullet_list','Minor - no operational impact',        '{}'::jsonb, null,  7),
        (new.user_id, new.id, 'bullet_list','Major - dispatch with restrictions',   '{}'::jsonb, null,  8),
        (new.user_id, new.id, 'bullet_list','AOG - aircraft on ground',             '{}'::jsonb, null,  9),
        (new.user_id, new.id, 'heading2',   'Phase of flight',                      '{}'::jsonb, null, 10),
        (new.user_id, new.id, 'paragraph',  'Pre-flight / Taxi / Climb / Cruise / Descent / Approach / Landing',
                                                                                   '{}'::jsonb, null, 11),
        (new.user_id, new.id, 'heading2',   'Description',                          '{}'::jsonb, null, 12),
        (new.user_id, new.id, 'paragraph',  '',                                     '{}'::jsonb, null, 13),
        (new.user_id, new.id, 'heading2',   'ECAM / EICAS / warning messages',      '{}'::jsonb, null, 14),
        (new.user_id, new.id, 'code',       '',                                     '{"language":"text"}'::jsonb, null, 15),
        (new.user_id, new.id, 'heading2',   'Operational impact',                   '{}'::jsonb, null, 16),
        (new.user_id, new.id, 'paragraph',  '',                                     '{}'::jsonb, null, 17),
        (new.user_id, new.id, 'heading2',   'MEL / CDL reference',                  '{}'::jsonb, null, 18),
        (new.user_id, new.id, 'paragraph',  'Item · Category (A/B/C/D) · Expiry',   '{}'::jsonb, null, 19),
        (new.user_id, new.id, 'heading2',   'Action taken',                         '{}'::jsonb, null, 20),
        (new.user_id, new.id, 'checklist',  'Deferred per MEL (O) / (M) items',     '{}'::jsonb, false, 21),
        (new.user_id, new.id, 'checklist',  'Maintenance notified',                 '{}'::jsonb, false, 22),
        (new.user_id, new.id, 'checklist',  'Tech log entry written',               '{}'::jsonb, false, 23),
        (new.user_id, new.id, 'checklist',  'Closed after rectification',           '{}'::jsonb, false, 24);

    else
      -- Unknown template key: nothing is seeded, the page stays blank.
      null;
  end case;

  -- Keep the search vector of the fresh page in sync with its seeded blocks.
  perform public.refresh_page_search(new.id);

  return new;
end;
$$;

drop trigger if exists trg_pages_seed_template on public.pages;
create trigger trg_pages_seed_template
  after insert on public.pages
  for each row execute function public.seed_template_blocks();

-- -------------------------------------------------------------------------------------
-- 6. Tag upsert helper (used by the Stage C tag editor) --------------------------------
-- -------------------------------------------------------------------------------------
create or replace function public.upsert_tag(
  p_name  text,
  p_color text default null
)
returns uuid
language plpgsql
as $$
declare
  tag_id uuid;
begin
  if p_name is null or char_length(trim(p_name)) = 0 then
    raise exception 'Tag name cannot be empty' using errcode = '23514';
  end if;

  select t.id into tag_id
  from public.tags t
  where t.user_id = auth.uid()
    and lower(trim(t.name)) = lower(trim(p_name));

  if tag_id is null then
    insert into public.tags (user_id, name, color)
    values (auth.uid(), trim(p_name), coalesce(p_color, '#0B4F8A'))
    returning id into tag_id;
  elsif p_color is not null then
    update public.tags set color = p_color where id = tag_id;
  end if;

  return tag_id;
end;
$$;

revoke all on function public.upsert_tag(text, text) from public;
grant execute on function public.upsert_tag(text, text) to authenticated;

-- Attach a tag to a page (idempotent).
create or replace function public.add_page_tag(p_page_id uuid, p_tag_id uuid)
returns void
language plpgsql
as $$
begin
  insert into public.page_tags (user_id, page_id, tag_id)
  values (auth.uid(), p_page_id, p_tag_id)
  on conflict (page_id, tag_id) do nothing;
end;
$$;

revoke all on function public.add_page_tag(uuid, uuid) from public;
grant execute on function public.add_page_tag(uuid, uuid) to authenticated;

-- -------------------------------------------------------------------------------------
-- 7. Grants for the new objects -------------------------------------------------------
-- -------------------------------------------------------------------------------------
grant select on public.page_search     to authenticated;
grant select on public.pages_with_tags to authenticated;
grant select on public.page_templates  to authenticated, anon;
