-- ═══════════════════════════════════════════════════════════════════════════
--  SU-35 Notes — Aviation Notes Workspace
--  مخطط قاعدة البيانات الكامل (PostgreSQL 15+ / Supabase)
--  نفّذ هذا الملف كاملًا في: Supabase Dashboard → SQL Editor → New query
--  الملف آمن للتشغيل أكثر من مرة (Idempotent).
--
--  الترتيب المنطقي:
--    1) الإضافات        2) الجداول        3) الدوال المساعدة
--    4) توليد الأعمدة   5) الفهارس        6) المُشغّلات (Triggers)
--    7) RLS والسياسات   8) Storage        9) بحث نصي (RPC)   10) الصلاحيات
-- ═══════════════════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────────────────────────────────
-- 1) الإضافات المطلوبة
--    pg_trgm: لبحث جزئي سريع (ILIKE) يعمل جيدًا مع النصوص العربية.
--    ملاحظة مهمة: PostgreSQL لا يملك قاموسًا عربيًا مدمجًا للبحث النصي،
--    لذلك نستخدم إعداد 'simple' (بدون تجذير) لتفادي تحطيم الكلمات العربية،
--    ونُسنِد بحث المسافات الجزئي إلى pg_trgm.
-- ───────────────────────────────────────────────────────────────────────────
create extension if not exists pg_trgm;

-- ───────────────────────────────────────────────────────────────────────────
-- 2) الجداول
--    كل جدول يحتوي على: user_id + created_at + updated_at كما هو مطلوب.
-- ───────────────────────────────────────────────────────────────────────────

