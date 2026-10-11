# مرجع قاعدة البيانات — SU-35 Notes

الملف التنفيذي: [`supabase/schema.sql`](../supabase/schema.sql) (يُنفَّذ مرة واحدة في SQL Editor).
بيانات البداية: [`supabase/seed.sql`](../supabase/seed.sql) (آمن للتشغيل المتكرر).

---

## 1) نظرة عامة

```
auth.users (Supabase Auth)
    │ 1:1
    ├─ profiles            الملف الشخصي (الاسم، الصفة، القاعدة، اللغة/الثيم المفضّل)
    │
    └─ notebooks           1) الدفتر … (data)
          └─ pages         2) الصفحة (مع parent_page_id للصفحات المتداخلة)
                ├─ blocks      3) الكتل: نص/عنوان/قائمة تحقق/جدول/صورة/PDF/كود/فاصل/اقتباس/تنبيه
                ├─ attachments 4) مرفقات Storage (صور/PDF)
                └─ page_tags ──► tags   الوسوم وربطها بالصفحات
```

**قاعدة صارمة:** كل جدول يحتوي `user_id` + `created_at` + `updated_at`، وجميع الجداول
مُفعَّل عليها RLS بسياسات تسمح للمستخدم بالوصول إلى صفوفه فقط.

---

## 2) الجداول

### 2.1 `profiles`
| العمود | النوع | ملاحظات |
|---|---|---|
| `id` / `user_id` | `uuid` | كلاهما يشير إلى `auth.users(id)` (‏`ON DELETE CASCADE`) |
| `email` | `text` | نسخة للقراءة السريعة |
| `display_name` | `text` | يُملأ من `raw_user_meta_data` عند التسجيل |
| `role` | `text` | `pilot` \| `engineer` \| `student` \| `instructor` \| `other` |
| `avatar_url` | `text` | رابط صورة (Storage) |
| `license_number` | `text` | رقم الرخصة |
| `home_base_icao` | `text` | قيد تحقّق: ٤ أحرف لاتينية |
| `preferred_locale` / `preferred_theme` | `text` | `ar`/`en` و `system`/`light`/`dark` |

### 2.2 `notebooks`
`title` (١–٢٠٠ حرفًا إلزامي)، `description`، `icon` (إيموجي)، `color` (‏`#RRGGBB`)،
`aircraft_type` (نوع افتراضي للدفتر)، `is_favorite`، `is_archived`، `sort_order`.

### 2.3 `pages` — جدول المحور
| المجموعة | الأعمدة |
|---|---|
| الهوية والترتيب | `id`, `user_id`, `notebook_id`, `parent_page_id`, `sort_order` |
| العرض | `title` (≤300)، `icon`, `summary` |
| المحتوى | `content_text` (نص مسطّح مجمّع من الكتل)، `template_key` |
| **حقول الطيران** | `aircraft_type`, `tail_number` (≤16), `ata_chapter` (≤8), `airport_icao` (٤ أحرف)، `flight_date` (date) |
| الحالة | `is_favorite`, `is_archived` |
| البحث | `search_vector tsvector` — عمود مولّد مع ترجيح: **A** العنوان، **B** الحقول الجوية، **C** الملخص + المحتوى |

**الصفحات المتداخلة:** `parent_page_id` يشير إلى `pages(id)` مع `ON DELETE CASCADE`
(حذف الصفحة الأم يحذف كل فروعها). المُشغّل `validate_page_parent` يمنع:
(١) أن يكون الأب في دفتر آخر أو لمستخدم آخر، (٢) الدوران الحلقي (صفحة داخل نفسها مباشرة أو عبر سلسلة).

### 2.4 `blocks`
| العمود | ملاحظات |
|---|---|
| `page_id` / `parent_block_id` | الكتلة الأب اختيارية (عناصر قائمة متداخلة)، ومُشغّل يتحقّق أنها من نفس الصفحة |
| `type` | `text` \| `heading` \| `checklist` \| `table` \| `image` \| `pdf` \| `code` \| `divider` \| `quote` \| `callout` |
| `sort_order` | `numeric(20,10)` لترتيب مرن (إدراج بين كتلتين بمتوسط القيمتين) |
| `content` | `jsonb` حسب النوع، أمثلة: `{"text":"..."}` / `{"items":[{"id":"1","text":"…","checked":false}]}` / `{"rows":[["A","B"]]}` |
| `text_content` | نص مسطّح **مولّد** من JSON عبر `block_plain_text(type, content)` — يُستخدم للبحث |

### 2.5 `tags` + `page_tags`
`tags.name` فريد لكل مستخدم (فهرس فريد على `(user_id, lower(btrim(name)))`) مع لون.
`page_tags` جدول ربط متعدد لمتعدد مع قيد تفرّد `(page_id, tag_id)`.

### 2.6 `attachments`
`page_id`, `block_id` (اختياري), `kind` (`image`/`pdf`/`other`), `file_name`,
`storage_path` (**فريد** داخل bucket المرفقات), `mime_type`, `size_bytes`, `width`, `height`, `caption`.

---

