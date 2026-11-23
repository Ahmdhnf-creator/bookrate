-- ============================================================================
-- 007_verify_schema.sql — audit akhir Execution Task 2 (GATE V2).
-- Jalankan setelah 006, sebagai postgres (SQL Editor default).
-- Tidak mengubah data. Semua baris `pass` harus true; ringkasan akhir harus
-- berbunyi 'VERIFY SCHEMA: ALL ... CHECKS PASSED'.
-- Kini 31 checks (20 awal + 11 revisi audit 2026-11-08).
-- ============================================================================

-- ------------------------------------------------------------- inventaris --
-- 9 tabel yang wajib ada dengan RLS aktif
select c.relname as tabel, c.relrowsecurity as rls_aktif
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('profiles', 'books', 'library_entries', 'reviews',
                    'likes', 'comments', 'follows', 'activities', 'notifications')
  and c.relkind = 'r'
order by c.relname;
-- harapkan 9 baris, rls_aktif = true semua

-- seluruh policy (inventaris; dipakai pemeriksaan ringkasan di bawah)
select tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

-- trigger fungsional
select c.relname as tabel, t.tgname
from pg_trigger t
join pg_class c on c.oid = t.tgrelid
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and not t.tgisinternal
order by c.relname, t.tgname;

-- enum, view, indeks unik parsial
select t.typname from pg_type t
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public' and t.typtype = 'e' order by t.typname;
-- harapkan 4: activity_type, library_visibility, notification_type, reading_status

select viewname from pg_views
where schemaname = 'public' and viewname in ('book_rating_summary', 'profile_stats')
order by viewname;

select indexname from pg_indexes
where schemaname = 'public' and tablename = 'reviews' order by indexname;