-- 2.1 الملفات الشخصية (مرتبطة ارتباطًا وثيقًا بمستخدمي auth.users) ─────────
create table if not exists public.profiles (
  id               uuid primary key references auth.users (id) on delete cascade,
  user_id          uuid not null unique references auth.users (id) on delete cascade,
  email            text,
  display_name     text,
  avatar_url       text,
  role             text not null default 'pilot'
                     check (role in ('pilot', 'engineer', 'student', 'instructor', 'other')),
  license_number   text,
  home_base_icao   text check (home_base_icao is null or home_base_icao ~ '^[A-Za-z]{4}$'),
  preferred_locale text not null default 'ar' check (preferred_locale in ('ar', 'en')),
  preferred_theme  text not null default 'system'
                     check (preferred_theme in ('system', 'light', 'dark')),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

comment on table public.profiles is 'بيانات المستخدم: الاسم، الدور المهني، اللغة والوضع الليلي المفضّل.';

-- 2.2 الدفاتر (Notebooks) ──────────────────────────────────────────────────
create table if not exists public.notebooks (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  title           text not null check (char_length(btrim(title)) between 1 and 200),
  description     text check (description is null or char_length(description) <= 2000),
  icon            text default '📘' check (icon is null or char_length(icon) <= 16),
  color           text default '#0B3D91' check (color is null or color ~* '^#[0-9a-f]{6}$'),
  aircraft_type   text,                       -- نوع الطائرة الافتراضي للدفتر
  is_favorite     boolean not null default false,
  is_archived     boolean not null default false,
  sort_order      integer not null default 100,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.notebooks is 'دفاتر المستخدم: كل دفتر يجمع صفحات مترابطة (رحلات، صيانة، دروس نظري...).';

-- 2.3 الصفحات (Pages) + الصفحات المتداخلة عبر parent_page_id ───────────────
create table if not exists public.pages (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  notebook_id     uuid not null references public.notebooks (id) on delete cascade,
  parent_page_id  uuid references public.pages (id) on delete cascade,   -- صفحة داخل صفحة
  title           text not null default 'بدون عنوان'
                    check (char_length(btrim(title)) between 1 and 300),
  icon            text check (icon is null or char_length(icon) <= 16),
  summary         text,                       -- سطر وصفي/ملخص الصفحة
  content_text    text,                       -- النص المسطّح المجمّع من البلوكات (للبحث والمعاينة)
  template_key    text,                       -- مفتاح القالب المستخدم (flight_log, defect_report...)
  -- ── الحقول المخصصة لمجال الطيران ──────────────────────────────
  aircraft_type   text check (aircraft_type is null or char_length(aircraft_type) <= 32),
  tail_number     text check (tail_number is null or char_length(tail_number) <= 16),
  ata_chapter     text check (ata_chapter is null or char_length(ata_chapter) <= 8),
  airport_icao    text check (airport_icao is null or airport_icao ~ '^[A-Za-z]{4}$'),
  flight_date     date,
  -- ── حالة الصفحة ───────────────────────────────────────────────
  is_favorite     boolean not null default false,
  is_archived     boolean not null default false,
  sort_order      integer not null default 100,
  -- ── البحث النصي الكامل (tsvector) ─────────────────────────────
  -- الأعمدة المولّدة تُحدَّث تلقائيًا عند أي تعديل، مع ترجيح:
  --   A = العنوان | B = الحقول الجوية | C = الملخص + محتوى البلوكات
  search_vector   tsvector generated always as (
                    setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
                    setweight(to_tsvector('simple',
                              coalesce(aircraft_type, '') || ' ' ||
                              coalesce(tail_number, '')   || ' ' ||
                              coalesce(ata_chapter, '')   || ' ' ||
                              coalesce(airport_icao, '')), 'B') ||
                    setweight(to_tsvector('simple',
                              coalesce(summary, '') || ' ' || coalesce(content_text, '')), 'C')
                  ) stored,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.pages is 'صفحات الملاحظات مع حقول الطيران المخصصة ودعم الصفحات المتداخلة والبحث النصي الكامل.';


-- ───────────────────────────────────────────────────────────────────────────
-- 2.4 دالة استخراج النص المسطّح من محتوى الكتلة
--     تُعرَّف قبل جدول blocks لأن العمود المولّد text_content يستدعيها،
--     وتُستخدم أيضًا لبناء فهرس البحث النصي الخاص بالكتل.
-- ───────────────────────────────────────────────────────────────────────────
create or replace function public.block_plain_text(p_type text, p_content jsonb)
returns text
language plpgsql
immutable
parallel safe
as $$
declare
  v_text text;
begin
  if p_content is null or jsonb_typeof(p_content) <> 'object' then
    return null;
  end if;

  case p_type
    when 'text'    then return p_content ->> 'text';
    when 'heading' then return p_content ->> 'text';
    when 'code'    then return p_content ->> 'code';
    when 'quote'   then return p_content ->> 'text';
    when 'callout' then return concat_ws(' ', p_content ->> 'title', p_content ->> 'text');
    when 'image'   then return concat_ws(' ', p_content ->> 'caption', p_content ->> 'alt');
    when 'pdf'     then return concat_ws(' ', p_content ->> 'file_name', p_content ->> 'caption');
    when 'divider' then return null;
    when 'checklist' then
      select string_agg(coalesce(item ->> 'text', ''), ' ' order by ord)
        into v_text
        from jsonb_array_elements(coalesce(p_content -> 'items', '[]'::jsonb))
             with ordinality as t (item, ord);
      return v_text;
    when 'table' then
      select string_agg(coalesce(cell, ''), ' ' order by r, c)
        into v_text
        from jsonb_array_elements(coalesce(p_content -> 'rows', '[]'::jsonb))
             with ordinality as tr (row_json, r),
             jsonb_array_elements_text(coalesce(tr.row_json, '[]'::jsonb))
             with ordinality as tc (cell, c);
      return v_text;
    else
      return p_content ->> 'text';
  end case;

  return null;
end;
$$;

comment on function public.block_plain_text(text, jsonb)
  is 'يستخرج نصًا مسطّحًا قابلًا للبحث من محتوى أي كتلة حسب نوعها.';

-- 2.5 الكتل (Blocks) — أنواعها: نص، عنوان، قائمة تحقق، جدول، صورة، PDF، كود، فاصل
create table if not exists public.blocks (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  page_id         uuid not null references public.pages (id) on delete cascade,
  parent_block_id uuid references public.blocks (id) on delete cascade,   -- إدراج داخل عنصر قائمة مثلًا
  type            text not null check (type in
                    ('text', 'heading', 'checklist', 'table', 'image',
                     'pdf', 'code', 'divider', 'quote', 'callout')),
  sort_order      numeric(20, 10) not null default 1000,   -- ترتيب مرن (منتصف بين كتلتين)
  content         jsonb not null default '{}'::jsonb,      -- محتوى الكتلة حسب نوعها
  text_content    text generated always as (public.block_plain_text(type, content)) stored,
  search_vector   tsvector generated always as (
                    to_tsvector('simple', coalesce(public.block_plain_text(type, content), ''))
                  ) stored,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint blocks_content_must_be_object check (jsonb_typeof(content) = 'object')
);

comment on table public.blocks is 'كتل محتوى الصفحة (نص/عنوان/تحقق/جدول/صورة/PDF/كود/فاصل) بصيغة JSONB قابلة للتمديد.';
comment on column public.blocks.content is 'أمثلة: {"text":"..."} أو {"items":[{"id":"1","text":"...","checked":false}]} أو {"rows":[["A","B"]]}.';

-- 2.6 الوسوم (Tags) ────────────────────────────────────────────────────────
create table if not exists public.tags (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null check (char_length(btrim(name)) between 1 and 50),
  color       text default '#4FA3E3' check (color is null or color ~* '^#[0-9a-f]{6}$'),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.tags is 'وسوم حرة لتنظيم الملاحظات (مثال: CFM56، Gear، EASA، Type-Rating).';

-- ملاحظة: لا يمكن استخدام دالة في قيد UNIQUE مباشرة، لذا نُنشئ فهرسًا فريدًا
-- على (user_id, lower(name)) لمنع تكرار الوسم نفسه بأحرف كبيرة/صغيرة.
create unique index if not exists tags_user_name_lower_key
  on public.tags (user_id, lower(btrim(name)));

-- 2.7 جدول الربط: صفحات ↔ وسوم ────────────────────────────────────────────
create table if not exists public.page_tags (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  page_id     uuid not null references public.pages (id) on delete cascade,
  tag_id      uuid not null references public.tags (id) on delete cascade,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint page_tags_unique_pair unique (page_id, tag_id)
);

comment on table public.page_tags is 'ربط متعدد لمتعدد بين الصفحات والوسوم مع فصل كامل بسياسات RLS.';

-- 2.8 المرفقات (Attachments) — صور، مخططات، ملفات PDF ─────────────────────
create table if not exists public.attachments (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  page_id       uuid not null references public.pages (id) on delete cascade,
  block_id      uuid references public.blocks (id) on delete set null,   -- الكتلة التي تعرضها (اختياري)
  kind          text not null default 'other' check (kind in ('image', 'pdf', 'other')),
  file_name     text not null check (char_length(btrim(file_name)) between 1 and 300),
  storage_path  text not null unique,          -- المسار داخل Bucket: <user_id>/<page_id>/<file>
  mime_type     text,
  size_bytes    bigint check (size_bytes is null or size_bytes >= 0),
  width         integer,
  height        integer,
  caption       text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.attachments is 'بيانات المرفقات (الصورة/PDF) داخل Storage، والملف نفسه يُخزَّن في bucket خاص باسم attachments.';

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) الدوال المساعدة (تُستخدم داخل الأعمدة المولّدة والمُشغّلات)
-- ═══════════════════════════════════════════════════════════════════════════

-- 3.1 تحديث updated_at تلقائيًا عند كل تعديل ───────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at() is 'مُشغّل عام: يضبط updated_at على وقت التعديل.';

-- 3.2 التحقق من صحة الصفحة الأصل (نفس الدفتر، بلا حلقات دائرية) ────────────
create or replace function public.validate_page_parent()
returns trigger
language plpgsql
as $$
declare
  v_parent        public.pages%rowtype;
  v_cursor        uuid;
  v_depth         integer := 0;
begin
  if new.parent_page_id is null then
    return new;
  end if;

  if new.parent_page_id = new.id then
    raise exception 'لا يمكن أن تكون الصفحة أصلًا لنفسها (parent_page_id = id)';
  end if;

  select * into v_parent from public.pages where id = new.parent_page_id;
  if not found then
    raise exception 'الصفحة الأصل غير موجودة: %', new.parent_page_id;
  end if;

  if v_parent.notebook_id <> new.notebook_id then
    raise exception 'يجب أن تكون الصفحة الفرعية داخل الدفتر نفسه';
  end if;

  if v_parent.user_id <> new.user_id then
    raise exception 'لا يمكن ربط صفحة تابعة لمستخدم آخر';
  end if;

  -- منع الحلقات: نصعد في سلسلة الآباء بحد أقصى 32 مستوى
  v_cursor := new.parent_page_id;
  while v_cursor is not null and v_depth < 32 loop
    if v_cursor = new.id then
      raise exception 'حلقة دائرية في تداخل الصفحات';
    end if;
    select p.parent_page_id into v_cursor from public.pages p where p.id = v_cursor;
    v_depth := v_depth + 1;
  end loop;

  return new;
end;
$$;

comment on function public.validate_page_parent() is 'يمنع تداخلًا خاطئًا: صفحة داخل دفتر آخر، أو حلقة دائرية، أو ربط بمستخدم آخر.';

-- 3.3 إعادة حساب النص المسطّح للصفحة من كتل المحتوى ────────────────────────
create or replace function public.refresh_page_content_text()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_page_id uuid;
begin
  if tg_op = 'DELETE' then
    v_page_id := old.page_id;
  else
    v_page_id := new.page_id;
  end if;

  update public.pages p
     set content_text = agg.txt
    from (
      select string_agg(b.text_content, E'\n' order by b.sort_order) as txt
        from public.blocks b
       where b.page_id = v_page_id
    ) agg
   where p.id = v_page_id;

  -- عند نقل كتلة من صفحة إلى أخرى نُحدّث الصفحة القديمة أيضًا
  if tg_op = 'UPDATE' and old.page_id is distinct from new.page_id then
    update public.pages p
       set content_text = agg.txt
      from (
        select string_agg(b.text_content, E'\n' order by b.sort_order) as txt
          from public.blocks b
         where b.page_id = old.page_id
      ) agg
     where p.id = old.page_id;
  end if;

  return null;   -- AFTER trigger
end;
$$;

comment on function public.refresh_page_content_text() is 'يُشغَّل بعد أي تغيير على الكتل ليحدّث pages.content_text المستخدم في البحث والمعاينة.';

-- 3.4 التحقق من أن الكتلة الأصل تنتمي للصفحة نفسها ─────────────────────────
create or replace function public.validate_block_parent()
returns trigger
language plpgsql
as $$
declare
  v_parent public.blocks%rowtype;
begin
  if new.parent_block_id is null then
    return new;
  end if;
  if new.parent_block_id = new.id then
    raise exception 'لا يمكن أن تكون الكتلة أصلًا لنفسها';
  end if;

  select * into v_parent from public.blocks where id = new.parent_block_id;
  if not found then
    raise exception 'الكتلة الأصل غير موجودة: %', new.parent_block_id;
  end if;
  if v_parent.page_id <> new.page_id then
    raise exception 'يجب أن تكون الكتلة الفرعية داخل الصفحة نفسها';
  end if;
  return new;
end;
$$;

-- 3.5 إنشاء الملف الشخصي ودفتر بداية عند تسجيل مستخدم جديد ────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_display_name text;
  v_role         text;
  v_notebook_id  uuid;
begin
  v_display_name := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '');
  if v_display_name is null then
    v_display_name := split_part(coalesce(new.email, 'طيار'), '@', 1);
  end if;

  v_role := coalesce(new.raw_user_meta_data ->> 'role', 'pilot');
  if v_role not in ('pilot', 'engineer', 'student', 'instructor', 'other') then
    v_role := 'pilot';
  end if;

  insert into public.profiles (id, user_id, email, display_name, role)
  values (new.id, new.id, new.email, v_display_name, v_role)
  on conflict (id) do nothing;

  -- دفتر بداية جاهز لكل مستخدم جديد
  insert into public.notebooks (user_id, title, description, icon, color, sort_order)
  values (new.id,
          'دفتر الطيران',
          'دفترك الأول: سجّل الرحلات، أعمال الصيانة، وملاحظات الدراسة النظرية.',
          '✈️',
          '#0B3D91',
          10)
  returning id into v_notebook_id;

  insert into public.pages (user_id, notebook_id, title, icon, summary, template_key, sort_order)
  values (new.id,
          v_notebook_id,
          'ابدأ من هنا',
          '🛫',
          'مرحبًا بك في SU-35 Notes. أنشئ صفحة جديدة، واختر قالبًا جاهزًا (ملاحظة رحلة، صيانة، قائمة ما قبل الطيران).',
          'welcome',
          10);

  return new;
end;
$$;

comment on function public.handle_new_user() is 'ينشئ profiles + دفترًا افتراضيًا + صفحة ترحيب عند إنشاء حساب جديد.';

-- ───────────────────────────────────────────────────────────────────────────
-- 4) ربط المُشغّلات بالجداول
-- ───────────────────────────────────────────────────────────────────────────

-- 4.1 updated_at لكل الجداول ──────────────────────────────────────────────
do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'profiles', 'notebooks', 'pages', 'blocks', 'tags', 'page_tags', 'attachments'
  ] loop
    execute format('drop trigger if exists trg_set_updated_at on public.%I', v_table);
    execute format(
      'create trigger trg_set_updated_at before update on public.%I '
      'for each row execute function public.set_updated_at()', v_table);
  end loop;
end $$;

-- 4.2 التحقق من الآباء ────────────────────────────────────────────────────
drop trigger if exists trg_validate_page_parent on public.pages;
create trigger trg_validate_page_parent
  before insert or update of parent_page_id, notebook_id, user_id on public.pages
  for each row execute function public.validate_page_parent();

drop trigger if exists trg_validate_block_parent on public.blocks;
create trigger trg_validate_block_parent
  before insert or update of parent_block_id, page_id on public.blocks
  for each row execute function public.validate_block_parent();

-- 4.3 مزامنة النص المسطّح للصفحة مع الكتل ──────────────────────────────────
drop trigger if exists trg_refresh_page_content_text on public.blocks;
create trigger trg_refresh_page_content_text
  after insert or update or delete on public.blocks
  for each row execute function public.refresh_page_content_text();

-- 4.4 المستخدمون الجدد ────────────────────────────────────────────────────
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────────────────────────────────────────────────────────
-- 5) الفهارس (أداء الاستعلامات + البحث النصي الكامل)
-- ───────────────────────────────────────────────────────────────────────────
create index if not exists notebooks_user_idx
  on public.notebooks (user_id, is_archived, sort_order, updated_at desc);

