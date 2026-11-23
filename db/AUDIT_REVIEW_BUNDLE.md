  # BookRate — Audit Review Bundle (Execution Task 2)

  Salinan **lengkap dan verbatim** dari 9 file sumber `db/` untuk keperluan security review **sebelum** SQL dijalankan di Supabase.

  - File sumber tidak diubah; tidak ada SQL yang dijalankan; tidak ada perubahan database/konfigurasi Supabase; tidak ada commit.
  - Setiap bagian menyalin seluruh isi file tanpa dipotong, dipisah dengan penanda `BEGIN`/`END`.
  - Dibuat: 2026-11-08.

  Daftar isi bundle:

  | # | File sumber |
  |---|---|
  | 1 | `db/README.md` |
  | 2 | `db/SCHEMA_STATE.md` |
  | 3 | `db/scripts/001_enums.sql` |
  | 4 | `db/scripts/002_identity_books.sql` |
  | 5 | `db/scripts/003_library.sql` |
  | 6 | `db/scripts/004_reviews_social.sql` |
  | 7 | `db/scripts/005_activity_notifications.sql` |
  | 8 | `db/scripts/006_negative_tests.sql` |
  | 9 | `db/scripts/007_verify_schema.sql` |

  ---

  ## File 1 — db/README.md

  <!-- BEGIN: db/README.md -->
  ````
  # BookRate Database (Dashboard-First)

  Sumber kebenaran skema: file SQL di `scripts/`. Eksekusi selalu **manual** melalui Supabase Dashboard → SQL Editor. Tanpa Supabase CLI, Docker, local Supabase, Edge Functions, atau custom API untuk MVP.

  ## Urutan eksekusi (wajib berurutan)

  | # | Skrip | Isi ringkas |
  |---|---|---|
  | 1 | `scripts/001_enums.sql` | 4 enum (reading_status, activity_type, notification_type, library_visibility); pg_trgm ditunda |
  | 2 | `scripts/002_identity_books.sql` | `profiles` + trigger signup + `books` (dedup identifier) + RLS |
  | 3 | `scripts/003_library.sql` | `library_entries` (visibility, progress, notes) + RLS + hak kolom notes + fungsi `library_entry_notes` |
  | 4 | `scripts/004_reviews_social.sql` | `reviews` (soft delete), `likes`, `comments`, `follows` + view `book_rating_summary` + `profile_stats` + RLS |
  | 5 | `scripts/005_activity_notifications.sql` | `activities`, `notifications` (insert hanya trigger) + trigger notifikasi/aktivitas + RLS |
  | 6 | `scripts/006_negative_tests.sql` | Seluruh negative authorization test (2 akun uji + anon); satu transaksi, diakhiri ROLLBACK (nol residu) |
  | 7 | `scripts/007_verify_schema.sql` | Audit akhir: RLS 9 tabel, policy, grant kolom notes, fungsi definer (owner/proconfig), ketiadaan policy INSERT di activities/notifications |

  ## Aturan kerja

  1. Sebelum Run: salin seluruh isi skrip → SQL Editor → **Run**; baca blok `-- VERIFY`.
  2. Setelah sukses/tidak: perbarui `../SCHEMA_STATE.md` (tanggal + hasil).
  3. **Perubahan skema hanya lewat skrip di repo** — jangan mengubah skema langsung dari Table Editor UI (anti-drift).
  4. Berhenti pada error; jangan lanjut ke nomor berikutnya.
  5. Sebelum skrip besar pada project yang sudah berisi data: gunakan backup Dashboard.
  6. Gate V2: `006` (semua asersi PASS) + `007` (audit lolos) = Execution Task 2 selesai → laporkan, jangan mulai Execution 3 tanpa persetujuan.

  ## Keamanan yang melekat pada skrip

  - RLS aktif di 9/9 tabel sejak pembuatan (default-deny).
  - Aktivitas & notifikasi hanya dari trigger (SECURITY DEFINER, `search_path = ''`); client tanpa policy INSERT.
  - Catatan pribadi (`library_entries.notes`) tidak dapat di-SELECT dari tabel; hanya via fungsi `library_entry_notes(uuid)` dengan cek kepemilikan.
  - Review: soft delete `deleted_at`; view rating hanya menghitung review aktif.
  - Statistik profil: hanya angka agregat publik (`profile_stats`), tanpa detail library privat.
  - Negative test memakai SQL Editor + dua akun uji (keputusan pengguna 2026-11-08) — tanpa service_role key.
  ````
  <!-- END: db/README.md -->

  ---

  ## File 2 — db/SCHEMA_STATE.md

  <!-- BEGIN: db/SCHEMA_STATE.md -->
  ````
  # SCHEMA STATE — status penerapan skrip (pengganti migration tracking)

  Workflow: jalankan skrip urut 001→007 via Supabase Dashboard SQL Editor, lalu tandai di sini.
  Kolom `applied` = skrip sukses dijalankan; `verified` = blok `-- VERIFY`/tes lolos.

  | Skrip | applied (tanggal) | verified (tanggal) | Catatan |
  |---|---|---|---|
  | 001_enums.sql | — | — | pending |
  | 002_identity_books.sql | — | — | pending |
  | 003_library.sql | — | — | pending |
  | 004_reviews_social.sql | — | — | pending |
  | 005_activity_notifications.sql | — | — | pending |
  | 006_negative_tests.sql | — | — | pending; isi `<USER_A>`/`<USER_B>` dengan UUID 2 akun uji |
  | 007_verify_schema.sql | — | — | pending; gate V2 |

  ## Log perubahan manual (jangan ada — hanya untuk catatan insidental)

  | Tanggal | Oleh | Perubahan di luar skrip | Tindak lanjut |
  |---|---|---|---|
  | — | — | — | — |

  ## Gate V2 (Execution Task 2 selesai)

  - [ ] 001–007 applied & verified (di atas).
  - [ ] 006: `ALL RLS TESTS PASSED`.
  - [ ] 007: 9/9 tabel RLS aktif; audit grant/fungsi lolos.
  - [ ] Dilaporkan ke pengguna; Execution 3 belum dimulai.
  ````
  <!-- END: db/SCHEMA_STATE.md -->

  ---

  ## File 3 — db/scripts/001_enums.sql

  <!-- BEGIN: db/scripts/001_enums.sql -->
  ```sql
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
  ```
  <!-- END: db/scripts/001_enums.sql -->

  ---

  ## File 4 — db/scripts/002_identity_books.sql

  <!-- BEGIN: db/scripts/002_identity_books.sql -->
  ```sql
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
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'books'
                  and policyname = 'books_update_authenticated') then
      execute $p$ create policy "books_update_authenticated" on public.books
        for update using (auth.uid() is not null)
        with check (auth.uid() is not null) $p$;
    end if;
    -- books: TANPA policy delete
  end $$;

  -- VERIFY
  select 'profiles' as tbl, relrowsecurity from pg_class where oid = 'public.profiles'::regclass
  union all
  select 'books', relrowsecurity from pg_class where oid = 'public.books'::regclass;
  -- harapkan: true, true

  select tablename, policyname, cmd from pg_policies
  where schemaname = 'public' and tablename in ('profiles', 'books')
  order by tablename, policyname;
  -- harapkan 5 policy (2 profiles + 3 books), tanpa insert/delete di profiles
  ```
  <!-- END: db/scripts/002_identity_books.sql -->

  ---

  ## File 5 — db/scripts/003_library.sql

  <!-- BEGIN: db/scripts/003_library.sql -->
  ```sql
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
  ```
  <!-- END: db/scripts/003_library.sql -->

  ---

  ## File 6 — db/scripts/004_reviews_social.sql

  <!-- BEGIN: db/scripts/004_reviews_social.sql -->
  ```sql
  -- ============================================================================
  -- 004_reviews_social.sql — reviews (soft delete), likes, comments, follows,
  -- view book_rating_summary (hanya review aktif), view profile_stats (agregat
  -- publik tanpa detail library privat), + RLS.
  -- Jalankan setelah 003.
  -- ============================================================================

  -- ---------------------------------------------------------------- reviews --
  create table if not exists public.reviews (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references public.profiles (id) on delete cascade,
    book_id    uuid not null references public.books (id) on delete cascade,
    rating     numeric(2,1) not null,
    title      text,
    content    text,
    spoiler    boolean not null default false,
    deleted_at timestamptz,                            -- soft delete (keputusan 3)
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint reviews_rating_range check (rating >= 0.5 and rating <= 5.0),
    constraint reviews_rating_interval check (round(rating * 2) = rating * 2),
    constraint reviews_title_len check (title is null or char_length(title) <= 300),
    constraint reviews_content_len check (content is null or char_length(content) <= 10000)
  );

  -- 1 review AKTIF per user per book (soft delete menghapus dari hitungan unique)
  create unique index if not exists reviews_one_active_per_book
    on public.reviews (user_id, book_id) where deleted_at is null;
  create index if not exists reviews_book_active_idx
    on public.reviews (book_id) where deleted_at is null;
  create index if not exists reviews_user_id_idx on public.reviews (user_id);

  do $$
  begin
    if not exists (select 1 from pg_trigger where tgname = 'reviews_set_updated_at'
                  and tgrelid = 'public.reviews'::regclass) then
      create trigger reviews_set_updated_at
        before update on public.reviews
        for each row execute function public.set_updated_at();
    end if;
  end $$;

  -- ------------------------------------------------------------------ likes --
  create table if not exists public.likes (
    review_id uuid not null references public.reviews (id) on delete cascade,
    user_id   uuid not null references public.profiles (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (review_id, user_id)
  );
  create index if not exists likes_user_id_idx on public.likes (user_id);

  -- --------------------------------------------------------------- comments --
  create table if not exists public.comments (
    id         uuid primary key default gen_random_uuid(),
    review_id  uuid not null references public.reviews (id) on delete cascade,
    user_id    uuid not null references public.profiles (id) on delete cascade,
    content    text not null,
    created_at timestamptz not null default now(),
    constraint comments_content_len check (char_length(content) between 1 and 5000)
  );
  create index if not exists comments_review_id_idx on public.comments (review_id);
  create index if not exists comments_user_id_idx on public.comments (user_id);

  -- ---------------------------------------------------------------- follows --
  create table if not exists public.follows (
    follower_id  uuid not null references public.profiles (id) on delete cascade,
    following_id uuid not null references public.profiles (id) on delete cascade,
    created_at   timestamptz not null default now(),
    primary key (follower_id, following_id),
    constraint follows_no_self check (follower_id <> following_id)
  );
  create index if not exists follows_following_idx on public.follows (following_id);

  -- -------------------------------------------------------------------- RLS --
  alter table public.reviews  enable row level security;
  alter table public.likes    enable row level security;
  alter table public.comments enable row level security;
  alter table public.follows  enable row level security;

  do $$
  begin
    -- reviews: hanya yang aktif terlihat; tulis hanya own; TANPA delete (soft-delete via update)
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'reviews'
                  and policyname = 'reviews_select_active') then
      execute $p$ create policy "reviews_select_active" on public.reviews
        for select using (deleted_at is null) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'reviews'
                  and policyname = 'reviews_insert_own') then
      execute $p$ create policy "reviews_insert_own" on public.reviews
        for insert with check (user_id = (select auth.uid())) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'reviews'
                  and policyname = 'reviews_update_own') then
      execute $p$ create policy "reviews_update_own" on public.reviews
        for update using (user_id = (select auth.uid()) and deleted_at is null)
        with check (user_id = (select auth.uid())) $p$;
    end if;

    -- likes: hanya pada review aktif; tulis/delete own
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'likes'
                  and policyname = 'likes_select_active_review') then
      execute $p$ create policy "likes_select_active_review" on public.likes
        for select using (exists (
          select 1 from public.reviews r where r.id = likes.review_id and r.deleted_at is null
        )) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'likes'
                  and policyname = 'likes_insert_own_active_review') then
      execute $p$ create policy "likes_insert_own_active_review" on public.likes
        for insert with check (
          user_id = (select auth.uid())
          and exists (select 1 from public.reviews r where r.id = likes.review_id and r.deleted_at is null)
        ) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'likes'
                  and policyname = 'likes_delete_own') then
      execute $p$ create policy "likes_delete_own" on public.likes
        for delete using (user_id = (select auth.uid())) $p$;
    end if;

    -- comments: hanya pada review aktif; tulis/delete own; tanpa update (PRD: hapus saja)
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'comments'
                  and policyname = 'comments_select_active_review') then
      execute $p$ create policy "comments_select_active_review" on public.comments
        for select using (exists (
          select 1 from public.reviews r where r.id = comments.review_id and r.deleted_at is null
        )) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'comments'
                  and policyname = 'comments_insert_own_active_review') then
      execute $p$ create policy "comments_insert_own_active_review" on public.comments
        for insert with check (
          user_id = (select auth.uid())
          and exists (select 1 from public.reviews r where r.id = comments.review_id and r.deleted_at is null)
        ) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'comments'
                  and policyname = 'comments_delete_own') then
      execute $p$ create policy "comments_delete_own" on public.comments
        for delete using (user_id = (select auth.uid())) $p$;
    end if;

    -- follows: publik dibaca; insert/unfollow hanya milik sendiri + no-self (constraint)
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'follows'
                  and policyname = 'follows_select_public') then
      execute $p$ create policy "follows_select_public" on public.follows
        for select using (true) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'follows'
                  and policyname = 'follows_insert_own') then
      execute $p$ create policy "follows_insert_own" on public.follows
        for insert with check (
          follower_id = (select auth.uid())
          and follower_id <> following_id
        ) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'follows'
                  and policyname = 'follows_delete_own') then
      execute $p$ create policy "follows_delete_own" on public.follows
        for delete using (follower_id = (select auth.uid())) $p$;
    end if;
  end $$;

  -- --------------------------------------------------------------- views ----
  -- Keputusan 5: agregat rating HANYA review aktif; security_invoker agar
  -- mengikuti RLS caller (baris review aktif memang publik).
  create or replace view public.book_rating_summary
  with (security_invoker = on) as
  select
    b.id as book_id,
    count(r.id)::bigint as rating_count,
    coalesce(avg(r.rating), 0)::numeric(3, 2) as avg_rating
  from public.books b
  left join public.reviews r on r.book_id = b.id and r.deleted_at is null
  group by b.id;

  grant select on public.book_rating_summary to anon, authenticated;

  -- Keputusan 7: statistik profil publik HANYA angka — view berjalan sebagai owner
  -- (security_invoker off, default) sehingga menghitung agregat lintas visibility;
  -- tidak pernah mengembalikan baris/baris detail library privat.
  create or replace view public.profile_stats as
  select
    p.id as profile_id,
    (select count(*) from public.library_entries l
      where l.user_id = p.id and l.status = 'FINISHED')::bigint as books_read,
    (select count(*) from public.library_entries l
      where l.user_id = p.id and l.status = 'READING')::bigint as currently_reading,
    (select count(*) from public.reviews r
      where r.user_id = p.id and r.deleted_at is null)::bigint as reviews_count,
    (select count(*) from public.follows f where f.following_id = p.id)::bigint as followers_count,
    (select count(*) from public.follows f where f.follower_id = p.id)::bigint as following_count
  from public.profiles p;

  grant select on public.profile_stats to anon, authenticated;

  -- VERIFY
  select relrowsecurity from pg_class
  where oid in ('public.reviews'::regclass, 'public.likes'::regclass,
                'public.comments'::regclass, 'public.follows'::regclass); -- 4x true
  select tablename, policyname, cmd from pg_policies
  where schemaname = 'public' and tablename in ('reviews','likes','comments','follows')
  order by tablename, policyname;
  -- harapkan: reviews TANPA policy delete; comments TANPA policy update
  select viewname from pg_views where schemaname = 'public'
    and viewname in ('book_rating_summary', 'profile_stats'); -- 2 view
  select indexname from pg_indexes where schemaname = 'public' and tablename = 'reviews'
    order by indexname;
  -- harapkan: reviews_book_active_idx, reviews_one_active_per_book, reviews_user_id_idx, ...reviews_pkey
  ```
  <!-- END: db/scripts/004_reviews_social.sql -->

  ---

  ## File 7 — db/scripts/005_activity_notifications.sql

  <!-- BEGIN: db/scripts/005_activity_notifications.sql -->
  ```sql
  -- ============================================================================
  -- 005_activity_notifications.sql — activities + notifications + trigger.
  -- Keputusan 4: client TANPA policy INSERT di dua tabel ini; semua baris lahir
  -- hanya dari trigger SECURITY DEFINER (anti-forgery / anti-spoofing).
  -- Jalankan setelah 004.
  -- ============================================================================

  create table if not exists public.activities (
    id              uuid primary key default gen_random_uuid(),
    actor_id        uuid not null references public.profiles (id) on delete cascade,
    target_user_id  uuid references public.profiles (id) on delete cascade, -- penerima (bila ada)
    book_id         uuid references public.books (id) on delete cascade,
    review_id       uuid references public.reviews (id) on delete cascade,
    activity_type   public.activity_type not null,
    created_at      timestamptz not null default now()
  );
  create index if not exists activities_created_at_idx on public.activities (created_at desc);
  create index if not exists activities_target_user_idx on public.activities (target_user_id);
  create index if not exists activities_actor_idx on public.activities (actor_id);

  create table if not exists public.notifications (
    id                uuid primary key default gen_random_uuid(),
    user_id           uuid not null references public.profiles (id) on delete cascade,
    notification_type public.notification_type not null,
    actor_id          uuid references public.profiles (id) on delete cascade,
    review_id         uuid references public.reviews (id) on delete cascade,
    comment_id        uuid references public.comments (id) on delete cascade,
    read              boolean not null default false,
    created_at        timestamptz not null default now()
  );
  create index if not exists notifications_user_created_idx
    on public.notifications (user_id, created_at desc);

  -- -------------------------------------------------------------------- RLS --
  alter table public.activities    enable row level security;
  alter table public.notifications enable row level security;

  -- Publik boleh membaca activity feed; user membaca notifikasinya sendiri.
  -- SENGAJA TANPA policy insert/update/delete untuk authenticated/anon:
  -- hanya trigger yang menulis (lihat trigger di bawah).
  do $$
  begin
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'activities'
                  and policyname = 'activities_select_public') then
      execute $p$ create policy "activities_select_public" on public.activities
        for select using (true) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'notifications'
                  and policyname = 'notifications_select_own') then
      execute $p$ create policy "notifications_select_own" on public.notifications
        for select using (user_id = (select auth.uid())) $p$;
    end if;
    if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'notifications'
                  and policyname = 'notifications_update_own') then
      execute $p$ create policy "notifications_update_own" on public.notifications
        for update using (user_id = (select auth.uid()))
        with check (user_id = (select auth.uid())) $p$;
    end if;
  end $$;

  -- ------------------------------------------------- trigger: aktivitas ------
  -- Pemetaan: rating-only → RATING_CREATED; berkonten (title/content) →
  -- REVIEW_CREATED (heuristik implementasi, tercatat di plan §4).
  -- Progress/status library → READING_PROGRESS_UPDATED / BOOK_STARTED / BOOK_FINISHED.
  create or replace function public.trg_review_activity() returns trigger
  language plpgsql security definer set search_path = '' as $$
  begin
    if tg_op = 'UPDATE' then
      if new.deleted_at is not null and old.deleted_at is null then
        return new; -- soft delete: tanpa aktivitas baru
      end if;
      if new.rating is not distinct from old.rating
        and new.title is not distinct from old.title
        and new.content is not distinct from old.content then
        return new; -- perubahan tanpa rating/konten: tanpa aktivitas
      end if;
    end if;
    if new.rating is not null and (coalesce(new.title, '') = '' and coalesce(new.content, '') = '') then
      insert into public.activities (actor_id, book_id, review_id, activity_type)
      values (new.user_id, new.book_id, new.id, 'RATING_CREATED');
    else
      insert into public.activities (actor_id, book_id, review_id, activity_type)
      values (new.user_id, new.book_id, new.id, 'REVIEW_CREATED');
    end if;
    return new;
  end $$;

  do $$
  begin
    if not exists (select 1 from pg_trigger where tgname = 'trg_reviews_activity'
                  and tgrelid = 'public.reviews'::regclass) then
      create trigger trg_reviews_activity
        after insert or update on public.reviews
        for each row execute function public.trg_review_activity();
    end if;
  end $$;

  create or replace function public.trg_library_activity() returns trigger
  language plpgsql security definer set search_path = '' as $$
  declare
    v_type public.activity_type;
  begin
    if tg_op = 'INSERT' then
      if new.status = 'READING' then v_type := 'BOOK_STARTED';
      elsif new.status = 'FINISHED' then v_type := 'BOOK_FINISHED';
      else v_type := 'BOOK_ADDED';
      end if;
    else
      if new.status <> old.status then
        if new.status = 'READING' then v_type := 'BOOK_STARTED';
        elsif new.status = 'FINISHED' then v_type := 'BOOK_FINISHED';
        else return new; -- mundur ke WANT_TO_READ: tanpa aktivitas
        end if;
      elsif new.progress is distinct from old.progress then
        v_type := 'READING_PROGRESS_UPDATED';
      else
        return new;
      end if;
    end if;
    insert into public.activities (actor_id, book_id, activity_type)
    values (new.user_id, new.book_id, v_type);
    return new;
  end $$;

  do $$
  begin
    if not exists (select 1 from pg_trigger where tgname = 'trg_library_activity'
                  and tgrelid = 'public.library_entries'::regclass) then
      create trigger trg_library_activity
        after insert or update on public.library_entries
        for each row execute function public.trg_library_activity();
    end if;
  end $$;

  -- ------------------------------------------------- trigger: notifikasi -----
  -- Like → REVIEW_LIKED (ke pemilik review, bukan pelaku);
  -- comment → REVIEW_COMMENTED; follow → NEW_FOLLOWER.
  create or replace function public.trg_like_notification() returns trigger
  language plpgsql security definer set search_path = '' as $$
  declare
    v_owner uuid;
  begin
    select r.user_id into v_owner from public.reviews r
    where r.id = new.review_id and r.deleted_at is null;
    if v_owner is null or v_owner = new.user_id then
      return new; -- review tak aktif / menyukai sendiri: tanpa notifikasi
    end if;
    insert into public.notifications (user_id, notification_type, actor_id, review_id)
    values (v_owner, 'REVIEW_LIKED', new.user_id, new.review_id);
    return new;
  end $$;

  do $$
  begin
    if not exists (select 1 from pg_trigger where tgname = 'trg_likes_notification'
                  and tgrelid = 'public.likes'::regclass) then
      create trigger trg_likes_notification
        after insert on public.likes
        for each row execute function public.trg_like_notification();
    end if;
  end $$;

  create or replace function public.trg_comment_notification() returns trigger
  language plpgsql security definer set search_path = '' as $$
  declare
    v_owner uuid;
  begin
    select r.user_id into v_owner from public.reviews r
    where r.id = new.review_id and r.deleted_at is null;
    if v_owner is null or v_owner = new.user_id then
      return new;
    end if;
    insert into public.notifications (user_id, notification_type, actor_id, review_id, comment_id)
    values (v_owner, 'REVIEW_COMMENTED', new.user_id, new.review_id, new.id);
    return new;
  end $$;

  do $$
  begin
    if not exists (select 1 from pg_trigger where tgname = 'trg_comments_notification'
                  and tgrelid = 'public.comments'::regclass) then
      create trigger trg_comments_notification
        after insert on public.comments
        for each row execute function public.trg_comment_notification();
    end if;
  end $$;

  create or replace function public.trg_follow_notification() returns trigger
  language plpgsql security definer set search_path = '' as $$
  begin
    insert into public.notifications (user_id, notification_type, actor_id)
    values (new.following_id, 'NEW_FOLLOWER', new.follower_id);
    return new;
  end $$;

  do $$
  begin
    if not exists (select 1 from pg_trigger where tgname = 'trg_follows_notification'
                  and tgrelid = 'public.follows'::regclass) then
      create trigger trg_follows_notification
        after insert on public.follows
        for each row execute function public.trg_follow_notification();
    end if;
  end $$;

  -- VERIFY
  select relrowsecurity from pg_class
  where oid in ('public.activities'::regclass, 'public.notifications'::regclass); -- 2x true
  select tablename, policyname, cmd from pg_policies
  where schemaname = 'public' and tablename in ('activities', 'notifications')
  order by tablename, policyname;
  -- harapkan: activities HANYA select; notifications HANYA select+update (TANPA insert/delete)
  select tgname, tgtype from pg_trigger
  where tgrelid in ('public.reviews'::regclass, 'public.library_entries'::regclass,
                    'public.likes'::regclass, 'public.comments'::regclass,
                    'public.follows'::regclass)
    and not tgisinternal
  order by tgname;
  -- harapkan 7 baris: 2 trigger updated_at (skrip 002/003) + 5 trigger fungsional
  -- (trg_reviews_activity, trg_library_activity, trg_likes_notification,
  --  trg_comments_notification, trg_follows_notification)
  ```
  <!-- END: db/scripts/005_activity_notifications.sql -->

  ---

  ## File 8 — db/scripts/006_negative_tests.sql

  <!-- BEGIN: db/scripts/006_negative_tests.sql -->
  ```sql
  -- ============================================================================
  -- 006_negative_tests.sql — seluruh negative authorization test.
  -- Prasyarat: 2 akun uji sudah terdaftar di Supabase Dashboard (Authentication →
  -- Users); dua profil pertama menurut join_date dipakai sebagai A dan B.
  -- Jalankan setelah 005. Satu transaksi, diakhiri ROLLBACK → NOL RESIDU
  -- (tabel uji, fungsi uji, fixture, dan seluruh perubahan data ikut terhapus).
  -- Marker keberhasilan: 'ALL NEGATIVE TESTS PASSED'
  -- ============================================================================

  begin;

  drop table if exists public._t006_results;
  drop table if exists public._t006_ids;
  drop function if exists public._t006_record(text, boolean, text);
  drop function if exists public._t006_expect_true(text, text);
  drop function if exists public._t006_expect_fail(text, text);
  drop function if exists public._t006_expect_pass(text, text);
  drop function if exists public._t006_expect_0rows(text, text);

  create table public._t006_results (
    name   text primary key,
    ok     boolean not null,
    detail text
  );
  create table public._t006_ids (k text primary key, v uuid not null);

  grant select, insert on public._t006_results to authenticated;
  grant select on public._t006_ids to authenticated;

  create or replace function public._t006_record(p_name text, p_ok boolean, p_detail text)
  returns void language sql as $$
    insert into public._t006_results (name, ok, detail) values (p_name, p_ok, p_detail);
  $$;

  -- expect_true: SQL dinamis harus menghasilkan true (tanpa error)
  create or replace function public._t006_expect_true(p_name text, p_sql text)
  returns void language plpgsql as $$
  declare v boolean;
  begin
    execute p_sql into v;
    perform public._t006_record(p_name, coalesce(v, false),
      case when coalesce(v, false) then 'ok'
          else 'hasil: ' || coalesce(v::text, 'null') end);
  exception when others then
    perform public._t006_record(p_name, false, sqlstate || ': ' || left(sqlerrm, 160));
  end $$;

  -- expect_fail: harus GAGAL dengan kode keamanan/konstraint yang benar
  -- (42501 privilege/RLS, 23505 unique, 23514 check); error lain = FAIL
  -- (mencegah lolos gara-gara typo/objek hilang).
  create or replace function public._t006_expect_fail(p_name text, p_sql text)
  returns void language plpgsql as $$
  begin
    execute p_sql;
    perform public._t006_record(p_name, false, 'SEHARUSNYA gagal, tapi berhasil');
  exception when others then
    perform public._t006_record(p_name, sqlstate in ('42501', '23505', '23514'),
      sqlstate || ': ' || left(sqlerrm, 140));
  end $$;

  -- expect_pass: DML/Statement harus SUKSES tanpa error (kontrol positif)
  create or replace function public._t006_expect_pass(p_name text, p_sql text)
  returns void language plpgsql as $$
  begin
    execute p_sql;
    perform public._t006_record(p_name, true, 'ok');
  exception when others then
    perform public._t006_record(p_name, false, sqlstate || ': ' || left(sqlerrm, 160));
  end $$;

  -- expect_0rows: DML yang mempengaruhi 0 baris (mode penolakan RLS khas UPDATE/DELETE)
  create or replace function public._t006_expect_0rows(p_name text, p_sql text)
  returns void language plpgsql as $$
  declare n int;
  begin
    execute p_sql;
    get diagnostics n = row_count;
    perform public._t006_record(p_name, n = 0, 'row_count=' || n);
  exception when others then
    perform public._t006_record(p_name, sqlstate in ('42501', '23505', '23514'),
      'error ' || sqlstate || ': ' || left(sqlerrm, 140));
  end $$;

  -- ============================================================ FIXTURE (A/B) --
  do $$
  declare
    v_a uuid; v_b uuid; v_book1 uuid; v_book2 uuid;
    v_entry_priv uuid; v_entry_pub uuid; v_review uuid;
    n int;
  begin
    select count(*) into n from public.profiles;
    if n < 2 then
      raise exception 'PRASYARAT GAGAL: butuh >= 2 profil. Buat 2 akun uji di Dashboard (Authentication -> Users) lalu jalankan ulang 006.';
    end if;
    select id into v_a from public.profiles order by join_date, id limit 1;
    select id into v_b from public.profiles order by join_date, id offset 1 limit 1;

    insert into public.books (google_books_id, title, authors, description)
    values ('t006-book-1', 'Buku Uji 006-1', array['Penulis Uji'], 'Fixture 006')
    returning id into v_book1;
    insert into public.books (google_books_id, title, authors, description)
    values ('t006-book-2', 'Buku Uji 006-2', array['Penulis Uji'], 'Fixture 006')
    returning id into v_book2;

    insert into public.library_entries (user_id, book_id, status, progress, visibility, notes)
    values (v_a, v_book1, 'READING', 10, 'PRIVATE', 'RAHASIA-A')
    returning id into v_entry_priv;
    insert into public.library_entries (user_id, book_id, status, progress, visibility, notes)
    values (v_a, v_book2, 'FINISHED', 100, 'PUBLIC', 'RAHASIA-PUB')
    returning id into v_entry_pub;

    insert into public.reviews (user_id, book_id, rating, title, content)
    values (v_a, v_book1, 4.0, 'Judul Uji', 'Isi ulasan uji untuk skrip 006.')
    returning id into v_review;

    insert into public._t006_ids (k, v) values
      ('a', v_a), ('b', v_b), ('book1', v_book1), ('book2', v_book2),
      ('entry_priv', v_entry_priv), ('entry_pub', v_entry_pub), ('review', v_review);
  end $$;

  -- ====================================================== SESI A (pemilik data) --
  set local role authenticated;
  select set_config('request.jwt.claims',
    '{"sub": "' || (select v from public._t006_ids where k = 'a') || '", "role": "authenticated"}',
    true);

  select public._t006_expect_true('A01 notes terbaca via fungsi milik sendiri', $sql$
    select public.library_entry_notes((select v from public._t006_ids where k = 'entry_priv')) = 'RAHASIA-A'
  $sql$);

  select public._t006_expect_fail('A02 notes TIDAK terbaca via SELECT tabel (hak kolom)', $sql$
    select notes from public.library_entries
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_true('A03 entry privat sendiri terlihat', $sql$
    select count(*) = 1 from public.library_entries
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_pass('A04 pemilik boleh UPDATE notes sendiri', $sql$
    update public.library_entries set notes = 'RAHASIA-BARU'
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_true('A05 notes hasil UPDATE terbaca via fungsi', $sql$
    select public.library_entry_notes((select v from public._t006_ids where k = 'entry_priv')) = 'RAHASIA-BARU'
  $sql$);

  select public._t006_expect_fail('A06 INSERT activities langsung DITOLAK (tanpa policy)', $sql$
    insert into public.activities (actor_id, activity_type)
    values ((select v from public._t006_ids where k = 'a'), 'BOOK_ADDED')
  $sql$);

  select public._t006_expect_fail('A07 INSERT notifications langsung DITOLAK (tanpa policy)', $sql$
    insert into public.notifications (user_id, notification_type)
    values ((select v from public._t006_ids where k = 'a'), 'NEW_FOLLOWER')
  $sql$);

  select public._t006_expect_0rows('A08 UPDATE profil orang lain TIDAK berpengaruh', $sql$
    update public.profiles set bio = 'HACKED-BY-A'
    where id = (select v from public._t006_ids where k = 'b')
  $sql$);

  select public._t006_expect_fail('A09 rating di luar interval CHECK ditolak (4.3)', $sql$
    insert into public.reviews (user_id, book_id, rating)
    values ((select v from public._t006_ids where k = 'a'),
            (select v from public._t006_ids where k = 'book2'), 4.3)
  $sql$);

  select public._t006_expect_pass('A10 kontrol positif: insert review valid di buku lain', $sql$
    insert into public.reviews (user_id, book_id, rating)
    values ((select v from public._t006_ids where k = 'a'),
            (select v from public._t006_ids where k = 'book2'), 3.0)
  $sql$);

  select public._t006_expect_fail('A11 review ganda pada buku sama DITOLAK (unique aktif)', $sql$
    insert into public.reviews (user_id, book_id, rating)
    values ((select v from public._t006_ids where k = 'a'),
            (select v from public._t006_ids where k = 'book1'), 5.0)
  $sql$);

  select public._t006_expect_fail('A12 follow diri sendiri DITOLAK (constraint no-self)', $sql$
    insert into public.follows (follower_id, following_id)
    values ((select v from public._t006_ids where k = 'a'),
            (select v from public._t006_ids where k = 'a'))
  $sql$);

  -- ====================================================== SESI B (pihak lain) --
  reset role;
  reset request.jwt.claims;
  set local role authenticated;
  select set_config('request.jwt.claims',
    '{"sub": "' || (select v from public._t006_ids where k = 'b') || '", "role": "authenticated"}',
    true);

  select public._t006_expect_fail('B01 notes milik A TIDAK terbaca via SELECT tabel', $sql$
    select notes from public.library_entries
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_true('B02 entry PRIVATE milik A TIDAK terlihat', $sql$
    select count(*) = 0 from public.library_entries
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_true('B03 entry PUBLIC milik A terlihat', $sql$
    select count(*) = 1 from public.library_entries
    where id = (select v from public._t006_ids where k = 'entry_pub')
  $sql$);

  select public._t006_expect_0rows('B04 UPDATE entry PRIVATE milik A TIDAK berpengaruh', $sql$
    update public.library_entries set progress = 99
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_0rows('B05 UPDATE review milik A TIDAK berpengaruh', $sql$
    update public.reviews set rating = 1.0
    where id = (select v from public._t006_ids where k = 'review')
  $sql$);

  select public._t006_expect_0rows('B06 DELETE review milik A TIDAK berpengaruh (tanpa policy)', $sql$
    delete from public.reviews
    where id = (select v from public._t006_ids where k = 'review')
  $sql$);

  select public._t006_expect_pass('B07 kontrol positif: like review aktif A oleh B', $sql$
    insert into public.likes (review_id, user_id)
    values ((select v from public._t006_ids where k = 'review'),
            (select v from public._t006_ids where k = 'b'))
  $sql$);

  select public._t006_expect_pass('B08 kontrol positif: comment review aktif A oleh B', $sql$
    insert into public.comments (review_id, user_id, content)
    values ((select v from public._t006_ids where k = 'review'),
            (select v from public._t006_ids where k = 'b'), 'Komentar uji 006')
  $sql$);

  select public._t006_expect_pass('B09 kontrol positif: follow A oleh B', $sql$
    insert into public.follows (follower_id, following_id)
    values ((select v from public._t006_ids where k = 'b'),
            (select v from public._t006_ids where k = 'a'))
  $sql$);

  select public._t006_expect_fail('B10 INSERT notifications langsung DITOLAK (tanpa policy)', $sql$
    insert into public.notifications (user_id, notification_type)
    values ((select v from public._t006_ids where k = 'b'), 'NEW_FOLLOWER')
  $sql$);

  select public._t006_expect_true('B11 notifikasi milik A TIDAK terlihat oleh B', $sql$
    select count(*) = 0 from public.notifications
    where user_id = (select v from public._t006_ids where k = 'a')
  $sql$);

  select public._t006_expect_true('B12 activity feed publik terlihat oleh B', $sql$
    select count(*) >= 1 from public.activities
  $sql$);

  select public._t006_expect_true('B13 view rating menunjukkan review aktif (count=1, avg=4.0)', $sql$
    select rating_count = 1 and avg_rating = 4.0 from public.book_rating_summary
    where book_id = (select v from public._t006_ids where k = 'book1')
  $sql$);

  -- =============================================== SESI A KEMBALI (notifikasi) --
  reset role;
  reset request.jwt.claims;
  set local role authenticated;
  select set_config('request.jwt.claims',
    '{"sub": "' || (select v from public._t006_ids where k = 'a') || '", "role": "authenticated"}',
    true);

  select public._t006_expect_true('A13 like/comment/follow B melahirkan 3 notifikasi untuk A (trigger)', $sql$
    select count(*) = 3 from public.notifications
    where user_id = (select v from public._t006_ids where k = 'a')
      and notification_type in ('REVIEW_LIKED', 'REVIEW_COMMENTED', 'NEW_FOLLOWER')
  $sql$);

  select public._t006_expect_pass('A14 pemilik boleh UPDATE notifikasi sendiri (tandai read)', $sql$
    update public.notifications set read = true
    where user_id = (select v from public._t006_ids where k = 'a')
      and notification_type = 'REVIEW_LIKED'
  $sql$);

  select public._t006_expect_true('A15 notifikasi REVIEW_LIKED berstatus read', $sql$
    select count(*) = 1 from public.notifications
    where user_id = (select v from public._t006_ids where k = 'a')
      and notification_type = 'REVIEW_LIKED' and read = true
  $sql$);

  select public._t006_expect_pass('A16 soft-delete review sendiri diizinkan', $sql$
    update public.reviews set deleted_at = now()
    where id = (select v from public._t006_ids where k = 'review')
  $sql$);

  select public._t006_expect_true('A17 review terhapus TIDAK terlihat di tabel (soft delete)', $sql$
    select count(*) = 0 from public.reviews
    where id = (select v from public._t006_ids where k = 'review')
  $sql$);

  select public._t006_expect_true('A18 view rating TIDAK menghitung review terhapus (count=0)', $sql$
    select rating_count = 0 from public.book_rating_summary
    where book_id = (select v from public._t006_ids where k = 'book1')
  $sql$);

  select public._t006_expect_true('A19 like pada review terhapus tidak terlihat', $sql$
    select count(*) = 0 from public.likes
    where review_id = (select v from public._t006_ids where k = 'review')
  $sql$);

  select public._t006_expect_pass('A20 visibility entry bisa diubah pemilik (PRIVATE -> PUBLIC)', $sql$
    update public.library_entries set visibility = 'PUBLIC'
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_true('A21 profile_stats mengembalikan tepat 1 baris agregat', $sql$
    select count(*) = 1 from public.profile_stats
    where profile_id = (select v from public._t006_ids where k = 'a')
  $sql$);

  -- ===================================================== POSTGRES (tanpa RLS) --
  reset role;
  reset request.jwt.claims;

  select public._t006_expect_true('P01 bio B tidak berubah (update A terefek 0 baris)', $sql$
    select bio is distinct from 'HACKED-BY-A' from public.profiles
    where id = (select v from public._t006_ids where k = 'b')
  $sql$);

  select public._t006_expect_true('P02 progress entry privat A masih 10 (update B terefek 0 baris)', $sql$
    select progress = 10 from public.library_entries
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_true('P03 notes A bertahan sebagai RAHASIA-BARU (tulis via tabel ok)', $sql$
    select notes = 'RAHASIA-BARU' from public.library_entries
    where id = (select v from public._t006_ids where k = 'entry_priv')
  $sql$);

  select public._t006_expect_true('P04 review A ber-rating 4.0 (update B terefek 0 baris)', $sql$
    select rating = 4.0 from public.reviews
    where id = (select v from public._t006_ids where k = 'review')
  $sql$);

  select public._t006_expect_true('P05 review A ber-status aktif kembali? TIDAK — masih terhapus', $sql$
    select deleted_at is not null from public.reviews
    where id = (select v from public._t006_ids where k = 'review')
  $sql$);

  -- ================================================================ RINGKASAN --
  select name, ok, detail from public._t006_results where not ok order by name;

  select
    case
      when count(*) = count(*) filter (where ok)
        then 'ALL NEGATIVE TESTS PASSED: ' || count(*) || ' pemeriksaan'
      else 'TESTS FAILED: ' || count(*) filter (where not ok) || ' gagal dari '
          || count(*) || ' pemeriksaan'
    end as hasil
  from public._t006_results;

  rollback;
  ```
  <!-- END: db/scripts/006_negative_tests.sql -->

  ---

  ## File 9 — db/scripts/007_verify_schema.sql

  <!-- BEGIN: db/scripts/007_verify_schema.sql -->
  ```sql
  -- ============================================================================
  -- 007_verify_schema.sql — audit akhir Execution Task 2 (GATE V2).
  -- Jalankan setelah 006, sebagai postgres (SQL Editor default).
  -- Tidak mengubah data. Semua baris `pass` harus true; ringkasan akhir harus
  -- berbunyi 'VERIFY SCHEMA: ALL ... CHECKS PASSED'.
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
  ```
  <!-- END: db/scripts/007_verify_schema.sql -->
