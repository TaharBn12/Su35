-- ═══════════════════════════════════════════════════════════════════════════
--  SU-35 Notes — بيانات البداية والتجربة (seed)
--  يُنفَّذ **بعد** schema.sql، في محرّر SQL في Supabase أو عبر psql.
--  الملف آمن للتشغيل أكثر من مرة (idempotent) ولا يُنشئ تكرارًا.
--
--  ماذا يفعل؟
--    1) يُنشئ صفوف profiles ناقصة للحسابات القديمة التي أُنشئت قبل المخطط.
--    2) يمنح كل مستخدم لديه صفر دفاتر: دفتر «دفتر الطيران» + صفحة ترحيب.
--    3) يضيف ثلاث صفحات تجريبية ببيانات جوية كاملة:
--         • ملاحظة رحلة (Flight Log)   • قائمة ما قبل الطيران (Checklist)
--         • تقرير عطل (Defect Report)
--       مع كتل محتوى حقيقية لتجربة المحرر في المرحلة (ب) والبحث في المرحلة (ج).
--    4) يُنشئ وسومًا (CFM56 / Gear / Type-Rating / تدريب) ويربطها بالصفحات.
--
--  لتشغيله لمستخدم واحد فقط: أضِف شرط `and u.email = 'you@example.com'`
--  إلى استعلام الحلقة عند السطر المعلَّم بـ  ⟵ (الفلترة)
-- ═══════════════════════════════════════════════════════════════════════════

begin;

-- ───────────────────────────────────────────────────────────────────────────
-- 1) استكمال صفوف profiles الناقصة (الحسابات المنشأة قبل تنفيذ المخطط)
-- ───────────────────────────────────────────────────────────────────────────
insert into public.profiles (id, user_id, email, display_name, role)
select u.id,
       u.id,
       u.email,
       coalesce(nullif(btrim(u.raw_user_meta_data ->> 'display_name'), ''),
                split_part(coalesce(u.email, 'طيار'), '@', 1)),
       case
         when u.raw_user_meta_data ->> 'role' in ('pilot', 'engineer', 'student', 'instructor', 'other')
           then u.raw_user_meta_data ->> 'role'
         else 'pilot'
       end
from auth.users u
where not exists (select 1 from public.profiles p where p.user_id = u.id);

-- ───────────────────────────────────────────────────────────────────────────
-- 2) الدفتر الافتراضي للجميع (نفس ما تفعله handle_new_user للحسابات الجديدة)
-- ───────────────────────────────────────────────────────────────────────────
insert into public.notebooks (user_id, title, description, icon, color, sort_order)
select u.id,
       'دفتر الطيران',
       'دفترك الأول: سجّل الرحلات، أعمال الصيانة، وملاحظات الدراسة النظرية.',
       '✈️',
       '#0B3D91',
       10
from auth.users u
where not exists (select 1 from public.notebooks n where n.user_id = u.id);

-- صفحة ترحيب داخل الدفتر الافتراضي لمن لا صفحة له بعد
insert into public.pages (user_id, notebook_id, title, icon, summary, template_key, sort_order)
select n.user_id,
       n.id,
       'ابدأ من هنا',
       '🛫',
       'مرحبًا بك في SU-35 Notes. أنشئ صفحة جديدة، واختر قالبًا جاهزًا (ملاحظة رحلة، صيانة، قائمة ما قبل الطيران).',
       'welcome',
       10
from public.notebooks n
where n.title = 'دفتر الطيران'
  and not exists (select 1 from public.pages p where p.notebook_id = n.id);

-- ───────────────────────────────────────────────────────────────────────────
-- 3) وسوم جاهزة لكل مستخدم (الوسوم مخصّصة لكل مستخدم: user_id + الاسم)
-- ───────────────────────────────────────────────────────────────────────────
insert into public.tags (user_id, name, color)
select u.id, t.name, t.color
from auth.users u
cross join (values
    ('CFM56',       '#4FA3E3'),
    ('Gear',        '#F0A02A'),
    ('Type-Rating', '#2E9E6B'),
    ('تدريب',        '#8E6BD8')
  ) as t (name, color)
where not exists (
    select 1 from public.tags x
     where x.user_id = u.id and lower(btrim(x.name)) = lower(btrim(t.name))
);