-- ------------------------------------------------- ringkasan pass / fail ----
with checks as (
  select '01 RLS aktif di 9/9 tabel' as name,
         (select count(*)
          from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relkind = 'r'
            and c.relname in ('profiles', 'books', 'library_entries', 'reviews',
                              'likes', 'comments', 'follows', 'activities', 'notifications')
            and c.relrowsecurity) = 9 as pass
  union all select '02 activities TANPA policy INSERT',
         not exists (select 1 from pg_policies
                     where schemaname = 'public' and tablename = 'activities' and cmd = 'INSERT')
  union all select '03 notifications TANPA policy INSERT',
         not exists (select 1 from pg_policies
                     where schemaname = 'public' and tablename = 'notifications' and cmd = 'INSERT')
  union all select '04 reviews TANPA policy DELETE (hanya soft delete)',
         not exists (select 1 from pg_policies
                     where schemaname = 'public' and tablename = 'reviews' and cmd = 'DELETE')
  union all select '05 comments TANPA policy UPDATE',
         not exists (select 1 from pg_policies
                     where schemaname = 'public' and tablename = 'comments' and cmd = 'UPDATE')
  union all select '06 profiles TANPA policy INSERT/DELETE (tulis via trigger signup)',
         not exists (select 1 from pg_policies
                     where schemaname = 'public' and tablename = 'profiles'
                       and cmd in ('INSERT', 'DELETE'))
  union all select '07 notes TANPA hak SELECT untuk anon & authenticated',
         not exists (select 1 from information_schema.column_privileges
                     where table_schema = 'public' and table_name = 'library_entries'
                       and column_name = 'notes'
                       and privilege_type = 'SELECT'
                       and grantee in ('anon', 'authenticated'))
  union all select '08 fungsi library_entry_notes: SECURITY DEFINER',
         (select prosecdef from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'library_entry_notes') = true
  union all select '09 fungsi library_entry_notes: search_path kosong',
         (select p.proconfig @> array['search_path='] from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'library_entry_notes') = true
  union all select '10 library_entry_notes: revoke dari anon',
         has_function_privilege('anon', 'public.library_entry_notes(uuid)', 'execute') = false
  union all select '11 library_entry_notes: owner = postgres (definer)',
         (select pg_get_userbyid(p.proowner) = 'postgres' from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'library_entry_notes') = true
  union all select '12 library_entry_notes: grant ke authenticated',
         has_function_privilege('authenticated', 'public.library_entry_notes(uuid)', 'execute') = true
  union all select '13 trigger signup ada di auth.users',
         exists (select 1 from pg_trigger t
                 join pg_class c on c.oid = t.tgrelid
                 join pg_namespace n on n.oid = c.relnamespace
                 where n.nspname = 'auth' and c.relname = 'users'
                   and t.tgname = 'on_auth_user_created' and not t.tgisinternal)
  union all select '14 5 trigger fungsional aktivitas/notifikasi ada',
         (select count(*) from pg_trigger t
          join pg_class c on c.oid = t.tgrelid
          join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and not t.tgisinternal
            and t.tgname in ('trg_reviews_activity', 'trg_library_activity',
                             'trg_likes_notification', 'trg_comments_notification',
                             'trg_follows_notification')) = 5
  union all select '15 4 enum tipenya ada',
         (select count(*) from pg_type t
          join pg_namespace n on n.oid = t.typnamespace
          where n.nspname = 'public' and t.typtype = 'e'
            and t.typname in ('reading_status', 'activity_type',
                              'notification_type', 'library_visibility')) = 4
  union all select '16 view book_rating_summary: security_invoker ON',
         (select c.reloptions @> array['security_invoker=true'] from pg_class c
          join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relname = 'book_rating_summary') = true
  union all select '17 indeks unik parsial 1 review aktif per user/buku ada',
         exists (select 1 from pg_indexes
                 where schemaname = 'public' and tablename = 'reviews'
                   and indexname = 'reviews_one_active_per_book')
  union all select '18 constraint follows_no_self ada',
         exists (select 1 from pg_constraint
                 where conname = 'follows_no_self'
                   and connamespace = 'public'::regnamespace)
  union all select '19 2 view publik ada (book_rating_summary, profile_stats)',
         (select count(*) from pg_views
          where schemaname = 'public'
            and viewname in ('book_rating_summary', 'profile_stats')) = 2
  union all select '20 library_entries: 4 policy (select own/public + insert/update/delete own)',
         (select count(*) from pg_policies
          where schemaname = 'public' and tablename = 'library_entries') = 4
  union all select '21 books TANPA policy UPDATE/DELETE (insert-only klien)',
         not exists (select 1 from pg_policies
                     where schemaname = 'public' and tablename = 'books'
                       and cmd in ('UPDATE', 'DELETE'))
  union all select '22 books TANPA grant UPDATE/DELETE ke anon & authenticated',
         not exists (select 1 from information_schema.table_privileges
                     where table_schema = 'public' and table_name = 'books'
                       and grantee in ('anon', 'authenticated')
                       and privilege_type in ('UPDATE', 'DELETE'))
  union all select '23 profile_stats hanya menghitung entri PUBLIC (>= 2 kemunculan)',
         (select (length(pg_get_viewdef('public.profile_stats'::regclass, true))
                 - length(replace(pg_get_viewdef('public.profile_stats'::regclass, true),
                                  'PUBLIC', ''))) / 4 >= 2
          and pg_get_viewdef('public.profile_stats'::regclass, true) like '%visibility%')
  union all select '24 notifications: UPDATE grant authenticated HANYA kolom read',
         (select coalesce(string_agg(column_name, ', ' order by column_name), '')
          from information_schema.column_privileges
          where table_schema = 'public' and table_name = 'notifications'
            and grantee = 'authenticated' and privilege_type = 'UPDATE') = 'read'
  union all select '25 notifications: anon TANPA grant apapun',
         not exists (select 1 from information_schema.column_privileges
                     where table_schema = 'public' and table_name = 'notifications'
                       and grantee = 'anon')
         and not exists (select 1 from information_schema.table_privileges
                         where table_schema = 'public' and table_name = 'notifications'
                           and grantee = 'anon')
  union all select '26 notifications: TANPA grant INSERT/DELETE ke authenticated',
         not exists (select 1 from information_schema.table_privileges
                     where table_schema = 'public' and table_name = 'notifications'
                       and grantee = 'authenticated'
                       and privilege_type in ('INSERT', 'DELETE'))
  union all select '27 activities: anon & authenticated HANYA SELECT (tanpa I/U/D)',
         not exists (select 1 from information_schema.table_privileges
                     where table_schema = 'public' and table_name = 'activities'
                       and grantee in ('anon', 'authenticated')
                       and privilege_type in ('INSERT', 'UPDATE', 'DELETE'))
  union all select '28 profiles: klien TANPA grant INSERT/DELETE',
         not exists (select 1 from information_schema.table_privileges
                     where table_schema = 'public' and table_name = 'profiles'
                       and grantee in ('anon', 'authenticated')
                       and privilege_type in ('INSERT', 'DELETE'))
  union all select '29 likes/comments/follows: authenticated TANPA grant UPDATE',
         not exists (select 1 from information_schema.table_privileges
                     where table_schema = 'public'
                       and table_name in ('likes', 'comments', 'follows')
                       and grantee = 'authenticated' and privilege_type = 'UPDATE')
  union all select '30 reviews: authenticated TANPA grant DELETE (soft-delete via update)',
         not exists (select 1 from information_schema.table_privileges
                     where table_schema = 'public' and table_name = 'reviews'
                       and grantee in ('anon', 'authenticated')
                       and privilege_type = 'DELETE')
  union all select '31 7 fungsi definer: owner postgres + search_path kosong',
         (select count(*) from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public'
            and p.proname in ('set_updated_at', 'handle_new_user',
                              'trg_review_activity', 'trg_library_activity',
                              'trg_like_notification', 'trg_comment_notification',
                              'trg_follow_notification')
            and p.prosecdef
            and p.proowner = 'postgres'::regrole
            and p.proconfig @> array['search_path=']) = 7
)
select name as pemeriksaan,
       case when pass then 'PASS' else 'FAIL' end as hasil
from checks

union all

select '=== RINGKASAN ===',
       case
         when count(*) = count(*) filter (where pass)
           then 'VERIFY SCHEMA: ALL ' || count(*) || ' CHECKS PASSED'
         else 'VERIFY SCHEMA: ' || count(*) filter (where not pass)
              || ' CHECKS FAILED dari ' || count(*) || ' — perbaiki sebelum menandai SCHEMA_STATE'
       end
from checks;
