# Execution Task 2 — Security Audit Revision Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Global override: NO commits, NO SQL execution, NO database/Supabase changes, NO dependency installs** — verification is static only.

**Goal:** Perbaiki 5 temuan audit keamanan pada 9 artefak database BookRate sebelum SQL pertama dijalankan di Supabase.

**Architecture:** Skrip SQL Dashboard-first tetap; perubahan murni di level skema/grant/policy/trigger + negative test + audit catalog. Tidak ada perubahan arsitektur (tetap tanpa CLI/Docker/Edge Functions), tidak ada perubahan produk di luar yang tercatat di §1A.

**Tech Stack:** PostgreSQL 15+ (Supabase hosted), RLS + column grants, plpgsql trigger SECURITY DEFINER, skrip idempoten dijalankan manual via SQL Editor.

**Spec:** Temuan audit keamanan (permintaan pengguna 2026-11-08) + `docs/superpowers/plans/execution-task-2-database-plan.md` (acuan keputusan yang sudah disetujui).

## Global Constraints

- Jangan jalankan SQL apa pun; jangan menyentuh database/konfigurasi Supabase; jangan install dependency/CLI; jangan commit.
- Jangan ubah `docs/PRD.md` (hash `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e`), `docs/ROADMAP.md` (CRLF), `db/AUDIT_REVIEW_BUNDLE.md` (snapshot historis — biarkan basi; regenerasi hanya bila diminta), ADR `docs/architecture/0001-supabase-first-backend.md` (tidak terdampak — lihat Task 7).
- Pertahankan keputusan produk 1–8 yang sudah disetujui; setiap penajaman keputusan wajib tercatat di plan doc (Task 7).
- Marker keberhasilan tetap: 006 → `ALL NEGATIVE TESTS PASSED`; 007 → `VERIFY SCHEMA: ALL ... CHECKS PASSED`.
- File yang BOLEH berubah: `db/README.md`, `db/SCHEMA_STATE.md`, `db/scripts/001..007.sql` (001 & 003 ternyata tak perlu diubah), `docs/superpowers/plans/execution-task-2-database-plan.md`.

---

## Ringkasan Temuan, Akar Masalah & Rancangan

### Temuan 1 — Private activity leakage
**Akar masalah:** `trg_library_activity()` (005) membuat baris `activities` tanpa memeriksa `library_entries.visibility`; policy `activities_select_public using (true)` membuat feed publik. Entri PRIVATE → aktivitas publik (bocor judul buku + fakta bacaan). Tidak ada penanganan transisi visibility, dan aktivitas lama tetap publik setelah entri diprivatisasi.
**Rancangan (keputusan baru — dicatat di plan doc §1A):**
- **Invarian:** baris aktivitas bertipe library (`BOOK_ADDED`, `BOOK_STARTED`, `BOOK_FINISHED`, `READING_PROGRESS_UPDATED`) ada **⟺** entri ada **DAN** `visibility = 'PUBLIC'`.
- INSERT entri PRIVATE → tanpa aktivitas. UPDATE status/progress saat PRIVATE → tanpa aktivitas.
- Transisi **PRIVATE → PUBLIC (saja)** → tanpa aktivitas retroaktif (toggle visibility bukan peristiwa membaca; feed mencatat aksi baca, bukan aksesibilitas). Perubahan status/progress **setelah** publik → aktivitas normal.
- Transisi **PUBLIC → PRIVATE** → **hapus** aktivitas library milik (actor, book) itu (tipe di atas saja — aktivitas review tetap ada).
- **DELETE** entri publik → hapus juga aktivitas library-nya (invarian bersih).
- Filter tipe menjaga aktivitas `REVIEW_CREATED`/`RATING_CREATED` (konten review memang publik) tetap utuh.
- Feed tetap `using (true)` (hanya aktivitas yang lahir dari entri publik/review — jejak publik); matriks §3 plan doc diselaraskan (lihat Task 7).

### Temuan 2 — Book metadata integrity
**Akar masalah:** policy `books_update_authenticated` (002) + (via default privileges Supabase) grant UPDATE tabel `books` → **semua user terautentikasi bisa menimpa metadata buku bersama** (vandalisme/poisoning lintas-user). Keputusan awal hanya menutup "merge sembarangan", bukan update bebas.
**Rancangan:**
- **Klien: INSERT-only.** Hapus policy `books_update_authenticated`; `revoke all` + `grant select` (anon & authenticated) + `grant insert` (authenticated) saja — tanpa UPDATE/DELETE untuk siapa pun dari client.
- Jalur pencarian: klien memanggil Google Books/Open Library **live dari client** (endpoint publik — **tanpa API secret di client**; kunci opsional Google bila nanti dibutuhkan harus tipe-restricted, di luar cakupan DB ini).
- Penyimpanan: `INSERT ... ON CONFLICT DO NOTHING` (butuh hak INSERT saja; pola upsert klien **tanpa** `DO UPDATE` yang butuh hak UPDATE). Baris yang sudah ada dipakai apa adanya (**first-writer-wins**).
- Koreksi metadata: **operator via SQL Editor Dashboard** (owner bypass RLS) — sesuai arsitektur Dashboard-first; dicatat di README.
- Index pendukung: tetap (unique per identifier).

### Temuan 3 — Notification column permissions
**Akar masalah:** `notifications_update_own` memberi UPDATE **baris penuh** → pemilik bisa mengubah `notification_type`/`actor_id`/`review_id`/`comment_id` notifikasinya (integritas data buatan trigger) dan (tanpa column grant) tidak ada pembatasan kolom sama sekali; `user_id` hanya dijaga `with check`, bukan grant.
**Rancangan (pola notes di 003):**
- `revoke all on table notifications from anon, authenticated;`
- `grant select (id, user_id, notification_type, actor_id, review_id, comment_id, read, created_at) to authenticated;` — **anon: nol grant** (notifikasi butuh login).
- `grant update (read) on notifications to authenticated;` — **hanya kolom `read`**.
- Policy RLS `notifications_update_own` **dipertahankan** (baris = milik sendiri). Grant = gate kolom, RLS = gate baris (dua lapis, temuan 5).

### Temuan 4 — Profile statistics privacy
**Akar masalah:** `profile_stats` (004) menghitung `library_entries` **tanpa filter visibility** → angka publik "selesai/dibaca" membocorkan volume koleksi privat (keputusan 7 hanya menjamin tanpa *detail baris*, bukan tanpa *jejak agregat*).
**Rancangan (penajaman keputusan 7 — alasannya dicatat di plan doc §1A):**
- `books_read` & `currently_reading` hanya menghitung entri **`visibility = 'PUBLIC'`**. Entri privat = tidak dihitung sama sekali di statistik publik.
- `reviews_count`, `followers_count`, `following_count` tidak berubah (sudah artefak publik).
- Statistik pribadi milik pemilik (termasuk privat) **tidak lewat view ini** — klien menghitung dari baris yang terlihat via RLS (`library_entries` own). Tanpa view kedua (YAGNI).