create index if not exists pages_user_idx
  on public.pages (user_id, updated_at desc);

create index if not exists pages_notebook_idx
  on public.pages (notebook_id, parent_page_id, sort_order);

create index if not exists pages_parent_idx
  on public.pages (parent_page_id);

create index if not exists pages_flight_date_idx
  on public.pages (user_id, flight_date desc)
  where flight_date is not null;

create index if not exists pages_ata_idx
  on public.pages (user_id, ata_chapter)
  where ata_chapter is not null;

create index if not exists pages_aircraft_idx
  on public.pages (user_id, aircraft_type)
  where aircraft_type is not null;

-- ★ فهرس البحث النصي الكامل (tsvector) — نقطة أساسية في المتطلبات
create index if not exists pages_search_vector_idx
  on public.pages using gin (search_vector);

-- فهارس ثلاثية الأحرف للبحث الجزئي السريع (مفيدة جدًا للنصوص العربية)
create index if not exists pages_title_trgm_idx
  on public.pages using gin (title gin_trgm_ops);

create index if not exists pages_content_trgm_idx
  on public.pages using gin (coalesce(summary, '') gin_trgm_ops);

create index if not exists pages_tags_page_idx
  on public.page_tags (page_id);

create index if not exists page_tags_tag_idx
  on public.page_tags (tag_id);