## 3) الدوال والمُشغّلات

| الدالة | الوظيفة |
|---|---|
| `set_updated_at()` | مُشغّل `BEFORE UPDATE` على كل جدول لتحديث `updated_at` تلقائيًا |
| `validate_page_parent()` | تحقّق صحة الصفحة الأب + منع الحلقات واختلاف الدفاتر |
| `validate_block_parent()` | تحقّق أن الكتلة الأب من الصفحة نفسها |
| `block_plain_text(type, content)` | استخراج نص مسطّح من `jsonb` حسب نوع الكتلة (تستخدمه الأعمدة المولّدة) |
| `refresh_page_content_text()` | بعد أي تغيير على `blocks` يعيد حساب `pages.content_text` (فتُحدَّث `search_vector` تلقائيًا) |
| `handle_new_user()` | `AFTER INSERT` على `auth.users`: ينشئ `profiles` + دفتر «دفتر الطيران» + صفحة ترحيب |

---

## 4) الفهارس

- دفاتر/صفحات: `(user_id, …)`, `notebook_id`, `parent_page_id`, `flight_date`, `ata_chapter`, `aircraft_type`.
- بحث: `GIN(search_vector)` على `pages` و`blocks` + `GIN(trgm)` على `pages.title` و`pages.content_text` للمطابقة الجزئية.
- كتل: `(page_id, sort_order)` و`GIN(content jsonb_path_ops)`.
- وسوم: `page_tags(page_id)` و`page_tags(tag_id)` و`tags(user_id, lower(name))`.

---

## 5) دالة البحث `search_notes` والعارض `notebook_page_counts`

```sql
select * from public.search_notes(
  'هيدروليك',   -- p_query         نص البحث (يدعم AND/OR/عبارة بين علامتي تنصيص)
  'A320',      -- p_aircraft_type فلترة اختيارية بنوع الطائرة
  '32',        -- p_ata_chapter   فلترة اختيارية بفصل ATA
  null,        -- p_notebook_id   فلترة اختيارية بدفتر
  20,          -- p_limit  (١..٢٠٠)
  0            -- p_offset
);
```
تُعيد: `page_id`, `notebook_id`, `notebook_title`, `title`, `icon`, `summary`,
`aircraft_type`, `tail_number`, `ata_chapter`, `airport_icao`, `flight_date`, `updated_at`,
`relevance` و`snippet` (مقتطف حول الكلمة بوسم `<b>`). تعمل بـ `security invoker` فتُطبَّق سياسات
RLS تلقائيًا، وتستخدم `websearch_to_tsquery('simple', …)` + `ts_rank` للترتيب، مع
`ilike` احتياطي للمطابقة الجزئية (مفيد للعربية).

```sql
select * from public.notebook_page_counts;  -- notebook_id, user_id, pages_count, last_page_update
```
عارض بـ `security_invoker = true` لتُطبَّق عليه سياسات RLS الخاصة بالمستخدم.

---

## 6) سياسات RLS (٤ سياسات لكل جدول)

لكل جدول في `public`: `select` / `insert` / `update` / `delete` مع شرط
`auth.uid() = user_id` (بصيغة `(select auth.uid())` لتحسين الأداء).

سياسات إضافية متقاطعة (دفاع في العمق) في `WITH CHECK`:

- `pages`: يجب أن يكون `notebook_id` لدفتر يملكه المستخدم.
- `blocks`: يجب أن تكون `page_id` لصفحة يملكها المستخدم.
- `page_tags`: يجب أن تكون الصفحة والوسم كلاهما للمستخدم.
- `attachments`: يجب أن تكون الصفحة للمستخدم، وأن يكون `block_id` (إن وُجد) في الصفحة نفسها.

---

## 7) Storage

- الـ bucket: `attachments` — **خاص** (`public = false`)، بحد ٥٠ ميجابايت للملف،
  وأنواع MIME محددة (صور + `application/pdf` + ملفات نصية).
- نمط المسار الإلزامي: `{user_id}/{page_id}/{file_name}`.
- سياسات `storage.objects` الأربع تتحقّق من `bucket_id = 'attachments'`
  ومن أن المقطع الأول من المسار = `auth.uid()`، بحيث لا يقرأ مستخدم ملفات غيره.

---

## 8) Realtime والصلاحيات

- تُضاف `notebooks`, `pages`, `blocks` إلى منشور `supabase_realtime` (يُستخدم في المرحلة د).
- `authenticated` يملك صلاحيات `select/insert/update/delete` على جداول `public`،
  و`anon` **مسحوب منه كل شيء**، و`handle_new_user()` غير قابل للتنفيذ من `anon/authenticated`.

---

## 9) تحقّق سريع بعد التنفيذ

```sql
select tablename, rowsecurity from pg_tables where schemaname = 'public';      -- كلها true
select tablename, policyname, cmd from pg_policies where schemaname = 'public'; -- ٤ لكل جدول
select indexname from pg_indexes where schemaname = 'public' and indexdef ilike '%gin%';
select id, public, file_size_limit from storage.buckets where id = 'attachments';
```