### Temuan 5 — Explicit grants audit
**Akar masalah:** hanya `library_entries` yang grant-nya eksplisit; 8 tabel lain & view mengandalkan **default privileges Supabase** (ALL ke anon/authenticated saat CREATE) → privilege SQL jauh lebih luas dari policy RLS; keduanya harus membatasi.
**Rancangan:** pola **`revoke all` → `grant` eksplisit minimal** di 002/004/005 (per tabel, per role), + audit fungsi definer/trigger di 007 (owner `postgres`, `proconfig search_path=`). Matriks akhir:

| Tabel | anon SELECT | auth SELECT | auth INSERT | auth UPDATE | auth DELETE |
|---|---|---|---|---|---|
| profiles | ✓ | ✓ | ✗ (trigger signup) | ✓ (baris own via RLS) | ✗ |
| books | ✓ | ✓ | ✓ | **✗ (baru)** | ✗ |
| library_entries | ✓ (kolom tanpa notes) | ✓ (kolom tanpa notes) | ✓ | ✓ (tabel; baris own via RLS) | ✓ |
| reviews | ✓ | ✓ | ✓ | ✓ (edit/soft-delete own) | ✗ |
| likes | ✓ | ✓ | ✓ | ✗ | ✓ |
| comments | ✓ | ✓ | ✓ | ✗ | ✓ |
| follows | ✓ | ✓ | ✓ | ✗ | ✓ |
| activities | ✓ | ✓ | ✗ | ✗ | ✗ |
| notifications | **✗ (baru)** | ✓ (kolom) | ✗ | ✓ **hanya kolom `read` (baru)** | ✗ |

View `book_rating_summary`/`profile_stats`: `revoke all` lalu `grant select` (hygiene). Fungsi trigger tak bisa dipanggil langsung oleh klien (PG: "trigger functions can only be called as triggers"); `library_entry_notes` sudah benar (003 tetap).

---

### Daftar negative test baru (39 → total **76** asersi; penomoran baru: S, K, N, V, AN; P06–P07)

| ID | Sesi | Asersi |
|---|---|---|
| S01 | A-kembali (sebelum A20) | `profile_stats` A: `books_read=1 AND currently_reading=0` (entry_pub PUBLIC FINISHED; entry_priv PRIVATE READING tak dihitung) |
| K01 | A | `UPDATE books SET title=...` → **gagal 42501** (tanpa grant UPDATE) |
| K02 | A | `INSERT` buku baru → **lolos** (kontrol positif insert-only) |
| K03 | A | `INSERT ... ON CONFLICT (google_books_id) DO NOTHING` duplikat → **lolos** (jalur upsert klien) |
| K04 | P | judul `book1` masih `'Buku Uji 006-1'` (K01 tak berefek) |
| N01 | A | `UPDATE notif sendiri SET notification_type` → **gagal 42501** (grant kolom) |
| N02 | A | `UPDATE notif sendiri SET actor_id` → **gagal 42501** |
| N03 | A | `UPDATE notif sendiri SET user_id` → **gagal 42501** |
| N04 | B | `UPDATE notif milik A SET read` → **0 baris** (RLS own) |
| V01 | A | INSERT entri **PRIVATE** (vb1) → lolos |
| V02 | A | aktivitas library vb1 = 0 (entri PRIVATE tanpa aktivitas) |
| V03 | A | INSERT entri **PUBLIC** (vb2) → lolos |
| V04 | A | aktivitas library vb2 ≥ 1 (BOOK_ADDED tercipta) |
| V05 | A | UPDATE status vb1 saat **PRIVATE** → lolos (tanpa aktivitas) |
| V06 | A | status berubah saat PRIVATE tetap aktivitas library = 0 |
| V07 | A | vb1 PRIVATE→PUBLIC saja → lolos |
| V08 | A | transisi PRIVATE→PUBLIC **tanpa aktivitas retroaktif** (= 0) |
| V09 | A | UPDATE progress vb1 (kini PUBLIC) → lolos |
| V10 | A | progress saat PUBLIC → aktivitas library ≥ 1 |
| V11 | A | INSERT review vb1 berkonten → lolos |
| V12 | A | aktivitas `REVIEW_CREATED` vb1 = 1 |
| V13 | A | vb1 PUBLIC→PRIVATE → lolos |
| V14 | A | **purge**: aktivitas library vb1 = 0 setelah PUBLIC→PRIVATE |
| V15 | A | aktivitas review vb1 **tetap = 1** (purge bertipe) |
| V16 | A | DELETE entri vb2 (PUBLIC) → lolos |
| V17 | A | aktivitas library vb2 = 0 setelah DELETE entri publik |
| V18 | B | UPDATE visibility entri milik A → **0 baris** |
| AN01 | anon | SELECT `notes` → gagal 42501 |
| AN02 | anon | INSERT `library_entries` → gagal 42501 |
| AN03 | anon | INSERT `activities` → gagal 42501 |
| AN04 | anon | UPDATE `notifications.read` → gagal 42501 |
| AN05 | anon | SELECT `activities` ≥ 1 (feed publik tetap terbaca) |
| AN06 | anon | SELECT `profile_stats` ≥ 1 (statistik publik tetap terbaca) |
| AN07 | anon | entri PUBLIC (entry_pub) terlihat = 1 |
| AN08 | anon | entri PRIVATE (entry_priv) terlihat = 0 |
| P06 | P | setelah A20: `books_read=1 AND currently_reading=1` (publik terhitung; vb1 privat tidak) |
| P07 | P | notif REVIEW_LIKED: `notification_type` & `actor_id` utuh setelah upaya N01/N02 |

Check 007 baru (total **31**): 21 books tanpa policy UPDATE/DELETE · 22 books tanpa grant UPDATE/DELETE · 23 profile_stats hanya PUBLIC · 24 notifications UPDATE grant = `read` · 25 notifications anon nol grant · 26 notifications tanpa grant INSERT/DELETE · 27 activities klien hanya SELECT · 28 profiles klien tanpa INSERT/DELETE · 29 likes/comments/follows tanpa grant UPDATE · 30 reviews tanpa grant DELETE · 31 7 fungsi definer owner+search_path.

### Risiko yang masih tersisa
1. **Asumsi greenfield** — tak ada backfill aktivitas lama (SQL belum pernah dijalankan); bila ternyata pernah, perlu purge manual.
2. **First-writer-wins** metadata buku; koreksi hanya manual via SQL Editor (terdokumentasi).
3. **Dedup lintas provider** — buku sama dengan identifier berbeda → baris kembar (keterbatasan pra-ada, di luar temuan).
4. **Statistik publik kini lebih ketat** — jumlah pribadi (termasuk privat) tak ada di `profile_stats`; pemilik menghitung sendiri dari baris RLS-nya (tercatat sebagai penajaman keputusan 7).
5. **Feed tetap publik** untuk aktivitas yang sah; matriks §3 plan doc diselaraskan (penyelarasan rencana↔skrip, bukan perubahan produk baru).
6. **Default privileges `service_role` & USAGE schema** tidak dicabut (MVP tanpa service key; service_role memang BYPASSRLS by design) — di luar cakupan audit (anon/authenticated only).
7. **Anti-drift grant** — kolom baru wajib ditambahkan ke daftar grant eksplisit (dicatat di README).
8. `db/AUDIT_REVIEW_BUNDLE.md` jadi basi (snapshot sebelum revisi).
9. 006 tumbuh → 76 asersi (satu transaksi + ROLLBACK; eksekusi manual lebih lama, tetap nol residu).