create index if not exists tags_user_idx
  on public.tags (user_id, name);

create index if not exists blocks_page_idx
  on public.blocks (page_id, sort_order);

create index if not exists blocks_type_idx
  on public.blocks (page_id, type);

create index if not exists blocks_search_vector_idx
  on public.blocks using gin (search_vector);

create index if not exists blocks_content_idx
  on public.blocks using gin (content jsonb_path_ops);

create index if not exists attachments_page_idx
  on public.attachments (page_id, created_at desc);

create index if not exists attachments_user_idx
  on public.attachments (user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 6) RLS — أمن مستوى الصف: لا يصل المستخدم إلا إلى بياناته هو فقط
--    نستخدم (select auth.uid()) لتُحسب القيمة مرة واحدة لكل استعلام
--    (تحسين أداء موصى به من Supabase) بدل استدعائها لكل صف.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.profiles    enable row level security;
alter table public.notebooks   enable row level security;
alter table public.pages       enable row level security;
alter table public.blocks      enable row level security;
alter table public.tags        enable row level security;
alter table public.page_tags   enable row level security;
alter table public.attachments enable row level security;

-- 6.1 profiles ────────────────────────────────────────────────────────────
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = user_id and id = (select auth.uid()));

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_delete_own on public.profiles
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 6.2 notebooks ───────────────────────────────────────────────────────────
drop policy if exists notebooks_select_own on public.notebooks;
create policy notebooks_select_own on public.notebooks
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists notebooks_insert_own on public.notebooks;
create policy notebooks_insert_own on public.notebooks
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists notebooks_update_own on public.notebooks;
create policy notebooks_update_own on public.notebooks
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists notebooks_delete_own on public.notebooks;
create policy notebooks_delete_own on public.notebooks
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 6.3 pages ───────────────────────────────────────────────────────────────
-- القراءة والتعديل مقيّدان بالمالك، والإدخال/التحديث يُتحقق فيهما أيضًا من
-- ملكية الدفتر (حماية إضافية في العمق ضد أي ربط خاطئ).
drop policy if exists pages_select_own on public.pages;
create policy pages_select_own on public.pages
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists pages_insert_own on public.pages;
create policy pages_insert_own on public.pages
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.notebooks n
       where n.id = notebook_id
         and n.user_id = (select auth.uid())
    )
  );

