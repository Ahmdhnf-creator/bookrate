-- ============================================================================
-- 001_enums.sql — BookRate Execution Task 2 (Dashboard-first)
-- Jalankan: Supabase Dashboard → SQL Editor → Run. Lalu VERIFY di bawah.
-- Catatan: pg_trgm DITUNDA (keputusan 2026-11-08) — jangan tambahkan.
-- ============================================================================

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'reading_status') then
    create type public.reading_status as enum ('WANT_TO_READ', 'READING', 'FINISHED');
  end if;

  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'activity_type') then
    create type public.activity_type as enum (
      'BOOK_ADDED', 'BOOK_STARTED', 'BOOK_FINISHED',
      'REVIEW_CREATED', 'RATING_CREATED', 'READING_PROGRESS_UPDATED'
    );
  end if;

  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'notification_type') then
    create type public.notification_type as enum ('NEW_FOLLOWER', 'REVIEW_LIKED', 'REVIEW_COMMENTED');
  end if;

  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'public' and t.typname = 'library_visibility') then
    create type public.library_visibility as enum ('PUBLIC', 'PRIVATE');
  end if;
end $$;

-- VERIFY: harus keluar 4 baris (activity_type, library_visibility, notification_type, reading_status)
select t.typname
from pg_type t
join pg_namespace n on n.oid = t.typnamespace
where n.nspname = 'public' and t.typtype = 'e'
order by t.typname;