### Urutan implementasi (8 task)
1. `002` — grants eksplisit profiles/books + hapus policy UPDATE books (temuan 2+5).
2. `004` — filter PUBLIC di `profile_stats` + grants eksplisif 4 tabel sosial & view (temuan 4+5).
3. `005` — rewrite `trg_library_activity` (temuan 1) + grants activities/notifications + index purge (temuan 3+5).
4. `006` — fixture vb1/vb2 + 37 test baru (S, K, N, V, AN, P06–P07) + pembaruan header/marker.
5. `007` — check 21–31 + pembaruan komentar header.
6. `db/README.md` + `db/SCHEMA_STATE.md` — dokumentasi aturan baru + perbaikan marker salah (`ALL RLS TESTS PASSED` → `ALL NEGATIVE TESTS PASSED`).
7. `docs/superpowers/plans/execution-task-2-database-plan.md` — §1A keputusan revisi + selaraskan §1/§3/§6/§8/§9.
8. Verifikasi statis menyeluruh (grep/diff/hash) — **tanpa SQL, tanpa commit**.

---

### Task 1: `db/scripts/002_identity_books.sql` — books insert-only + grants eksplisit

**Files:**
- Modify: `db/scripts/002_identity_books.sql` (blok RLS `-- -------------------------------------------------------------------- RLS --` sampai akhir file)

**Interfaces:**
- Produces: tabel `profiles` (anon/auth: SELECT; auth: UPDATE) & `books` (anon/auth: SELECT; auth: INSERT; **tanpa UPDATE/DELETE**); **tidak ada** policy `books_update_authenticated`. Task 4 (006 K01–K03) mengasumsikan kondisi ini.

- [ ] **Step 1: Sisipkan blok grant setelah `alter table ... enable row level security` (sebelum blok `do $$` policy)**

```sql
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
```

- [ ] **Step 2: Hapus policy `books_update_authenticated`** — hapus seluruh blok:

```sql
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'books'
                 and policyname = 'books_update_authenticated') then
    execute $p$ create policy "books_update_authenticated" on public.books
      for update using (auth.uid() is not null)
      with check (auth.uid() is not null) $p$;
  end if;
```

Komentar penutup `-- books: TANPA policy delete` → `-- books: TANPA policy update/delete (insert-only; koreksi operator via SQL Editor)`.

- [ ] **Step 3: Perbarui blok VERIFY di akhir file** — ganti baris harapan kebijakan:

```sql
-- harapkan 4 policy (2 profiles + 3 books), tanpa insert/delete di profiles, tanpa update/delete di books
```

(tambahkan juga query grant untuk dokumentasi visual):

```sql
select grantee, privilege_type, table_name
from information_schema.table_privileges
where table_schema = 'public' and table_name in ('profiles', 'books')
  and grantee in ('anon', 'authenticated')
order by table_name, grantee, privilege_type;
-- harapkan: profiles=select,update; books=select,insert (TANPA update/delete utk client)
```

- [ ] **Step 4: Verifikasi statis**

Run: `grep -n "books_update_authenticated" db/scripts/002_identity_books.sql`
Expected: **nol hasil**. Lalu `grep -n "revoke all on table public.books\|grant insert on table public.books" db/scripts/002_identity_books.sql` → 2 hasil.

---

### Task 2: `db/scripts/004_reviews_social.sql` — stats hanya PUBLIC + grants sosial

**Files:**
- Modify: `db/scripts/004_reviews_social.sql`

**Interfaces:**
- Consumes: keputusan 7 (penajaman §1A).
- Produces: `profile_stats` menghitung `books_read`/`currently_reading` hanya entri PUBLIC; tabel reviews/likes/comments/follows punya grant eksplisit (sesuai matriks §Ringkasan Temuan 5). Task 4 (S01, P06) & Task 5 (check 23, 29, 30) mengasumsikan ini.

- [ ] **Step 1: Filter visibility di `profile_stats`** — ganti kedua subquery `library_entries`:

```sql
create or replace view public.profile_stats as
select
  p.id as profile_id,
  (select count(*) from public.library_entries l
    where l.user_id = p.id and l.visibility = 'PUBLIC' and l.status = 'FINISHED')::bigint as books_read,
  (select count(*) from public.library_entries l
    where l.user_id = p.id and l.visibility = 'PUBLIC' and l.status = 'READING')::bigint as currently_reading,
  (select count(*) from public.reviews r
    where r.user_id = p.id and r.deleted_at is null)::bigint as reviews_count,
  (select count(*) from public.follows f where f.following_id = p.id)::bigint as followers_count,
  (select count(*) from public.follows f where f.follower_id = p.id)::bigint as following_count
from public.profiles p;
```