drop policy if exists pages_update_own on public.pages;
create policy pages_update_own on public.pages
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.notebooks n
       where n.id = notebook_id
         and n.user_id = (select auth.uid())
    )
  );

drop policy if exists pages_delete_own on public.pages;
create policy pages_delete_own on public.pages
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 6.4 blocks ──────────────────────────────────────────────────────────────
drop policy if exists blocks_select_own on public.blocks;
create policy blocks_select_own on public.blocks
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists blocks_insert_own on public.blocks;
create policy blocks_insert_own on public.blocks
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.pages p
       where p.id = page_id
         and p.user_id = (select auth.uid())
    )
  );

drop policy if exists blocks_update_own on public.blocks;
create policy blocks_update_own on public.blocks
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.pages p
       where p.id = page_id
         and p.user_id = (select auth.uid())
    )
  );

drop policy if exists blocks_delete_own on public.blocks;
create policy blocks_delete_own on public.blocks
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 6.5 tags ────────────────────────────────────────────────────────────────
drop policy if exists tags_select_own on public.tags;
create policy tags_select_own on public.tags
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists tags_insert_own on public.tags;
create policy tags_insert_own on public.tags
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists tags_update_own on public.tags;
create policy tags_update_own on public.tags
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists tags_delete_own on public.tags;
create policy tags_delete_own on public.tags
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 6.6 page_tags ───────────────────────────────────────────────────────────
drop policy if exists page_tags_select_own on public.page_tags;
create policy page_tags_select_own on public.page_tags
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists page_tags_insert_own on public.page_tags;
create policy page_tags_insert_own on public.page_tags
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.pages p
                 where p.id = page_id and p.user_id = (select auth.uid()))
    and exists (select 1 from public.tags t
                 where t.id = tag_id and t.user_id = (select auth.uid()))
  );