-- ───────────────────────────────────────────────────────────────────────────
-- 4) المحتوى التجريبي: ثلاث صفحات + كتل + ربط الوسوم
--    الحلقة تعمل لكل مستخدم مسجّل. ⟵ (الفلترة)
-- ───────────────────────────────────────────────────────────────────────────
do $$
declare
  v_user         record;
  v_notebook_id  uuid;
  v_flight_id    uuid;
  v_checklist_id uuid;
  v_defect_id    uuid;
begin
  for v_user in
    select u.id as user_id
      from auth.users u
      join public.notebooks n on n.user_id = u.id
     where n.title = 'دفتر الطيران'
  loop
    select n.id into v_notebook_id
      from public.notebooks n
     where n.user_id = v_user.user_id and n.title = 'دفتر الطيران'
     order by n.created_at
     limit 1;

    -- ── 4.1 ملاحظة رحلة (Flight Log) ─────────────────────────────────────
    select p.id into v_flight_id
      from public.pages p
     where p.user_id = v_user.user_id and p.title = 'رحلة تجريبية — OERK إلى OEJN'
     limit 1;

    if v_flight_id is null then
      insert into public.pages (user_id, notebook_id, title, icon, summary,
                                aircraft_type, tail_number, ata_chapter,
                                airport_icao, flight_date, template_key, sort_order)
      values (v_user.user_id, v_notebook_id,
              'رحلة تجريبية — OERK إلى OEJN',
              '🛩️',
              'مثال لملاحظة رحلة مع بيانات الطائرة والأوزان وحسابات الإقلاع.',
              'A320', 'HZ-A12', '22', 'OERK', current_date, 'flight_log', 20)
      returning id into v_flight_id;
    end if;

    if not exists (select 1 from public.blocks b where b.page_id = v_flight_id) then
      insert into public.blocks (user_id, page_id, type, sort_order, content) values
        (v_user.user_id, v_flight_id, 'heading', 100,
         '{"text": "بيانات الرحلة", "level": 1}'::jsonb),
        (v_user.user_id, v_flight_id, 'text', 200,
         '{"text": "الإقلاع من OERK (الرياض) إلى OEJN (جدة). الطقس جيد، الرياح 320/08، مدى الرؤية 10 كم."}'::jsonb),
        (v_user.user_id, v_flight_id, 'table', 300,
         '{"columns": ["البند", "القيمة"], "rows": [["وزن الإقلاع", "68.4 t"], ["V1", "142 kt"], ["VR", "148 kt"], ["V2", "152 kt"], ["وقود الرحلة", "6.2 t"]]}'::jsonb),
        (v_user.user_id, v_flight_id, 'heading', 400,
         '{"text": "ملاحظات الطائرة", "level": 2}'::jsonb),
        (v_user.user_id, v_flight_id, 'text', 500,
         '{"text": "محرك CFM56-5B: قراءات EGT طبيعية في الصعود. لا توجد ملاحظات على نظام الهيدروليك."}'::jsonb),
        (v_user.user_id, v_flight_id, 'divider', 600, '{}'::jsonb),
        (v_user.user_id, v_flight_id, 'code', 700,
         '{"language": "text", "code": "OERK 121200Z 32008KT 9999 FEW040 34/12 Q1008 NOSIG"}'::jsonb);
    end if;

    -- ── 4.2 قائمة ما قبل الطيران (Pre-flight Checklist) ───────────────────
    select p.id into v_checklist_id
      from public.pages p
     where p.user_id = v_user.user_id and p.title = 'قائمة ما قبل الطيران — A320'
     limit 1;

    if v_checklist_id is null then
      insert into public.pages (user_id, notebook_id, title, icon, summary,
                                aircraft_type, airport_icao, template_key, sort_order)
      values (v_user.user_id, v_notebook_id,
              'قائمة ما قبل الطيران — A320',
              '✅',
              'قائمة تحقق تشغيلية بالبنود الأساسية قبل الإقلاع.',
              'A320', 'OERK', 'preflight_checklist', 30)
      returning id into v_checklist_id;
    end if;

    if not exists (select 1 from public.blocks b where b.page_id = v_checklist_id) then
      insert into public.blocks (user_id, page_id, type, sort_order, content) values
        (v_user.user_id, v_checklist_id, 'heading', 100,
         '{"text": "قبل الإقلاع", "level": 1}'::jsonb),
        (v_user.user_id, v_checklist_id, 'checklist', 200,
         '{"items": [
            {"id": "pf-1", "text": "مستندات الطائرة و MEL", "checked": true},
            {"id": "pf-2", "text": "مستويات الزيوت والهيدروليك", "checked": true},
            {"id": "pf-3", "text": "فحص المشغّلات (Walkaround)", "checked": false},
            {"id": "pf-4", "text": "الأوزان والحسابات (V1/VR/V2)", "checked": false},
            {"id": "pf-5", "text": "الوقود مقابل خطة الرحلة", "checked": false}
          ]}'::jsonb),
        (v_user.user_id, v_checklist_id, 'callout', 300,
         '{"title": "تذكير", "text": "أي بند غير مطابق يُسجَّل في تقرير عطل فورًا مع ذكر فصل ATA."}'::jsonb);
    end if;

    -- ── 4.3 تقرير عطل (Defect Report) ────────────────────────────────────
    select p.id into v_defect_id
      from public.pages p
     where p.user_id = v_user.user_id and p.title = 'تقرير عطل — ATA 32'
     limit 1;

    if v_defect_id is null then
      insert into public.pages (user_id, notebook_id, title, icon, summary,
                                aircraft_type, tail_number, ata_chapter, template_key, sort_order)
      values (v_user.user_id, v_notebook_id,
              'تقرير عطل — ATA 32',
              '🛠️',
              'مثال لتقرير عطل: العجلة الأمامية — أثر تسريب زيت الهيدروليك.',
              'A320', 'HZ-A12', '32', 'defect_report', 40)
      returning id into v_defect_id;
    end if;

    if not exists (select 1 from public.blocks b where b.page_id = v_defect_id) then
      insert into public.blocks (user_id, page_id, type, sort_order, content) values
        (v_user.user_id, v_defect_id, 'heading', 100,
         '{"text": "تقرير عطل", "level": 1}'::jsonb),
        (v_user.user_id, v_defect_id, 'text', 200,
         '{"text": "أثناء الفحص قبل الطيران لوحظ أثر زيت هيدروليك أسفل العجلة الأمامية."}'::jsonb),
        (v_user.user_id, v_defect_id, 'table', 300,
         '{"columns": ["الحقل", "القيمة"], "rows": [["فصل ATA", "32"], ["الخطورة", "متوسطة"], ["الإجراء المطلوب", "فحص العدة الهيدروليكية واستبدال السيل إن لزم"], ["حالة الإصلاح", "بانتظار الصيانة"]]}'::jsonb),
        (v_user.user_id, v_defect_id, 'quote', 400,
         '{"text": "لا تُقلع الطائرة قبل إغلاق التقرير من قسم الصيانة."}'::jsonb);
    end if;

    -- ── 4.4 ربط الوسوم بالصفحات ──────────────────────────────────────────
    insert into public.page_tags (user_id, page_id, tag_id)
    select v_user.user_id, v_flight_id, t.id
      from public.tags t
     where t.user_id = v_user.user_id and lower(btrim(t.name)) in ('cfm56', 'type-rating')
    on conflict (page_id, tag_id) do nothing;

    insert into public.page_tags (user_id, page_id, tag_id)
    select v_user.user_id, v_defect_id, t.id
      from public.tags t
     where t.user_id = v_user.user_id and lower(btrim(t.name)) in ('gear', 'تدريب')
    on conflict (page_id, tag_id) do nothing;
  end loop;
end $$;

-- ───────────────────────────────────────────────────────────────────────────
-- 5) تحديث البحث النصي للصفحات التي أُدخلت لها كتل في هذا الملف
--    (المُشغّل يقوم بذلك تلقائيًا؛ هذه الخطوة احتياطية للصفحات القديمة)
-- ───────────────────────────────────────────────────────────────────────────
update public.pages p
   set content_text = agg.txt
  from (
    select b.page_id, string_agg(b.text_content, E'\n' order by b.sort_order) as txt
      from public.blocks b
     group by b.page_id
  ) agg
 where p.id = agg.page_id
   and p.content_text is distinct from agg.txt;

commit;

-- ═══════════════════════════════════════════════════════════════════════════
--  تحقّق سريع بعد التنفيذ (اختياري):
--    select n.title, count(p.id) as pages
--      from public.notebooks n left join public.pages p on p.notebook_id = n.id
--     group by n.title order by n.title;
--
--    select p.title, p.aircraft_type, p.ata_chapter, left(p.content_text, 60) as preview
--      from public.pages p order by p.created_at;
--
--    select * from public.search_notes('هيدروليك', null, null, null, 10, 0);
-- ═══════════════════════════════════════════════════════════════════════════