Catatan: urutan predicate ditulis persis `l.visibility = 'PUBLIC' and l.status = ...` (check 007 #23 mengandalkan kemunculan `PUBLIC` ≥ 2 di viewdef).

- [ ] **Step 2: Grants eksplisit 4 tabel** — sisipkan setelah `alter table ... enable row level security` (keempatnya) dan sebelum blok `do $$` policy:

```sql
-- Grant EKSPLISIT (temuan audit 5) — pola revoke lalu grant minimal:
revoke all on table public.reviews from anon, authenticated;
grant select on table public.reviews to anon, authenticated;
grant insert, update on public.reviews to authenticated;   -- edit/soft-delete own; TANPA delete

revoke all on table public.likes from anon, authenticated;
grant select on table public.likes to anon, authenticated;
grant insert, delete on public.likes to authenticated;     -- tanpa update

revoke all on table public.comments from anon, authenticated;
grant select on table public.comments to anon, authenticated;
grant insert, delete on public.comments to authenticated;  -- tanpa update (PRD: hapus saja)

revoke all on table public.follows from anon, authenticated;
grant select on table public.follows to anon, authenticated;
grant insert, delete on public.follows to authenticated;   -- tanpa update
```

- [ ] **Step 3: Hygiene grant view** — ganti dua baris grant view yang ada:

```sql
revoke all on view public.book_rating_summary from anon, authenticated;
grant select on public.book_rating_summary to anon, authenticated;
```

```sql
revoke all on view public.profile_stats from anon, authenticated;
grant select on public.profile_stats to anon, authenticated;
```

- [ ] **Step 4: Perbarui komentar `-- Keputusan 7` di atas `profile_stats`** menjadi:

```sql
-- Keputusan 7 (diperjelas revisi audit 2026-11-08): statistik profil publik HANYA angka
-- yang berasal dari entri PUBLIC (books_read/currently_reading) — jejak privat tidak
-- dihitung sama sekali; reviews/follows memang artefak publik. Owner-side stats pribadi
-- dihitung klien dari baris sendiri via RLS (tanpa view kedua).
```

- [ ] **Step 5: Verifikasi statis**

Run: `grep -c "l.visibility = 'PUBLIC'" db/scripts/004_reviews_social.sql` → **2**.
Run: `grep -n "revoke all on table public.reviews\|revoke all on table public.likes\|revoke all on table public.comments\|revoke all on table public.follows" db/scripts/004_reviews_social.sql` → **4**.

---

### Task 3: `db/scripts/005_activity_notifications.sql` — trigger visibility-aware + grants kolom notifikasi

**Files:**
- Modify: `db/scripts/005_activity_notifications.sql`

**Interfaces:**
- Produces: invarian aktivitas-library (lihat Temuan 1); fungsi `trg_library_activity` dengan event `INSERT OR UPDATE OR DELETE`; index `activities_actor_book_idx`; activities: klien hanya SELECT; notifications: auth SELECT kolom + UPDATE `read` saja, anon nol grant. Task 4 (V/AN/N tests) & Task 5 (check 24–27, 31) mengasumsikan ini.

- [ ] **Step 1: Grants eksplisit** — sisipkan setelah `alter table ... enable row level security` (kedua tabel) dan sebelum blok `do $$` policy:

```sql
-- Grant EKSPLISIT (temuan audit 5):
-- activities: publik hanya BOLEH BACA; tulis hanya trigger definer (temuan 1).
revoke all on table public.activities from anon, authenticated;
grant select on table public.activities to anon, authenticated;

-- notifications: anon NOL grant; authenticated baca kolom + UPDATE hanya kolom `read`
-- (temuan 3 — notification_type/actor_id/user_id/dll tidak bisa diubah klien).
revoke all on table public.notifications from anon, authenticated;
grant select (id, user_id, notification_type, actor_id, review_id, comment_id, read, created_at)
      on public.notifications to authenticated;
grant update (read) on public.notifications to authenticated;
```

- [ ] **Step 2: Index untuk jalur purge** — sisipkan setelah index `activities_actor_idx`:

```sql
create index if not exists activities_actor_book_idx on public.activities (actor_id, book_id);
```

- [ ] **Step 3: Ganti SELURUH fungsi `trg_library_activity`** (create or replace yang ada) dengan versi visibility-aware:

```sql
create or replace function public.trg_library_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_type public.activity_type;
begin
  if tg_op = 'DELETE' then
    if old.visibility = 'PUBLIC' then
      delete from public.activities
      where actor_id = old.user_id and book_id = old.book_id
        and activity_type in ('BOOK_ADDED', 'BOOK_STARTED', 'BOOK_FINISHED',
                              'READING_PROGRESS_UPDATED');
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if new.visibility <> 'PUBLIC' then
      return new; -- entri PRIVATE: tanpa aktivitas publik (temuan audit 1)
    end if;
    if new.status = 'READING' then v_type := 'BOOK_STARTED';
    elsif new.status = 'FINISHED' then v_type := 'BOOK_FINISHED';
    else v_type := 'BOOK_ADDED';
    end if;
    insert into public.activities (actor_id, book_id, activity_type)
    values (new.user_id, new.book_id, v_type);
    return new;
  end if;

  -- UPDATE ---------------------------------------------------------------
  if new.visibility = 'PRIVATE' then
    if old.visibility = 'PUBLIC' then
      -- PUBLIC -> PRIVATE: hapus aktivitas library lama agar tak bocor (temuan audit 1)
      delete from public.activities
      where actor_id = new.user_id and book_id = new.book_id
        and activity_type in ('BOOK_ADDED', 'BOOK_STARTED', 'BOOK_FINISHED',
                              'READING_PROGRESS_UPDATED');
    end if;
    return new; -- sekarang privat: tanpa aktivitas baru
  end if;

  -- sekarang PUBLIC:
  if new.status <> old.status then
    if new.status = 'READING' then v_type := 'BOOK_STARTED';
    elsif new.status = 'FINISHED' then v_type := 'BOOK_FINISHED';
    else return new; -- mundur ke WANT_TO_READ: tanpa aktivitas
    end if;
  elsif new.progress is distinct from old.progress then
    v_type := 'READING_PROGRESS_UPDATED';
  elsif old.visibility = 'PRIVATE' then
    return new; -- PRIVATE -> PUBLIC (tanpa aksi baca): TANPA aktivitas retroaktif
  else
    return new; -- perubahan tak relevan
  end if;
  insert into public.activities (actor_id, book_id, activity_type)
  values (new.user_id, new.book_id, v_type);
  return new;
end $$;
```

- [ ] **Step 4: Buat ulang trigger dengan event DELETE** — ganti guard `do $$` pembuatan `trg_library_activity` menjadi:

```sql
do $$
begin
  if exists (select 1 from pg_trigger where tgname = 'trg_library_activity'
             and tgrelid = 'public.library_entries'::regclass) then
    drop trigger trg_library_activity on public.library_entries;
  end if;
  create trigger trg_library_activity
    after insert or update or delete on public.library_entries
    for each row execute function public.trg_library_activity();
end $$;
```

- [ ] **Step 5: Perbarui komentar pemetaan (di atas fungsi)** — tambah baris:

```sql
-- Invarian (revisi audit 2026-11-08): aktivitas library ada ⟺ entri ada DAN visibility PUBLIC.
-- PRIVATE -> PUBLIC: tanpa retroaktif; PUBLIC -> PRIVATE / DELETE entri publik: purge tipe library.
-- Aktivitas review (REVIEW_CREATED/RATING_CREATED) tidak ikut di-purge (konten review publik).
```

- [ ] **Step 6: Verifikasi statis**

Run: `grep -n "after insert or update or delete on public.library_entries" db/scripts/005_activity_notifications.sql` → 1.
Run: `grep -c "old.visibility" db/scripts/005_activity_notifications.sql` → ≥3.
Run: `grep -n "grant update (read) on public.notifications" db/scripts/005_activity_notifications.sql` → 1.
Run: `grep -n "revoke all on table public.activities" db/scripts/005_activity_notifications.sql` → 1.

---

### Task 4: `db/scripts/006_negative_tests.sql` — fixture + 37 test baru

**Files:**
- Modify: `db/scripts/006_negative_tests.sql`

**Interfaces:**
- Consumes: perubahan Task 1–3.
- Produces: marker `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`; id fixture baru `book_v1`, `book_v2`; sesi baru SESI V & SESI ANON.

- [ ] **Step 1: Perbarui header** — ganti 2 baris terakhir header:

```sql
-- Marker keberhasilan: 'ALL NEGATIVE TESTS PASSED' (76 pemeriksaan)
-- Sesi: A → B → A-kembali (notifikasi/statistik) → V (visibility) → ANON → POSTGRES.
```

- [ ] **Step 2: Tambahkan 2 buku fixture di akhir blok fixture** — sisipkan sebelum `insert into public._t006_ids` dan tambahkan key-nya:

```sql
  insert into public.books (google_books_id, title, authors)
  values ('t006-book-v1', 'Buku Uji V1', array['Penulis Uji'])
  returning id into v_book_v1;
  insert into public.books (google_books_id, title, authors)
  values ('t006-book-v2', 'Buku Uji V2', array['Penulis Uji'])
  returning id into v_book_v2;
```

```sql
  insert into public._t006_ids (k, v) values
    ('a', v_a), ('b', v_b), ('book1', v_book1), ('book2', v_book2),
    ('entry_priv', v_entry_priv), ('entry_pub', v_entry_pub), ('review', v_review),
    ('book_v1', v_book_v1), ('book_v2', v_book_v2);
```

Tambah deklarasi variabel di `declare`: `v_book_v1 uuid; v_book_v2 uuid;`.

- [ ] **Step 3: Tambahkan K01–K03 di akhir SESI A (setelah A12)**

```sql
select public._t006_expect_fail('K01 UPDATE books oleh authenticated DITOLAK (insert-only)', $sql$
  update public.books set title = 'HACKED-TITLE'
  where id = (select v from public._t006_ids where k = 'book1')
$sql$);

select public._t006_expect_pass('K02 kontrol positif: INSERT buku baru oleh authenticated', $sql$
  insert into public.books (google_books_id, title, authors)
  values ('t006-book-3', 'Buku Uji K02', array['Penulis Uji'])
$sql$);

select public._t006_expect_pass('K03 jalur upsert klien: ON CONFLICT DO NOTHING tanpa hak UPDATE', $sql$
  insert into public.books (google_books_id, title, authors)
  values ('t006-book-1', 'Duplikat', array['X'])
  on conflict (google_books_id) do nothing
$sql$);
```

- [ ] **Step 4: Tambahkan N04 di akhir SESI B (setelah B13)**

```sql
select public._t006_expect_0rows('N04 B TIDAK bisa menandai read notifikasi A (RLS own)', $sql$
  update public.notifications set read = true
  where user_id = (select v from public._t006_ids where k = 'a')
$sql$);
```

- [ ] **Step 5: Tambahkan N01–N03 di SESI A KEMBALI (setelah A15)**

```sql
select public._t006_expect_fail('N01 notification_type notifikasi sendiri TIDAK bisa diubah', $sql$
  update public.notifications set notification_type = 'NEW_FOLLOWER'
  where id = (select id from public.notifications
              where user_id = (select v from public._t006_ids where k = 'a')
                and notification_type = 'REVIEW_LIKED' limit 1)
$sql$);

select public._t006_expect_fail('N02 actor_id notifikasi sendiri TIDAK bisa diubah', $sql$
  update public.notifications set actor_id = (select v from public._t006_ids where k = 'a')
  where id = (select id from public.notifications
              where user_id = (select v from public._t006_ids where k = 'a')
                and notification_type = 'REVIEW_LIKED' limit 1)
$sql$);

select public._t006_expect_fail('N03 user_id notifikasi sendiri TIDAK bisa diubah', $sql$
  update public.notifications set user_id = (select v from public._t006_ids where k = 'b')
  where id = (select id from public.notifications
              where user_id = (select v from public._t006_ids where k = 'a')
                and notification_type = 'REVIEW_LIKED' limit 1)
$sql$);
```

- [ ] **Step 6: Tambahkan S01 di SESI A KEMBALI (di antara A19 dan A20)**

```sql
select public._t006_expect_true('S01 stats publik TANPA koleksi privat (baca=1, sedang=0)', $sql$
  select books_read = 1 and currently_reading = 0 from public.profile_stats
  where profile_id = (select v from public._t006_ids where k = 'a')
$sql$);
```

(Urutan wajib: S01 **sebelum** A20 — A20 mengubah entry_priv jadi PUBLIC.)

- [ ] **Step 7: Tambahkan SESI V (sesi baru, setelah SESI A KEMBALI, sebelum blok POSTGRES)**

```sql
-- ===================================================== SESI V (visibility) --
reset role;
reset request.jwt.claims;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "' || (select v from public._t006_ids where k = 'a') || '", "role": "authenticated"}',
  true);

select public._t006_expect_pass('V01 INSERT entri PRIVATE (vb1) diizinkan', $sql$
  insert into public.library_entries (user_id, book_id, visibility)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book_v1'), 'PRIVATE')
$sql$);

select public._t006_expect_true('V02 entri PRIVATE TANPA aktivitas publik', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);

select public._t006_expect_pass('V03 INSERT entri PUBLIC (vb2) diizinkan', $sql$
  insert into public.library_entries (user_id, book_id, visibility)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book_v2'), 'PUBLIC')
$sql$);

select public._t006_expect_true('V04 entri PUBLIC membuat aktivitas (BOOK_ADDED)', $sql$
  select count(*) >= 1 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v2')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);

select public._t006_expect_pass('V05 UPDATE status vb1 saat PRIVATE diizinkan (tanpa aktivitas)', $sql$
  update public.library_entries set status = 'READING'
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);

select public._t006_expect_true('V06 status berubah saat PRIVATE tetap TANPA aktivitas', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);

select public._t006_expect_pass('V07 vb1 PRIVATE -> PUBLIC saja diizinkan', $sql$
  update public.library_entries set visibility = 'PUBLIC'
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);

select public._t006_expect_true('V08 transisi PRIVATE->PUBLIC TANPA aktivitas retroaktif', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);

select public._t006_expect_pass('V09 UPDATE progress vb1 (kini PUBLIC) diizinkan', $sql$
  update public.library_entries set progress = 40
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);

select public._t006_expect_true('V10 progress saat PUBLIC MEMBUAT aktivitas', $sql$
  select count(*) >= 1 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);

select public._t006_expect_pass('V11 A membuat review berkonten pada vb1', $sql$
  insert into public.reviews (user_id, book_id, rating, content)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book_v1'), 4.5, 'Konten uji visibility')
$sql$);

select public._t006_expect_true('V12 aktivitas REVIEW_CREATED vb1 tercipta', $sql$
  select count(*) = 1 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type = 'REVIEW_CREATED'
$sql$);

select public._t006_expect_pass('V13 vb1 PUBLIC -> PRIVATE diizinkan', $sql$
  update public.library_entries set visibility = 'PRIVATE'
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
$sql$);

select public._t006_expect_true('V14 PUBLIC->PRIVATE MEMPURGE aktivitas library (bocor dicegah)', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);

select public._t006_expect_true('V15 aktivitas REVIEW vb1 TIDAK ikut terhapus (purge bertipe)', $sql$
  select count(*) = 1 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v1')
    and activity_type = 'REVIEW_CREATED'
$sql$);

select public._t006_expect_pass('V16 DELETE entri vb2 (PUBLIC) diizinkan', $sql$
  delete from public.library_entries
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v2')
$sql$);

select public._t006_expect_true('V17 DELETE entri publik MEMPURGE aktivitas library-nya', $sql$
  select count(*) = 0 from public.activities
  where actor_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book_v2')
    and activity_type in ('BOOK_ADDED','BOOK_STARTED','BOOK_FINISHED','READING_PROGRESS_UPDATED')
$sql$);
```

Lalu ganti sesi ke B untuk V18:

```sql
reset role;
reset request.jwt.claims;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub": "' || (select v from public._t006_ids where k = 'b') || '", "role": "authenticated"}',
  true);

select public._t006_expect_0rows('V18 B TIDAK bisa mengubah visibility entri milik A', $sql$
  update public.library_entries set visibility = 'PRIVATE'
  where user_id = (select v from public._t006_ids where k = 'a')
    and book_id = (select v from public._t006_ids where k = 'book1')
$sql$);
```

(Catatan: penomoran V01–V18 = 18 test; total akhir dihitung ulang di Step 10.)

- [ ] **Step 8: Tambahkan SESI ANON (setelah SESI V, sebelum blok POSTGRES)**

```sql
-- ==================================================== SESI ANON (tanpa login) --
reset role;
reset request.jwt.claims;
set local role anon;

select public._t006_expect_fail('AN01 anon TIDAK bisa SELECT notes', $sql$
  select notes from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);

select public._t006_expect_fail('AN02 anon TIDAK bisa INSERT library_entries', $sql$
  insert into public.library_entries (user_id, book_id, visibility)
  values ((select v from public._t006_ids where k = 'a'),
          (select v from public._t006_ids where k = 'book1'), 'PUBLIC')
$sql$);

select public._t006_expect_fail('AN03 anon TIDAK bisa INSERT activities', $sql$
  insert into public.activities (actor_id, activity_type)
  values ((select v from public._t006_ids where k = 'a'), 'BOOK_ADDED')
$sql$);

select public._t006_expect_fail('AN04 anon TIDAK bisa UPDATE notifications', $sql$
  update public.notifications set read = true
  where user_id = (select v from public._t006_ids where k = 'a')
$sql$);

select public._t006_expect_true('AN05 anon MASIH bisa membaca activity feed publik', $sql$
  select count(*) >= 1 from public.activities
$sql$);

select public._t006_expect_true('AN06 anon MASIH bisa membaca statistik profil publik', $sql$
  select count(*) >= 1 from public.profile_stats
$sql$);

select public._t006_expect_true('AN07 anon melihat entri PUBLIC', $sql$
  select count(*) = 1 from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_pub')
$sql$);

select public._t006_expect_true('AN08 anon TIDAK melihat entri PRIVATE', $sql$
  select count(*) = 0 from public.library_entries
  where id = (select v from public._t006_ids where k = 'entry_priv')
$sql$);
```

- [ ] **Step 9: Tambahkan K04, P06, P07 di blok POSTGRES (setelah P05)**

```sql
select public._t006_expect_true('K04 judul book1 utuh (UPDATE klien tadi tidak berefek)', $sql$
  select title = 'Buku Uji 006-1' from public.books
  where id = (select v from public._t006_ids where k = 'book1')
$sql$);

select public._t006_expect_true('P06 stats: entri publik terhitung (baca=1, sedang=1); vb1 privat tidak', $sql$
  select books_read = 1 and currently_reading = 1 from public.profile_stats
  where profile_id = (select v from public._t006_ids where k = 'a')
$sql$);

select public._t006_expect_true('P07 notif REVIEW_LIKED utuh (type & actor tidak berubah oleh N01/N02)', $sql$
  select notification_type = 'REVIEW_LIKED'
     and actor_id = (select v from public._t006_ids where k = 'b')
  from public.notifications
  where user_id = (select v from public._t006_ids where k = 'a')
    and notification_type = 'REVIEW_LIKED'
  limit 1
$sql$);
```

- [ ] **Step 10: Hitung ulang total & perbarui komentar ringkasan bila perlu**

Run: `grep -c "^select public._t006_expect" db/scripts/006_negative_tests.sql`
Expected: **76** (39 lama + 37 baru: S01, K01–K04, N01–N04, V01–V18, AN01–AN08, P06–P07).
Jika ≠ 76, hitung ulang dan perbarui teks marker header (`76 pemeriksaan`) agar konsisten — teks marker `ALL NEGATIVE TESTS PASSED` sendiri otomatis (count dinamis), jadi tidak ada hardcode di query ringkasan.

- [ ] **Step 11: Verifikasi urutan sesi & tanpa duplikasi ID**

Run: `grep -n "^-- =\+ SESI\|^-- =\+ FIXTURE\|^-- =\+ POSTGRES\|^-- =\+ RINGKASAN" db/scripts/006_negative_tests.sql`
Expected urutan: FIXTURE → SESI A → SESI B → SESI A KEMBALI → SESI V → SESI ANON → POSTGRES → RINGKASAN.
Run: `grep -o "'[ABPSKVN][0-9][0-9] " db/scripts/006_negative_tests.sql | sort | uniq -d` → **nol hasil** (ID unik).

---

### Task 5: `db/scripts/007_verify_schema.sql` — check 21–31

**Files:**
- Modify: `db/scripts/007_verify_schema.sql`

**Interfaces:**
- Consumes: perubahan Task 1–3.
- Produces: 31 check (21–31 baru) + ringkasan dinamis `count(*)` (otomatis mengikuti).

- [ ] **Step 1: Sisipkan check 21–31 di dalam CTE `checks`** — tepat setelah baris check `20 library_entries: 4 policy ...` (sebelum `)` penutup CTE):

```sql
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
```

- [ ] **Step 2: Perbarui komentar header** — baris `-- berbunyi 'VERIFY SCHEMA: ALL ... CHECKS PASSED'.` → tambah `-- Kini 31 checks (20 awal + 11 revisi audit 2026-11-08).`

- [ ] **Step 3: Verifikasi statis**

Run: `grep -c "union all select '" db/scripts/007_verify_schema.sql` → **30** (check 1 memakai `select '01 ...` di awal CTE; 30 sisa union all = 30 → total 31).
Run: `grep -n "'31 7 fungsi definer" db/scripts/007_verify_schema.sql` → 1.
Pastikan `)` penutup CTE tetap setelah check 31 (bukan hilang): `grep -n "^)" db/scripts/007_verify_schema.sql` → minimal 1 (penutup `with checks as (`).

---

### Task 6: `db/README.md` + `db/SCHEMA_STATE.md`

**Files:**
- Modify: `db/README.md`
- Modify: `db/SCHEMA_STATE.md`

**Interfaces:**
- Consumes: hasil Task 1–5 (aturan baru & marker benar).

- [ ] **Step 1: README — perbarui tabel urutan eksekusi** (baris 002, 005, 006, 007):

```markdown
| 2 | `scripts/002_identity_books.sql` | `profiles` + trigger signup + `books` (dedup identifier, **insert-only utk klien**) + RLS + **grant eksplisit** |
| 5 | `scripts/005_activity_notifications.sql` | `activities`, `notifications` (insert hanya trigger; **aktivitas library hanya dari entri PUBLIC**; notifikasi: UPDATE hanya kolom `read`) + trigger + RLS + grant eksplisit |
| 6 | `scripts/006_negative_tests.sql` | 76 negative authorization test (2 akun uji + anon); satu transaksi, diakhiri ROLLBACK (nol residu) |
| 7 | `scripts/007_verify_schema.sql` | Audit akhir 31 checks: RLS 9 tabel, policy, grant eksplisit per tabel, kolom notifikasi, fungsi definer (owner/proconfig), ketiadaan policy UPDATE books, stats hanya PUBLIC |
```

- [ ] **Step 2: README — tambah seksi "Aturan grant & integritas" setelah "Aturan kerja":**

```markdown
## Aturan grant & integritas (revisi audit 2026-11-08)

1. **Grant eksplisit, bukan default privileges** — setiap tabel di-`REVOKE ALL` dari `anon`/`authenticated` lalu di-grant minimal (lihat matriks di plan revisi). **Kolom baru wajib ditambahkan ke daftar grant** (anti-drift) — 007 memantau.
2. **`books` insert-only untuk klien** — pencarian = Google Books/Open Library live dari client (**tanpa API secret di client**); simpan = `INSERT ... ON CONFLICT DO NOTHING` (first-writer-wins); **koreksi metadata = operator via SQL Editor** (owner bypass RLS). Tanpa policy/grant UPDATE/DELETE untuk client.
3. **Aktivitas library ⟺ entri PUBLIC** — trigger tidak pernah membuat aktivitas publik dari entri PRIVATE; `PUBLIC → PRIVATE`/`DELETE` entri publik mem-purge aktivitas library tipe `BOOK_*`/`READING_PROGRESS_UPDATED` (aktivitas review tetap); `PRIVATE → PUBLIC` tanpa aktivitas retroaktif.
4. **Notifikasi: UPDATE hanya kolom `read`** — `notification_type`/`actor_id`/`user_id`/dst. hanya bisa ditulis trigger definer; RLS tetap membatasi baris ke milik sendiri.
5. **Statistik publik tanpa jejak privat** — `profile_stats.books_read`/`currently_reading` hanya menghitung entri `PUBLIC`; statistik pribadi pemilik dihitung klien dari baris miliknya via RLS.
```

- [ ] **Step 3: README — perbarui bullet keamanan terakhir**:

```markdown
- Negative test memakai SQL Editor + dua akun uji + sesi anon (keputusan pengguna 2026-11-08) — tanpa service_role key.
```

- [ ] **Step 4: SCHEMA_STATE — perbaiki marker salah** — ganti:

```markdown
- [ ] 006: `ALL RLS TESTS PASSED`.
```

menjadi:

```markdown
- [ ] 006: `ALL NEGATIVE TESTS PASSED` (76 pemeriksaan).
- [ ] 007: `VERIFY SCHEMA: ALL 31 CHECKS PASSED`.
```

(hapus baris lama `- [ ] 007: 9/9 tabel RLS aktif; audit grant/fungsi lolos.` yang duplikat/bersifat umum — atau pertahankan bila dianggap checklist terpisah; **keputusan: ganti menjadi dua baris marker di atas**).

- [ ] **Step 5: SCHEMA_STATE — catat revisi di header** — sisipkan setelah baris 4:

```markdown
> Catatan: skrip direvisi pasca-audit keamanan 2026-11-08 **sebelum aplikasi pertama** (belum ada baris `applied`).
```

- [ ] **Step 6: Verifikasi statis**

Run: `grep -n "ALL RLS TESTS PASSED" db/SCHEMA_STATE.md db/README.md docs/superpowers/plans/execution-task-2-database-plan.md` → nol hasil (semua marker lama sudah diganti; plan doc ditangani Task 7).
Run: `grep -c "76 negative\|76 pemeriksaan" db/README.md db/SCHEMA_STATE.md` → ≥ 2 total.

---

### Task 7: `docs/superpowers/plans/execution-task-2-database-plan.md` — catat keputusan revisi

**Files:**
- Modify: `docs/superpowers/plans/execution-task-2-database-plan.md`

**Interfaces:**
- Produces: §1A (akar keputusan untuk semua perubahan produk/privasi yang dirinci di plan ini); §3/§6/§8/§9 diselaraskan. ADR **tidak diubah** (alasan: temuan murni level skema/grant/trigger; keputusan Dashboard-first/tanpa-CLI di ADR tidak tersentuh).

- [ ] **Step 1: Sisipkan section baru setelah §1 (sebelum `## 2. Arsitektur database`):**

```markdown
## 1A. Revisi Audit Keamanan (2026-11-08 — sebelum SQL dijalankan)

Lima temuan audit → keputusan (penajaman, bukan perubahan arsitektur; produk 1–8 tetap):

| # | Temuan | Keputusan hasil revisi | Alasan |
|---|---|---|---|
| A | Private activity leakage | **Invarian:** aktivitas library (BOOK_*/READING_PROGRESS_UPDATED) ada ⟺ entri ada DAN PUBLIC; PRIVATE→PUBLIC tanpa retroaktif; PUBLIC→PRIVATE & DELETE entri publik = purge tipe library; aktivitas review tak di-purge; feed tetap publik (hanya berisi aktivitas sah) | Aktivitas dari entri PRIVATE membocorkan judul/fakta bacaan; toggle visibility bukan peristiwa membaca; purge bertipe menjaga konten review yang memang publik |
| B | Book metadata integrity | Klien **INSERT-only** (`ON CONFLICT DO NOTHING`, first-writer-wins); tanpa policy/grant UPDATE/DELETE; koreksi = operator via SQL Editor; pencarian provider live dari client tanpa API secret | Update bebas = vandalisme metadata bersama; Dashboard-first sudah menyediakan jalur operator |
| C | Notification column permissions | Grant `UPDATE (read)` saja + RLS own dipertahankan; anon nol grant | Menjaga integritas baris buatan trigger; notifikasi = data privat butuh login |
| D | Profile statistics privacy | `books_read`/`currently_reading` **hanya entri PUBLIC**; stats pribadi = klien hitung dari baris RLS sendiri (tanpa view kedua) | Penajaman keputusan 7: "tanpa bocor detail privat" mencakup jejak agregat koleksi privat; angka publik wajib hanya berasal dari jejak publik |
| E | Explicit grants | Pola `REVOKE ALL` → grant minimal per tabel/anon/authenticated di 002/004/005; 007 audit 31 checks termasuk grant matrix & fungsi definer | Default privileges Supabase terlalu luas; RLS + privilege SQL wajib sama-sama membatasi |

Matriks §3 di bawah sudah diselaraskan dengan keputusan ini.
```

- [ ] **Step 2: Selaraskan matriks §3** — ganti baris `books` dan `notifications` dan `activities`:

```markdown
| books | publik | authenticated (dedup via unique) | **tidak ada** (insert-only; koreksi operator via SQL Editor) | **tidak ada** |
```

```markdown
| activities | publik (hanya aktivitas dari entri PUBLIC & review publik — invarian §1A) | **tidak ada** (trigger only) | **tidak ada** | **tidak ada** |
```

```markdown
| notifications | own | **tidak ada** (trigger only) | own, **hanya kolom `read`** (grant kolom + RLS own) | **tidak ada** |
```

- [ ] **Step 3: Perbarui tabel keputusan §1 baris keputusan 7** — tambahkan catatan:

```markdown
| 7 | **Profile statistics:** agregat **publik** via view `profile_stats` — hanya angka; **tidak membocorkan detail entri privat**; **revisi 2026-11-08:** `books_read`/`currently_reading` hanya menghitung entri **PUBLIC** (jejak privat tidak dihitung — alasan §1A-D) |
```

- [ ] **Step 4: Perbarui tabel risiko §6** — ganti/sekalian tambahkan baris:

```markdown
| Aktivitas membocorkan entri PRIVATE | Invarian trigger §1A: aktivitas library hanya dari entri PUBLIC; purge pada PUBLIC→PRIVATE & DELETE; diuji V01–V18 di 006 |
| Buku di-poison client (update metadata) | Klien INSERT-only + `ON CONFLICT DO NOTHING`; tanpa policy/grant UPDATE; koreksi operator via SQL Editor; diuji K01–K04 |
| Notifikasi dimanipulasi kolom | Grant `UPDATE (read)` saja + RLS own; anon nol grant; diuji N01–N04, AN04 |
| Agregat profil membocorkan library privat | `profile_stats` hanya menghitung entri PUBLIC; stats pribadi via RLS client-side; diuji S01, P06 |
| Default privileges Supabase terlalu luas | REVOKE ALL → grant eksplisit di 002/004/005; audit 31 checks di 007 |
```

(Hapus baris lama `| Buku di-poison client (insert authenticated) | ... |` dan `| Agregat profil membocorkan library privat | profile_stats hanya mengembalikan angka; ... |` yang sudah digantikan di atas.)

- [ ] **Step 5: Perbarui §8 checklist**:

```markdown
- [ ] 006: seluruh asersi PASS (dua akun + anon, 76 pemeriksaan), rollback bersih.
- [ ] 007: 31 checks PASS (grant eksplisit, stats hanya PUBLIC, notifikasi kolom read, books insert-only, fungsi definer).
```

- [ ] **Step 6: Perbarui §9 langkah 4** (marker salah + placeholder usang):

```markdown
4. Untuk 006: siapkan 2 akun uji (Authentication → Users); skrip memakai dua profil pertama otomatis (tanpa placeholder). Jalankan — pastikan muncul `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`.
```

- [ ] **Step 7: Verifikasi statis**

Run: `grep -n "ALL RLS TESTS PASSED\|<USER_A>" docs/superpowers/plans/execution-task-2-database-plan.md` → nol hasil.
Run: `grep -n "## 1A. Revisi Audit Keamanan" docs/superpowers/plans/execution-task-2-database-plan.md` → 1.

---

### Task 8: Verifikasi statis menyeluruh (tanpa SQL, tanpa commit)

**Files:**
- Verify only — semua file dalam cakupan.

- [ ] **Step 1: Konsistensi marker lintas file**

Run:
```bash
grep -rn "ALL RLS TESTS PASSED" db/ docs/superpowers/plans/execution-task-2-database-plan.md
```
Expected: nol hasil (marker lama 100% terganti).

Run:
```bash
grep -c "ALL NEGATIVE TESTS PASSED" db/scripts/006_negative_tests.sql db/SCHEMA_STATE.md
```
Expected: ≥ 1 tiap file.

Run:
```bash
grep -c "^select public._t006_expect" db/scripts/006_negative_tests.sql
```
Expected: **76**.

Run:
```bash
grep -c "union all select '\|  select '01 " db/scripts/007_verify_schema.sql
```
Expected: 31 (1 awal `select '01` + 30 union all).

- [ ] **Step 2: Cakupan perubahan**

Run: `git status --porcelain` — perubahan di sesi ini hanya: `db/` (semua di dalamnya) + `docs/superpowers/plans/execution-task-2-security-revision-plan.md` (plan ini) + `docs/superpowers/plans/execution-task-2-database-plan.md`. File pra-adas (`README.md`, `docs/PRD.md`, `docs/ROADMAP.md`, dst.) tidak berubah dari status sebelum sesi.

Run: `sha256sum docs/PRD.md` → `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e`.
Run: `file docs/ROADMAP.md` → CRLF; `tr -cd '\r' < docs/ROADMAP.md | wc -c` → 127.

- [ ] **Step 3: Skrip 001 & 003 tak berubah + ADR tak berubah**

Run: `git diff --stat -- db/scripts/001_enums.sql db/scripts/003_library.sql docs/architecture/0001-supabase-first-backend.md` (file untracked — gunakan): `md5sum db/scripts/001_enums.sql db/scripts/003_library.sql docs/architecture/0001-supabase-first-backend.md` dan bandingkan dengan catatan sesi sebelumnya bila ada; minimal: pastikan `grep -c "revoke" db/scripts/003_library.sql` tetap **≥ 2** (isinya tak tersentuh) dan 001 tanpa kata `grant`/`revoke`.

- [ ] **Step 4: Audit ringkas pola keamanan**

Run:
```bash
grep -c "revoke all on table" db/scripts/002_identity_books.sql db/scripts/004_reviews_social.sql db/scripts/005_activity_notifications.sql
```
Expected: 002 → 2, 004 → 4, 005 → 2.

Run:
```bash
grep -n "books_update_authenticated" db/scripts/*.sql
```
Expected: nol hasil.

Run:
```bash
grep -c "security definer set search_path = ''" db/scripts/002_identity_books.sql db/scripts/003_library.sql db/scripts/005_activity_notifications.sql
```
Expected: 002 → 2 (`set_updated_at`, `handle_new_user`), 003 → 1 (`library_entry_notes`), 005 → 5 (lima `trg_*`).

- [ ] **Step 5: Laporan akhir + BERHENTI**

Susun laporan: file berubah, jumlah akhir test (76) & check (31), konfirmasi nol SQL/nol commit, daftar risiko tersisa (bagian Ringkasan di atas). **Jangan lanjut ke eksekusi SQL — menunggu persetujuan pengguna.**

---

## Self-Review (skill)

1. **Spec coverage:** Temuan 1 → Task 3+4(V)+5(check via grant/trigger)+7; Temuan 2 → Task 1+4(K)+5(21,22)+7; Temuan 3 → Task 3+4(N)+5(24–26)+7; Temuan 4 → Task 2+4(S,P06)+5(23)+7; Temuan 5 → Task 1/2/3 grants + 4(AN)+5(21–31) + README Task 6. Semua butir wajib (temuan/akar, rancangan, file, daftar test, risiko, urutan) ada di Ringkasan + task. ✔
2. **Placeholder scan:** Tidak ada TBD/TODO; semua langkah berisi kode persis. ✔
3. **Konsistensi:** penomoran test final V01–V18 (18) + S01 + K01–K04 + N01–N04 + AN01–AN08 + P06–P07 = 37 baru; 39+37=76 — Step 10 Task 4 menghitung ulang sebagai jaring pengaman. Check 007: 20+11=31; Step 3 Task 5 menghitung ulang. Marker `ALL RLS TESTS PASSED` dihapus di Task 6+7 dan diverifikasi Task 8. ✔