drop policy if exists page_tags_update_own on public.page_tags;
create policy page_tags_update_own on public.page_tags
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists page_tags_delete_own on public.page_tags;
create policy page_tags_delete_own on public.page_tags
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- 6.7 attachments ─────────────────────────────────────────────────────────
drop policy if exists attachments_select_own on public.attachments;
create policy attachments_select_own on public.attachments
  for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists attachments_insert_own on public.attachments;
create policy attachments_insert_own on public.attachments
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.pages p
                 where p.id = page_id and p.user_id = (select auth.uid()))
  );

drop policy if exists attachments_update_own on public.attachments;
create policy attachments_update_own on public.attachments
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists attachments_delete_own on public.attachments;
create policy attachments_delete_own on public.attachments
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- 7) Storage — Bucket خاص للمرفقات (صور + PDF)
--    اصطلاح المسار: <user_id>/<page_id>/<file_name>
--    السياسات تمنع أي مستخدم من قراءة/كتابة ملفات غيره.
-- ═══════════════════════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'attachments',
  'attachments',
  false,
  52428800,   -- 50 ميغابايت للملف الواحد
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'application/pdf']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists storage_attachments_select_own on storage.objects;
create policy storage_attachments_select_own on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists storage_attachments_insert_own on storage.objects;
create policy storage_attachments_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists storage_attachments_update_own on storage.objects;
create policy storage_attachments_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists storage_attachments_delete_own on storage.objects;
create policy storage_attachments_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- ═══════════════════════════════════════════════════════════════════════════
-- 8) البحث النصي الكامل (RPC)
--    security invoker: الاستعلام يعمل بصلاحيات المستخدم، فتُطبَّق سياسات RLS
--    تلقائيًا ولا يرى إلا صفحاته.
--    الاستراتيجية: tsquery للكلمات المتقدمة + pg_trgm للبحث الجزئي
--    (مهم للعربية لأنها لغة اشتقاقية بلا قاموس بحث مدمج).
-- ═══════════════════════════════════════════════════════════════════════════
create or replace function public.search_notes(
  p_query         text,
  p_aircraft_type text default null,
  p_ata_chapter   text default null,
  p_notebook_id   uuid default null,
  p_limit         integer default 50,
  p_offset        integer default 0
)
returns table (
  page_id        uuid,
  notebook_id    uuid,
  notebook_title text,
  title          text,
  icon           text,
  summary        text,
  aircraft_type  text,
  tail_number    text,
  ata_chapter    text,
  airport_icao   text,
  flight_date    date,
  updated_at     timestamptz,
  relevance      real,
  snippet        text
)
language sql
stable
security invoker
set search_path = public
as $$
  with q as (
    select
      case
        when coalesce(btrim(p_query), '') = '' then null
        else websearch_to_tsquery('simple', btrim(p_query))
      end as tsq,
      '%' || coalesce(btrim(p_query), '') || '%' as likeq
  )
  select
    p.id,
    p.notebook_id,
    n.title,
    p.title,
    p.icon,
    p.summary,
    p.aircraft_type,
    p.tail_number,
    p.ata_chapter,
    p.airport_icao,
    p.flight_date,
    p.updated_at,
    coalesce(ts_rank(p.search_vector, q.tsq), 0)::real as relevance,
    case
      when q.tsq is null then left(coalesce(p.summary, p.content_text, ''), 160)
      else ts_headline('simple',
                       coalesce(nullif(p.summary, ''), nullif(p.content_text, ''), p.title),
                       q.tsq,
                       'MaxFragments=2, MaxWords=20, MinWords=6, StartSel=<b>, StopSel=</b>')
    end as snippet
  from public.pages p
  join public.notebooks n on n.id = p.notebook_id
  cross join q
  where p.is_archived = false
    and (
      q.tsq is null
      or p.search_vector @@ q.tsq
      or p.title ilike q.likeq
      or coalesce(p.content_text, '') ilike q.likeq
      or coalesce(p.tail_number, '') ilike q.likeq
    )
    and (p_aircraft_type is null or p.aircraft_type = p_aircraft_type)
    and (p_ata_chapter   is null or p.ata_chapter   = p_ata_chapter)
    and (p_notebook_id   is null or p.notebook_id   = p_notebook_id)
  order by relevance desc, p.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200))
  offset greatest(0, coalesce(p_offset, 0));
