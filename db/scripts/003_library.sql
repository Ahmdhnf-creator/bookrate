-- ============================================================================
-- 003_library.sql — library_entries (visibility, progress, notes privat) + RLS
-- Jalankan setelah 002. Keputusan: notes SELALU hanya pemilik (via hak kolom +
-- fungsi library_entry_notes); visibility default PRIVATE (default-deny).
-- ============================================================================

create table if not exists public.library_entries (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles (id) on delete cascade,
  book_id    uuid not null references public.books (id) on delete cascade,
  status     public.reading_status not null default 'WANT_TO_READ',
  progress   smallint not null default 0,
  start_date date,
  finish_date date,
  visibility public.library_visibility not null default 'PRIVATE',
  notes      text,                                  -- SELALU privat
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint library_progress_range check (progress >= 0 and progress <= 100),
  constraint library_unique_entry unique (user_id, book_id)
);

create index if not exists library_entries_user_id_idx on public.library_entries (user_id);

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'library_entries_set_updated_at'
                 and tgrelid = 'public.library_entries'::regclass) then
    create trigger library_entries_set_updated_at
      before update on public.library_entries
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- -------------------------------------------------------------------- RLS --
alter table public.library_entries enable row level security;

-- Hak kolom: notes TIDAK boleh terbaca lewat SELECT tabel (bahkan baris PUBLIC).
-- UPDATE notes tetap diizinkan untuk pemilik (menulis tanpa membaca lewat tabel).
revoke all on table public.library_entries from anon, authenticated;
grant select (id, user_id, book_id, status, progress, start_date, finish_date,
             visibility, created_at, updated_at)
      on public.library_entries to anon, authenticated;
grant insert, update, delete on public.library_entries to authenticated;
-- (grant di atas hanya otorisasi role; RLS tetap membatasi baris per kebijakan)

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'library_entries'
                 and policyname = 'library_select_own_or_public') then
    execute $p$ create policy "library_select_own_or_public" on public.library_entries
      for select using (
        user_id = (select auth.uid())
        or visibility = 'PUBLIC'
      ) $p$;
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'library_entries'
                 and policyname = 'library_insert_own') then
    execute $p$ create policy "library_insert_own" on public.library_entries
      for insert with check (user_id = (select auth.uid())) $p$;
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'library_entries'
                 and policyname = 'library_update_own') then
    execute $p$ create policy "library_update_own" on public.library_entries
      for update using (user_id = (select auth.uid()))
      with check (user_id = (select auth.uid())) $p$;
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'library_entries'
                 and policyname = 'library_delete_own') then
    execute $p$ create policy "library_delete_own" on public.library_entries
      for delete using (user_id = (select auth.uid())) $p$;
  end if;
end $$;

-- ------------------------------------------------- fungsi baca notes (RLS) --
-- SECURITY DEFINER dengan cek kepemilikan DI DALAM fungsi; search_path kosong.
-- DIREVOKE dari public/anon; hanya authenticated (pemilik) yang boleh execute.
create or replace function public.library_entry_notes(entry_id uuid) returns text
language sql security definer set search_path = '' as $$
  select l.notes
  from public.library_entries l
  where l.id = entry_id
    and l.user_id = (select auth.uid());
$$;

revoke execute on function public.library_entry_notes(uuid) from public, anon;
grant execute on function public.library_entry_notes(uuid) to authenticated;

-- VERIFY
select relrowsecurity from pg_class where oid = 'public.library_entries'::regclass; -- true
select policyname, cmd from pg_policies
where schemaname = 'public' and tablename = 'library_entries' order by policyname; -- 4 policy
select grantee, string_agg(column_name, ', ' order by column_name) as selected_columns
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'library_entries'
  and privilege_type = 'SELECT' and grantee in ('anon', 'authenticated')
group by grantee;
-- harapkan: kolom 'notes' TIDAK ada di daftar grantee manapun
select p.proname, p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner) as owner
from pg_proc p where p.proname = 'library_entry_notes';
-- harapkan: prosecdef=t, proconfig={search_path=}, owner=postgres
