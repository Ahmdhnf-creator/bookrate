-- ============================================================================
-- 002_identity_books.sql — profiles (+signup trigger) + books + RLS
-- Jalankan setelah 001. Blok VERIFY di bawah.
-- ============================================================================

-- ---------------------------------------------------------------- profiles --
create table if not exists public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  username        text not null unique,
  display_name    text,
  bio             text,
  avatar_url      text,
  cover_url       text,
  join_date       timestamptz not null default now(),
  favorite_genres text[] not null default '{}',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint profiles_username_len check (char_length(username) between 3 and 30)
);

-- shared updated_at trigger function (SECURITY DEFINER, search_path kosong)
create or replace function public.set_updated_at() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'profiles_set_updated_at'
                 and tgrelid = 'public.profiles'::regclass) then
    create trigger profiles_set_updated_at
      before update on public.profiles
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- signup: buat profil otomatis (satu-satunya jalur INSERT profiles)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_username text;
begin
  v_username := coalesce(
    nullif(new.raw_user_meta_data ->> 'username', ''),
    'user_' || substr(new.id::text, 1, 8)
  );
  begin
    insert into public.profiles (id, username, display_name)
    values (
      new.id,
      v_username,
      coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), v_username)
    );
  exception when unique_violation then
    -- fallback username unik bila tabrakan (mis. 'user_abcdef12' sudah ada)
    insert into public.profiles (id, username, display_name)
    values (
      new.id,
      v_username || '_' || substr(gen_random_uuid()::text, 1, 4),
      coalesce(nullif(new.raw_user_meta_data ->> 'display_name', ''), v_username)
    );
  end;
  return new;
end $$;

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'on_auth_user_created'
                 and tgrelid = 'auth.users'::regclass) then
    create trigger on_auth_user_created
      after insert on auth.users
      for each row execute function public.handle_new_user();
  end if;
end $$;

-- ------------------------------------------------------------------- books --
-- Dedup: unique per identifier (keputusan 2). Minimal satu identifier.
create table if not exists public.books (
  id              uuid primary key default gen_random_uuid(),
  google_books_id text unique,
  openlibrary_id  text unique,
  isbn10          text unique,
  isbn13          text unique,
  title           text not null,
  authors         text[] not null default '{}',
  description     text,
  publisher       text,
  published_date  text,               -- teks: Google Books mengirim bulan/tahun parsial
  cover_url       text,
  categories      text[] not null default '{}',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint books_has_identifier check (
    google_books_id is not null or openlibrary_id is not null
    or isbn10 is not null or isbn13 is not null
  ),
  constraint books_title_len check (char_length(title) between 1 and 500)
);

do $$
begin
  if not exists (select 1 from pg_trigger where tgname = 'books_set_updated_at'
                 and tgrelid = 'public.books'::regclass) then
    create trigger books_set_updated_at
      before update on public.books
      for each row execute function public.set_updated_at();
  end if;
end $$;

-- -------------------------------------------------------------------- RLS --
alter table public.profiles enable row level security;
alter table public.books     enable row level security;

-- Grant EKSPLISIT (temuan audit 5 — tidak bergantung default privileges Supabase):
-- profiles: baca publik; UPDATE baris-own via RLS; INSERT hanya trigger signup; DELETE di luar MVP.
revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to anon, authenticated;
grant update on table public.profiles to authenticated;

-- books: INSERT-only untuk klien (temuan audit 2 — tanpa UPDATE/DELETE).
-- Pencarian = provider API live dari client; simpan = INSERT ON CONFLICT DO NOTHING;
-- koreksi metadata = operator via SQL Editor (lihat db/README.md).
revoke all on table public.books from anon, authenticated;
grant select on table public.books to anon, authenticated;
grant insert on table public.books to authenticated;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles'
                 and policyname = 'profiles_select_public') then
    execute $p$ create policy "profiles_select_public" on public.profiles
      for select using (true) $p$;
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles'
                 and policyname = 'profiles_update_own') then
    execute $p$ create policy "profiles_update_own" on public.profiles
      for update using (id = (select auth.uid()))
      with check (id = (select auth.uid())) $p$;
  end if;
  -- profiles: TANPA policy insert/delete untuk client (trigger signup; hapus akun di luar MVP)

  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'books'
                 and policyname = 'books_select_public') then
    execute $p$ create policy "books_select_public" on public.books
      for select using (true) $p$;
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'books'
                 and policyname = 'books_insert_authenticated') then
    execute $p$ create policy "books_insert_authenticated" on public.books
      for insert with check (auth.uid() is not null) $p$;
  end if;
  -- books: TANPA policy update/delete (insert-only; koreksi operator via SQL Editor)
end $$;

-- VERIFY
select 'profiles' as tbl, relrowsecurity from pg_class where oid = 'public.profiles'::regclass
union all
select 'books', relrowsecurity from pg_class where oid = 'public.books'::regclass;
-- harapkan: true, true

select tablename, policyname, cmd from pg_policies
where schemaname = 'public' and tablename in ('profiles', 'books')
order by tablename, policyname;
-- harapkan 4 policy (2 profiles + 2 books), tanpa insert/delete di profiles, tanpa update/delete di books

select grantee, privilege_type, table_name
from information_schema.table_privileges
where table_schema = 'public' and table_name in ('profiles', 'books')
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;
-- harapkan: profiles=select,update; books=select,insert (TANPA update/delete utk client)