$$;

comment on function public.search_notes(text, text, text, uuid, integer, integer)
  is 'بحث نصي كامل في الصفحات (عنوان + حقول جوية + ملخص + محتوى الكتل) مع فلترة حسب الطائرة وفصل ATA.';

-- 8.1 إحصاءات سريعة للوحة الرئيسية (عدد الصفحات لكل دفتر) ─────────────────
create or replace view public.notebook_page_counts
with (security_invoker = true) as
  select
    n.id                       as notebook_id,
    n.user_id                  as user_id,
    count(p.id) filter (where p.is_archived = false) as pages_count,
    max(p.updated_at)          as last_page_update
  from public.notebooks n
  left join public.pages p on p.notebook_id = n.id
  group by n.id, n.user_id;

comment on view public.notebook_page_counts
  is 'عدد الصفحات وآخر تحديث لكل دفتر (security_invoker لتُطبَّق RLS الخاصة بالمستخدم).';

-- ═══════════════════════════════════════════════════════════════════════════
-- 9) الصلاحيات (Grants)
--    المستخدم المجهول anon لا يصل إلى أي جدول في هذا المخطط.
-- ═══════════════════════════════════════════════════════════════════════════
grant usage on schema public to anon, authenticated;

grant select, insert, update, delete on public.profiles    to authenticated;
grant select, insert, update, delete on public.notebooks   to authenticated;
grant select, insert, update, delete on public.pages       to authenticated;
grant select, insert, update, delete on public.blocks      to authenticated;
grant select, insert, update, delete on public.tags        to authenticated;
grant select, insert, update, delete on public.page_tags   to authenticated;
grant select, insert, update, delete on public.attachments to authenticated;

revoke all on public.profiles    from anon;
revoke all on public.notebooks   from anon;
revoke all on public.pages       from anon;
revoke all on public.blocks      from anon;
revoke all on public.tags        from anon;
revoke all on public.page_tags   from anon;
revoke all on public.attachments from anon;

grant select on public.notebook_page_counts to authenticated;

grant execute on function public.search_notes(text, text, text, uuid, integer, integer) to authenticated;
revoke execute on function public.search_notes(text, text, text, uuid, integer, integer) from anon;
revoke execute on function public.handle_new_user() from anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════════
-- 10) Realtime (اختياري — يُستخدم في المرحلة (د) للمزامنة الحيّة)
-- ═══════════════════════════════════════════════════════════════════════════
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime
        add table public.notebooks, public.pages, public.blocks;
    exception
      when duplicate_object then null;   -- مُضاف مسبقًا
      when others then null;
    end;
  end if;
end $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- 11) تحقّق سريع بعد التنفيذ (يمكن تشغيله يدويًا للاطمئنان)
-- ═══════════════════════════════════════════════════════════════════════════
-- select tablename, rowsecurity from pg_tables
--   where schemaname = 'public' order by tablename;               -- يجب أن تكون كلها true
-- select tablename, policyname, cmd from pg_policies
--   where schemaname = 'public' order by tablename, cmd;          -- 4 سياسات لكل جدول
-- select indexname from pg_indexes where schemaname = 'public' and indexdef ilike '%gin%';
-- select id, public, file_size_limit from storage.buckets where id = 'attachments';
