# BookRate — Execution Task 2: SQL Deployment & Runtime Verification (Dashboard-First) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Eksekusi Dashboard (klik/Run) dilakukan OPERATOR (pengguna) di Supabase Dashboard; agen menyiapkan instruksi, memvalidasi output yang ditempel, dan menyusun laporan. TAHAP INI SAAT DIBUAT = PLAN SAJA: nol SQL dijalankan.**

**Goal:** Menjalankan `db/scripts/001`→`007` berurutan via Supabase Dashboard → SQL Editor, memverifikasi tiap blok `-- VERIFY`, membuktikan Gate V2 (`ALL NEGATIVE TESTS PASSED: 76 pemeriksaan` + `VERIFY SCHEMA: ALL 31 CHECKS PASSED`), mengumpulkan bukti, lalu (hanya bila gate lolos) memperbarui `db/SCHEMA_STATE.md`.

**Architecture:** Dashboard-First tanpa CLI/Docker/Edge Functions/custom API. Operator menyalin seluruh isi satu skrip → SQL Editor → Run; agent memeriksa output terhadap expected eksak di bawah. Skrip 001–005 idempoten (aman diulang); 006 satu transaksi `begin;…rollback;` (nol residu); 007 read-only. Pemulihan = berhenti → diagnosa → re-run skrip yang sama (bukan patch Table Editor — anti-drift).

**Tech Stack:** Supabase Dashboard (SQL Editor, Authentication → Users, Settings → Database), PostgreSQL via SQL Editor sebagai role `postgres`. Tanpa Supabase CLI, Docker, local Supabase, Edge Functions, custom API.

**Spec:** `docs/superpowers/plans/execution-task-2-database-plan.md` (keputusan 1–8, §1A, §8–§9) · `execution-task-2-security-revision-plan.md` (kode lolos review) · `db/README.md` (urutan + aturan kerja) · hasil review statis: `review-task-2-security-revision-plan.md` = **PASS 8/8**.

## Global Constraints

- **TAHAP INI = PLAN.** DILARANG menjalankan SQL apa pun, membuka/mengubah hosted Supabase, mengubah file SQL implementasi, mengubah `docs/PRD.md` (hash acuan `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e`), `docs/ROADMAP.md` (CRLF, 127 CR), ADR `0001`, `db/AUDIT_REVIEW_BUNDLE.md`.
- DILARANG mengubah `db/SCHEMA_STATE.md` menjadi PASSED saat menyusun rencana ini; penandaan hanya pada eksekusi nyata **setelah** Gate V2 lolos (Task 10).
- DILARANG install dependency/CLI; commit/push; memulai Execution Task 3.
- Urutan wajib `001 → 002 → 003 → 004 → 005 → (buat 2 akun uji) → 006 → 007`. **Berhenti pada error pertama** (README aturan 4); jangan lanjut nomor berikutnya.
- Perubahan skema HANYA lewat skrip di repo — dilarang patch Table Editor UI (anti-drift). `pg_trgm` ditunda (keputusan 2026-11-08) — jangan ditambahkan.
- Marker keberhasilan (teks persis): `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan` dan `VERIFY SCHEMA: ALL 31 CHECKS PASSED`.
- RLS verification = SQL Editor + 2 akun uji (keputusan produk 8) — tanpa `service_role key`.

---

## Peta File & Artefak

| Aksi | File / Lokasi |
|---|---|
| **Dibuat oleh plan ini** | `docs/superpowers/plans/execution-task-2-deployment-verification-plan.md` (dokumen ini) |
| **Dieksekusi (Run di Dashboard, TIDAK diubah)** | `db/scripts/001_enums.sql` … `db/scripts/007_verify_schema.sql` (7 file) |
| **Dimodifikasi HANYA di Task 10 (setelah Gate V2 lolos)** | `db/SCHEMA_STATE.md` |
| **Wajib TIDAK berubah** | `docs/PRD.md`, `docs/ROADMAP.md`, `docs/architecture/0001-supabase-first-backend.md`, `db/AUDIT_REVIEW_BUNDLE.md`, seluruh `db/scripts/*` |
| **Di luar cakupan** | `apps/`, `packages/`, `scripts/`, Execution Task 3 |

---

## Analisis Transaksional & Idempotensi (WAJIB dibaca sebelum eksekusi)

| Skrip | Sifat transaksional | Idempotensi (di dalam kode) | Aman re-run? | Catatan kritis |
|---|---|---|---|---|
| `001` | Tanpa `BEGIN` eksplisit → batch implisit; error di tengah = seluruh batch batal | 4× guard `if not exists` pada `create type` | **YA** | Re-run = no-op bila enum sudah ada |
| `002` | Batch implisit | `create table if not exists`; `create or replace function` ×2 (`set_updated_at`, `handle_new_user`); DO-guard `if not exists` untuk 3 trigger + 4 policy; `revoke`/`grant` idempoten | **YA** | `if not exists` TIDAK memperbaiki drift kolom tabel lama → deteksi lewat VERIFY |
| `003` | Batch implisit | `create table if not exists`; DO-guard trigger + 4 policy; `create or replace function library_entry_notes`; `revoke`/`grant` | **YA** | Sama seperti 002 |
| `004` | Batch implisit | `create table if not exists`; `create … index if not exists` ×7; `create or replace view` ×2; DO-guard 12 policy; `revoke`/`grant` | **YA** | View di-replace aman |
| `005` | Batch implisit | `create table if not exists`; index if not exists; `create or replace function` ×5; DO-guard 3 policy; `revoke`/`grant` | **YA** | `trg_library_activity` memakai **drop-lalu-create** — re-run MEMASTIKAN event `INSERT OR UPDATE OR DELETE` terpasang (bukan `if not exists` yang membekukan event lama) |
| `006` | **EKSPLISIT `begin;` … `rollback;`, TANPA `commit`** — satu transaksi utuh | `drop table if exists` harness sebelum `create`; `create or replace` helper; seluruh fixture/test DML di dalam transaksi | **YA — dirancang nol residu** | Gagal keras (mis. `PRASYARAT GAGAL`) → abort → rollback implisit. Aserensi gagal → dicatat di `_t006_results`, skrip tetap sampai `rollback;`. **Tidak ada residu untuk dibersihkan manual** |
| `007` | Hanya `SELECT` (read-only) | Trivial | **YA** | Tidak mengubah data; boleh diulang kapan pun |

**Implikasi pemulihan:** karena 001–005 idempoten, prosedur standar = **perbaiki penyebab → re-run SKRIP YANG SAMA dari baris pertama** (bukan menempel sisa blok). Jangan menonaktifkan guard `if not exists` atau menambahkan objek di luar skrip.

**Syarat teknis 006:** seluruh isi file dieksekusi dalam SATU Run agar `set local role`/`set_config` berada di dalam transaksi. Gejala bila SQL Editor memecah pernyataan: peringatan `SET LOCAL can only be used in transaction blocks` ATAU hasil RLS aneh (mis. `B01` lolos membaca notes) → **006 TIDAK SAH** → jangan tandai lolos → eskalasi Risiko R-4.

**Asumsi transaksi SQL Editor (R-07 — WAJIB dibaca, bukan klaim):**
- Rencana ini **TIDAK mengklaim** bahwa SQL Editor Supabase selalu mengirim seluruh file sebagai satu batch/one session. Asumsi yang diadopsi: SQL Editor mengirim teks yang di-paste ke Postgres, dan bila ia mengirimnya sebagai satu pesan (multi-statement), `begin;…rollback;` berjalan dalam satu transaksi utuh. Bila ia memecah pernyataan ke sesi/koneksi terpisah, transaksi 006 bisa tidak utuh.
- **Tidak ada bukti statis** yang dapat membuktikan perilaku SQL Editor sesungguhnya — lihat R-8: bukti runtime (`null|null` pasca-rollback + 0 gagal + marker) adalah satu-satunya jalan verifikasi, dan bila tidak terpenuhi → 006 dianggap **tidak sah** (R-4).
- **Ketentuan wajib sebelum melanjutkan:** bila perilaku transaksi tidak dapat dipastikan (mis. peringatan `SET LOCAL`, `B01` aneh, atau residu tidak `null`), operator **harus menghenti** dan mengikuti Prosedur Pemulihan Tingkat 3 (di bawah) — **jangan mengabaikan dan jangan menandai Gate V2**. Tindakan yang diizinkan: (a) ulangi 006 dalam satu Run (jika editor versi baru mengirim satu batch), (b) ganti ke versi editor/kesempatan lain yang dikuatkan mengirim satu sesi, (c) **laporkan ke pengguna** untuk keputusan eksplisit. Jangan mengedit skrip 006.
- Untuk 001–005 (tanpa `BEGIN` eksplisit): bila SQL Editor mengirim pernyataan satu-satu dengan autocommit, kegagalan tengah **bisa meninggalkan objek parsial** (mis. tabel dibuat tapi indeks gagal). Mitigasi: re-run idempoten + VERIFY wajib setiap skrip (lihat R-07/OBSERVATION). Jangan mengasumsikan "seluruh batch batal" tanpa verifikasi.

---

## Aturan Umum Eksekusi Dashboard (berlaku di Task 2–8)

1. Buka `https://supabase.com/dashboard` → pilih project BookRate (catat **Project Ref** di Project Settings → General).
2. Sidebar kiri → **SQL Editor** → **New query** (ikon +).
3. Hapus isi bawaan; salin **SELURUH** isi file skrip dari repo (Ctrl+A → Ctrl+V).
4. Klik **Run** (Ctrl/Cmd+Enter). Notifikasi **`Success`** (disertai waktu) = tanpa error; error merah = FAIL (berhenti).
5. Panel **Results** menampilkan result set. Bila hanya satu grid terjangkau: buat query baru untuk tiap query blok `-- VERIFY`, Run **satu per satu** (VERIFY read-only — mengulang aman).
6. **Segera salin output** ke laporan percakapan (Results menimpa pada Run berikutnya). File bukti terpisah HANYA bila diminta pengguna.

---

### Task 1: Prasyarat & Pemeriksaan Project Supabase

**Tujuan:** Project siap, kosong dari skema lama, SQL Editor sebagai `postgres`, keputusan backup tercatat.
**Prasyarat:** Akses owner Dashboard; project Supabase sudah dibuat.
**Instruksi Dashboard:** langkah checkbox di bawah. **Hasil diharapkan:** project kosong siap menerima 001.
**Kriteria:** semua Step PASS. **Jika gagal:** tindakan per langkah.

- [ ] **Step 1: Catat identitas project + role SQL Editor**

  Dashboard → project → **Project Settings → General** → catat **Project Ref** → **SQL Editor → New query** → Run:
  ```sql
  select current_user as role, current_database() as db;
  ```
  Expected: `postgres | postgres`.
  PASS: baris `postgres | postgres`. FAIL: **JANGAN lanjut** — laporkan ke pengguna; eksekusi hanya sah sebagai `postgres`.

- [ ] **Step 2: Pastikan skema public kosong (project baru)**

  Run (query baru):
  ```sql
  select c.relname
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
  order by 1;
  ```
  Expected: **Data (0)** — nol baris.
  PASS: 0 baris. FAIL (ada tabel): **BERHENTI**, jangan jalankan 001; laporkan daftar tabel ke pengguna untuk keputusan: (a) reset project (Settings → Database → **Reset database** — destruktif, HANYA atas izin eksplisit pengguna) ATAU (b) backup dulu (Settings → Database → **Backups**) lalu lanjut dengan pemahaman risiko drift.

- [ ] **Step 3: Verifikasi toolchain**

  Run: `select version();`
  Expected: string berisi `PostgreSQL ` + angka 14/15/16.x.
  PASS: versi terbaca. FAIL: laporkan; jangan lanjut.

- [ ] **Step 4: Catat keputusan backup**

  Buka **Project Settings → Database → Backups**: catat status auto-backup & slot berikutnya. Project kosong (Step 2 PASS) → catat "project kosong; backup tidak diperlukan".
  PASS: catatan ada di laporan. FAIL (Step 2 gagal): sudah tertangani Step 2.

- [ ] **Step 5: Tunda pembuatan akun uji ke SETELAH 002**

  Alasan: trigger `on_auth_user_created` (pembuat baris `profiles`) baru dibuat di `002_identity_books.sql:72` — akun sebelum 002 tidak punya profil → 006 gagal `PRASYARAT GAGAL`.
  Expected: nol akun uji dibuat sekarang; pembuatan = Task 7 Step 1.
  PASS: jadwal tercatat. FAIL (akun terlanjur dibuat sebelum 002): catat — pemulihan di Task 7 Step 1b.

**Acceptance criteria Task 1:** role `postgres`; 0 tabel; versi terbaca; keputusan backup tercatat; akun uji belum dibuat.

---

### Task 2: Eksekusi `001_enums.sql`

**Tujuan:** 4 enum (`reading_status`, `activity_type`, `notification_type`, `library_visibility`) + verifikasi.
**Prasyarat:** Task 1 PASS. **File:** `db/scripts/001_enums.sql` (jangan diubah; 38 baris total — header 5 baris + DO-block `if not exists` untuk 4 enum + blok `-- VERIFY`).
**Instruksi Dashboard:** Aturan Umum 1–6 dengan file `001_enums.sql`.
**Hasil diharapkan:** `Success`; VERIFY = 4 baris enum.
**Kriteria PASS/FAIL:** Step 2. **Jika gagal:** berhenti → re-run 001 (idempoten).

- [ ] **Step 1: Run seluruh file 001**

  Expected: `Success`. FAIL: catat pesan error + baris; JANGAN lanjut ke 002; perbaiki penyebab; re-run 001.

- [ ] **Step 2: Periksa blok VERIFY 001**

  Run terpisah:
  ```sql
  select t.typname
  from pg_type t
  join pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'public' and t.typtype = 'e'
  order by t.typname;
  ```
  Expected — tepat **4 baris** urut: `activity_type`, `library_visibility`, `notification_type`, `reading_status`.
  PASS: persis. FAIL (≠4 / nama beda): berhenti; diagnosa; re-run 001.

- [ ] **Step 3: Simpan bukti Task 2**

  Salin (a) `Success`+waktu → E-001a; (b) 4 baris → E-001b.
  PASS: keduanya terkumpul.

**Acceptance criteria Task 2:** Success + 4 baris + bukti E-001a/b.

---

### Task 3: Eksekusi `002_identity_books.sql`

**Tujuan:** `profiles` + trigger signup + `books` (insert-only klien) + RLS + grant eksplisit + 4 policy.
**Prasyarat:** Task 2 PASS. **File:** `db/scripts/002_identity_books.sql`.
**Instruksi Dashboard:** Aturan Umum 1–6. **Hasil diharapkan:** `Success` + 3 VERIFY.
**Kriteria:** Step 2–4. **Jika gagal:** berhenti; re-run 002; dilarang patch Table Editor.

- [ ] **Step 1: Run seluruh file 002**

  Expected: `Success`. FAIL: catat error; JANGAN lanjut; perbaiki penyebab (mis. bukan project Supabase); re-run 002.

- [ ] **Step 2: VERIFY 002a — RLS aktif**

  ```sql
  select 'profiles' as tbl, relrowsecurity from pg_class where oid = 'public.profiles'::regclass
  union all
  select 'books', relrowsecurity from pg_class where oid = 'public.books'::regclass;
  ```
  Expected: 2 baris `profiles|true`, `books|true`. FAIL: re-run 002.

- [ ] **Step 3: VERIFY 002b — tepat 4 policy**

  ```sql
  select tablename, policyname, cmd from pg_policies
  where schemaname = 'public' and tablename in ('profiles', 'books')
  order by tablename, policyname;
  ```
  Expected — tepat **4 baris**:
  | tablename | policyname | cmd |
  |---|---|---|
  | books | books_insert_authenticated | INSERT |
  | books | books_select_public | SELECT |
  | profiles | profiles_select_public | SELECT |
  | profiles | profiles_update_own | UPDATE |

  PASS: 4 baris persis (tanpa UPDATE/DELETE books; tanpa INSERT/DELETE profiles). FAIL: re-run 002; persist = drift → Prosedur Pemulihan tingkat 2.

- [ ] **Step 4: VERIFY 002c — matriks grant (6 baris)**

  ```sql
  select grantee, privilege_type, table_name
  from information_schema.table_privileges
  where table_schema = 'public' and table_name in ('profiles', 'books')
    and grantee in ('anon', 'authenticated')
  order by table_name, grantee, privilege_type;
  ```
  Expected — tepat **6 baris**: books/anon/SELECT; books/authenticated/INSERT; books/authenticated/SELECT; profiles/anon/SELECT; profiles/authenticated/SELECT; profiles/authenticated/UPDATE.
  PASS: 6 baris persis. FAIL: re-run 002 (jangan menulis SQL baru di luar skrip).

- [ ] **Step 5: Simpan bukti Task 3**

  E-002a (`Success`+waktu), E-002b/c/d (3 output VERIFY). PASS: terkumpul.

**Acceptance criteria Task 3:** Success; RLS 2×true; policy 4; grant 6; bukti E-002a–d.

---

### Task 4: Eksekusi `003_library.sql`

**Tujuan:** `library_entries` + hak kolom `notes` (tanpa SELECT klien) + fungsi `library_entry_notes` + 4 policy.
**Prasyarat:** Task 3 PASS. **File:** `db/scripts/003_library.sql`.
**Instruksi Dashboard:** Aturan Umum 1–6. **Hasil diharapkan:** `Success` + 3 VERIFY.
**Kriteria:** Step 2–4. **Jika gagal:** berhenti; re-run 003.

- [ ] **Step 1: Run seluruh file 003**

  Expected: `Success`. FAIL: pola Task 2 Step 1.

- [ ] **Step 2: VERIFY 003a — RLS + policy**

  ```sql
  select relrowsecurity from pg_class where oid = 'public.library_entries'::regclass;
  ```
  Expected: 1 baris `true`.
  ```sql
  select policyname, cmd from pg_policies
  where schemaname = 'public' and tablename = 'library_entries' order by policyname;
  ```
  Expected — tepat **4 baris**: `library_delete_own|DELETE`, `library_insert_own|INSERT`, `library_select_own_or_public|SELECT`, `library_update_own|UPDATE`.
  PASS: keduanya sesuai. FAIL: re-run 003.

- [ ] **Step 3: VERIFY 003b — `notes` tanpa hak SELECT klien**

  ```sql
  select grantee, string_agg(column_name, ', ' order by column_name) as selected_columns
  from information_schema.column_privileges
  where table_schema = 'public' and table_name = 'library_entries'
    and privilege_type = 'SELECT' and grantee in ('anon', 'authenticated')
  group by grantee;
  ```
  Expected: 2 baris (anon, authenticated); daftar kolom keduanya **identik dan TIDAK memuat `notes`** — 10 kolom: `book_id, created_at, finish_date, id, progress, start_date, status, updated_at, user_id, visibility`.
  PASS: `notes` absen dari kedua grantee. FAIL (ada `notes`): JANGAN lanjut; re-run 003; persist = drift grant → Prosedur Pemulihan tingkat 2.

- [ ] **Step 4: VERIFY 003c — fungsi definer**

  ```sql
  select p.proname, p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner) as owner
  from pg_proc p where p.proname = 'library_entry_notes';
  ```
  Expected: 1 baris — `library_entry_notes | true | {search_path=} | postgres`.
  PASS: persis. FAIL: re-run 003.

- [ ] **Step 5: Simpan bukti Task 4**

  E-003a (`Success`+waktu) + E-003b/c/d. PASS: terkumpul.

**Acceptance criteria Task 4:** Success; RLS true; 4 policy; `notes` absen; fungsi definer benar; bukti E-003a–d.

### Task 5: Eksekusi `004_reviews_social.sql`

**Tujuan:** `reviews` (soft delete) + `likes`/`comments`/`follows` + view `book_rating_summary` (security_invoker) & `profile_stats` (hanya entri PUBLIC) + RLS/grant.
**Prasyarat:** Task 4 PASS. **File:** `db/scripts/004_reviews_social.sql`.
**Instruksi Dashboard:** Aturan Umum 1–6. **Hasil diharapkan:** `Success` + VERIFY.
**Kriteria:** Step 2–5. **Jika gagal:** berhenti; re-run 004 (view `create or replace` aman).

- [ ] **Step 1: Run seluruh file 004**

  Expected: `Success`. FAIL: pola Task 2 Step 1.

- [ ] **Step 2: VERIFY 004a — RLS 4 tabel**

  ```sql
  select relrowsecurity from pg_class
  where oid in ('public.reviews'::regclass, 'public.likes'::regclass,
                'public.comments'::regclass, 'public.follows'::regclass);
  ```
  Expected: **4 baris**, semua `true`. FAIL: re-run 004.

- [ ] **Step 3: VERIFY 004b — 12 policy**

  ```sql
  select tablename, policyname, cmd from pg_policies
  where schemaname = 'public' and tablename in ('reviews','likes','comments','follows')
  order by tablename, policyname;
  ```
  Expected — tepat **12 baris** (urut per tabel + abjad):
  | tablename | policyname | cmd |
  |---|---|---|
  | comments | comments_delete_own | DELETE |
  | comments | comments_insert_own_active_review | INSERT |
  | comments | comments_select_active_review | SELECT |
  | follows | follows_delete_own | DELETE |
  | follows | follows_insert_own | INSERT |
  | follows | follows_select_public | SELECT |
  | likes | likes_delete_own | DELETE |
  | likes | likes_insert_own_active_review | INSERT |
  | likes | likes_select_active_review | SELECT |
  | reviews | reviews_insert_own | INSERT |
  | reviews | reviews_select_active | SELECT |
  | reviews | reviews_update_own | UPDATE |

  PASS: 12 baris persis (tanpa DELETE reviews; tanpa UPDATE comments/likes/follows). FAIL: re-run 004.

- [ ] **Step 4: VERIFY 004c — 2 view + indeks reviews**

  ```sql
  select viewname from pg_views where schemaname = 'public'
    and viewname in ('book_rating_summary', 'profile_stats') order by viewname;
  ```
  Expected: 2 baris `book_rating_summary`, `profile_stats`.
  ```sql
  select indexname from pg_indexes where schemaname = 'public' and tablename = 'reviews'
    order by indexname;
  ```
  Expected minimal 4: `reviews_book_active_idx`, `reviews_one_active_per_book`, `reviews_pkey`, `reviews_user_id_idx`.
  PASS: keduanya sesuai. FAIL: re-run 004.

- [ ] **Step 5: VERIFY 004d — filter PUBLIC di profile_stats + invoker book_rating_summary**

  ```sql
  select pg_get_viewdef('public.profile_stats'::regclass, true) like '%visibility%' as ada_visibility,
         pg_get_viewdef('public.profile_stats'::regclass, true) like '%PUBLIC%' as ada_public,
         (select c.reloptions @> array['security_invoker=true'] from pg_class c
          where c.oid = 'public.book_rating_summary'::regclass) as invoker_book_rating;
  ```
  Expected: `ada_visibility=true`, `ada_public=true`, `invoker_book_rating=true`.
  (`profile_stats` memang TANPA security_invoker — keputusan 5 hanya untuk `book_rating_summary`.)
  PASS: 3×true. FAIL: re-run 004.

- [ ] **Step 6: Simpan bukti Task 5**

  E-004a (`Success`+waktu) + E-004b–e (4 output VERIFY). PASS: terkumpul.

**Acceptance criteria Task 5:** Success; 4×true; 12 policy; 2 view; indeks; filter PUBLIC + invoker; bukti E-004a–e.

---

### Task 6: Eksekusi `005_activity_notifications.sql`

**Tujuan:** `activities`/`notifications` + 5 trigger SECURITY DEFINER (invarian aktivitas hanya-entri-PUBLIC) + grant (activities SELECT-only; notif UPDATE hanya kolom `read`; anon nol grant notif).
**Prasyarat:** Task 5 PASS. **File:** `db/scripts/005_activity_notifications.sql`.
**Instruksi Dashboard:** Aturan Umum 1–6. **Hasil diharapkan:** `Success` + VERIFY.
**Kriteria:** Step 2–5. **Jika gagal:** berhenti; re-run 005 (drop-create `trg_library_activity` justru memperbarui event dengan benar).

- [ ] **Step 1: Run seluruh file 005**

  Expected: `Success`. FAIL: pola Task 2 Step 1.

- [ ] **Step 2: VERIFY 005a — RLS + policy**

  ```sql
  select relrowsecurity from pg_class
  where oid in ('public.activities'::regclass, 'public.notifications'::regclass);
  ```
  Expected: 2 baris, `true` semua.
  ```sql
  select tablename, policyname, cmd from pg_policies
  where schemaname = 'public' and tablename in ('activities', 'notifications')
  order by tablename, policyname;
  ```
  Expected — tepat **3 baris**: `activities|activities_select_public|SELECT`; `notifications|notifications_select_own|SELECT`; `notifications|notifications_update_own|UPDATE`.
  PASS: sesuai. FAIL: re-run 005.

- [ ] **Step 3: VERIFY 005b — 7 trigger (2 updated_at + 5 fungsional)**

  ```sql
  select tgname, tgtype from pg_trigger
  where tgrelid in ('public.reviews'::regclass, 'public.library_entries'::regclass,
                    'public.likes'::regclass, 'public.comments'::regclass,
                    'public.follows'::regclass)
    and not tgisinternal
  order by tgname;
  ```
  Expected — tepat **7 baris** urut abjad: `library_entries_set_updated_at`, `reviews_set_updated_at`, `trg_comments_notification`, `trg_follows_notification`, `trg_library_activity`, `trg_likes_notification`, `trg_reviews_activity`.
  PASS: 7 baris persis. FAIL (kurang/lebih): re-run 005.

- [ ] **Step 4: VERIFY 005c — grant notifications (kolom read saja, anon nol)**

  ```sql
  select grantee, string_agg(column_name, ', ' order by column_name) as cols
  from information_schema.column_privileges
  where table_schema = 'public' and table_name = 'notifications'
  group by grantee, privilege_type
  order by grantee, privilege_type;
  ```
  Expected: `anon` TIDAK muncul sama sekali; `authenticated|SELECT` = 8 kolom (`actor_id, comment_id, created_at, id, notification_type, read, review_id, user_id`); `authenticated|UPDATE` = `read` saja (1 kolom).
  PASS: anon absen; UPDATE=`read`. FAIL: re-run 005.

- [ ] **Step 5: Simpan bukti Task 6**

  E-005a (`Success`+waktu) + E-005b/c/d (3 output VERIFY). PASS: terkumpul.

**Acceptance criteria Task 6:** Success; RLS 2×true; 3 policy; 7 trigger; grant notif benar; bukti E-005a–d.

---

### Task 7: Prasyarat akun uji + Eksekusi `006_negative_tests.sql` (76 pemeriksaan)

**Tujuan:** Membuktikan seluruh garis keamanan runtime (RLS, hak kolom, trigger invarian, insert-only books, statistik PUBLIC) melalui 76 test dalam satu transaksi yang di-rollback — keputusan produk 8 (SQL Editor + 2 akun uji, tanpa service_role).
**Prasyarat:** Task 6 PASS (trigger `on_auth_user_created` sudah ada). **File:** `db/scripts/006_negative_tests.sql`.
**Instruksi Dashboard:** Aturan Umum 1–6 + **wajib SATU Run untuk seluruh file** (lihat syarat teknis pada Analisis Transaksional).
**Hasil diharapkan:** daftar gagal = 0 baris; `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`.
**Kriteria:** Step 5–6. **Jika gagal:** berhenti; jangan jalankan 007 sebagai pengganti; diagnosa (Task 8 Prosedur).

- [ ] **Step 1: Buat 2 akun uji (SETELAH 002 — lihat Task 1 Step 5)**

  Dashboard → **Authentication → Users → Add user** (atau **Create new user**):
  1. User 1: isi **Email** `bookrate.test.a@example.com`, **Password** kuat (min 8 karakter — catat kredensial di tempat aman), **Auto Confirm User** = ON (atau centang konfirmasi bila tersedia) → **Create user**.
  2. Ulangi User 2: `bookrate.test.b@example.com` (password berbeda, dicatat).
  Expected: 2 baris di tabel Users (status `Confirmed` bila auto-confirm).
  PASS: 2 user terdaftar. FAIL (error pembuatan): catat pesan; perbaiki (mis. email duplikat → ganti email); ulangi.

- [ ] **Step 1b: Pemulihan bila akun terlanjur dibuat SEBELUM 002**

  Jalankan (query baru, sebagai postgres):
  ```sql
  select tgname from pg_trigger
  where tgname = 'on_auth_user_created' and not tgisinternal;
  ```
  Expected: 1 baris (trigger ada setelah 002 sukses).
  Jika 1 baris tapi profiles < 2 → jalankan (mengikuti logika `handle_new_user`):
  ```sql
  select count(*) from public.profiles;
  ```
  Jika < 2: **berhenti dan laporkan ke pengguna** — pilihan:
  (a) **Hapus 2 user via Authentication → Users** (ikon trash, konfirmasi) lalu ulangi Step 1 di atas. Ini adalah pilihan utama — mengembalikan ke jalur trigger `handle_new_user` yang punya fallback username unik (bukan SQL manual).
  (b) **Buat profil manual via SQL Editor sebagai postgres** — HANYA bila (a) tidak memungkinkan (mis. user terikat ke data lain). SQL lengkap, mengikuti pola `handle_new_user` (002:40) agar username unik dan tidak duplikat:
  ```sql
  insert into public.profiles (id, username, display_name)
  select
    u.id,
    coalesce(
      nullif(u.raw_user_meta_data ->> 'username', ''),
      'user_' || substr(u.id::text, 1, 8)
    ),
    coalesce(
      nullif(u.raw_user_meta_data ->> 'display_name', ''),
      coalesce(nullif(u.raw_user_meta_data ->> 'username', ''), 'user_' || substr(u.id::text, 1, 8))
    )
  from auth.users u
  where u.email in ('bookrate.test.a@example.com', 'bookrate.test.b@example.com')
  on conflict (id) do nothing;
  ```
  Expected: 2 baris ter-insert (atau 0 bila sudah ada — `on conflict do nothing` mencegah duplikat).
  Catatan: `on conflict (id) do nothing` mencegah duplikat profil; SQL ini berjalan sebagai `postgres` (bypass RLS), jadi TIDAK melemahkan kebijakan RLS — RLS tetap berlaku untuk klien/auth. Jangan lanjut ke 006 dengan profiles < 2.

- [ ] **Step 2: Verifikasi prasyarat 006 (profil A & B = akun uji yang baru dibuat)**

  ```sql
  select count(*) as n_profil from public.profiles;
  ```
  Expected: `n_profil = 2` — **tepat 2 profil, tidak lebih**. (Jika > 2, profil tambahan mengganggu identitas A/B; lihat Step 2b.)
  ```sql
  select row_number() over (order by join_date, id) as urutan, id, username
  from public.profiles order by join_date, id limit 2;
  ```
  Expected: tepat 2 baris (urutan 1 = **A**, urutan 2 = **B**) — inilah identitas yang dipakai skrip (`order by join_date, id limit 1` / `offset 1 limit 1`).
  ```sql
  select id, username
  from auth.users
  where email in ('bookrate.test.a@example.com', 'bookrate.test.b@example.com')
  order by email;
  ```
  Expected: 2 baris — profil A & B (urutan 1 & 2 dari query sebelumnya) **harus sama dengan 2 user yang baru dibuat di Step 1** (cocokkan `id` dan `username`). Jika username bukan `user_<id>` (mis. dari metadata) dan operator ingat nilainya, bandingkan dengan yang diingat.
  PASS: `n_profil = 2` **dan** 2 user yang terbaca di `auth.users` = profil A & B. FAIL (profiles < 2): kembali Step 1/1b; JANGAN jalankan 006. FAIL (profiles > 2): **hentikan proses** — lihat Step 2b; JANGAN jalankan 006.

- [ ] **Step 2b: Pemulihan bila profil > 2 (A/B tidak pasti) — STOP, jangan jalankan 006**

  Situasi: ada profil tambahan (mis. akun operator atau percobaan sebelumnya) → `order by join_date, id` bisa mengambil profil yang BUKAN akun uji. **Proses dihentikan di sini. Jangan jalankan `006_negative_tests.sql`.**

  1. **Hentikan proses.** Kembali ke Task 1/Task 7 Step 1 — jangan melanjutkan 006, jangan mengabaikan peringatan ini, jangan menandai SCHEMA_STATE.
  2. **Laporkan** ke pengguna: jumlah profil (`n_profil`) + daftar tiap profil (`id`, `username`, `join_date`) dari query di bawah, beserta 2 akun uji yang diinginkan (`bookrate.test.a@example.com`, `bookrate.test.b@example.com`).
  3. **Prioritaskan project Supabase pengujian yang benar-benar bersih.** Jika tersedia project uji terpisah (kosong, tanpa data operator), gunakan project itu untuk 006 — bukan project utama BookRate yang sudah berisi akun operator. Keputusan ada di pengguna.
  4. **Penghapusan akun melalui Authentication → Users BUKAN tindakan otomatis.** Operator harus memilihnya secara manual (ikon trash → konfirmasi). Jangan otomatis hapus tanpa langkah ini.
  5. **Jika penghapusan akun diperlukan, HENTIKAN dan minta persetujuan eksplisit pengguna terlebih dahulu** — penghapusan mengikuti `on delete cascade` ke profil dan data terkait (`library_entries.user_id`, `reviews.user_id`, `likes.user_id`, `comments.user_id`, `follows.*`, `activities.actor_id`, `notifications.user_id`, dst.), jadi **dapat menghapus data terkait**. Tanpa persetujuan eksplisit, jangan lakukan penghapusan.
  6. **Pastikan A & B teridentifikasi secara tepat** sebelum Task 7 dilanjutkan: setelah keputusan ( hapus / pindah project / profil yang ada ), ulangi Step 2 — `n_profil = 2` **dan** 2 user di `auth.users` (email `bookrate.test.a/b@example.com`) = profil A & B (cocokkan `id`/`username`). Hanya bila keduanya cocok, lanjut ke Step 3 (catat tanggal) lalu Step 4 (Run 006).

  Jalankan (query baru, sebagai postgres) untuk melaporkan:
  ```sql
  select id, username, join_date
  from public.profiles order by join_date, id;
  ```
  Expected: daftar semua profil + tanggal join (ini adalah data laporan ke pengguna, bukan keputusan otomatis).

- [ ] **Step 3: Catat tanggal eksekusi untuk bukti**

  Catat tanggal hari ini (format `YYYY-MM-DD`) → akan dipakai kolom `applied`/`verified` Task 10 (E-006T).
  PASS: tanggal tercatat.

- [ ] **Step 4: Run seluruh file 006 DALAM SATU Run**

  Salin **seluruh** `006_negative_tests.sql` → SQL Editor → **Run tunggal** (jangan dipecah, jangan dijalankan per blok).
  Expected: `Success` pada baris terakhir (setelah `rollback;`) — tanpa error merah.
  FAIL — error `PRASYARAT GAGAL: butuh >= 2 profil...`: transaksi abort (nol residu) → kembali Step 1/2 lalu ulangi Step 4. (Catatan: `PRASYARAT GAGAL` di 006:99 terpicu jika `count(*) < 2`; jika profil > 2, kegagalan ini TIDAK akan muncul — profil > 2 terdeteksi di Step 2b, bukan di 006.)
  FAIL — error `SET LOCAL can only be used in transaction blocks`: SQL Editor memecah pernyataan → **006 TIDAK SAH** → jangan lanjut → eskalasi Risiko R-4 ke pengguna.
  FAIL — error syntax/timeout: catat pesan + baris; transaksi batal otomatis (nol residu); ulangi Step 4 setelah penyebab diperbaiki (harness `drop table if exists` membuat re-run aman).

- [ ] **Step 5: Periksa daftar GAGAL = 0 baris**

  Pada hasil Run yang sama, cari result set query:
  ```sql
  select name, ok, detail from public._t006_results where not ok order by name;
  ```
  Expected: **Data (0)** — nol baris (panel menampilkan header kosong).
  PASS: 0 baris gagal. FAIL (ada baris): salin SELURUH daftar (name/ok/detail) → **BERHENTI** (jangan jalankan 007 sebagai pengganti) → diagnosa per Task 8.

- [ ] **Step 6: Periksa marker RINGKASAN (teks persis)**

  Result set terakhir Run yang sama:
  ```sql
  select case when count(*) = count(*) filter (where ok)
        then 'ALL NEGATIVE TESTS PASSED: ' || count(*) || ' pemeriksaan'
        else 'TESTS FAILED: ' || count(*) filter (where not ok) || ' gagal dari '
             || count(*) || ' pemeriksaan' end as hasil
  from public._t006_results;
  ```
  Expected — SATU baris, kolom `hasil` persis:
  `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`
  PASS: teks identik (termasuk angka `76`). FAIL (`TESTS FAILED: …`): ambil daftar dari Step 5 → BERHENTI → Task 8. Angka ≠ 76 padahal semua ok: hitungan unit test menyimpang → BERHENTI → laporkan (kemungkinan file teredit — jangan edit skrip; laporkan ke pengguna).

- [ ] **Step 7: Verifikasi nol residu pasca-rollback**

  ```sql
  select to_regclass('public._t006_results') as hasil_table,
         to_regclass('public._t006_ids') as ids_table;
  ```
  Expected: `null | null` (kedua tabel harness sudah terhapus rollback).
  PASS: keduanya null. FAIL (ada tabel): rollback tidak terjadi (Run terpecah!) → 006 TIDAK SAH → eskalasi R-4; jangan tandai lolos.

- [ ] **Step 8: Simpan bukti Task 7**

  E-006a (`Success`+waktu); E-006b (daftar gagal 0 baris); E-006c (baris marker `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`); E-006d (null|null residu); E-006e (2 baris A/B dari Step 2); E-006T (tanggal).
  PASS: seluruh bukti terkumpul.

**Acceptance criteria Task 7:** 2 akun uji ada; ≥2 profil; Success satu Run; gagal=0; marker persis `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`; residu null|null; bukti E-006a–e/T.

---

### Task 8: Eksekusi `007_verify_schema.sql` (31 checks)

**Tujuan:** Audit skema final — 31 check grant/policy/definer/stats semuanya PASS + marker akhir.
**Prasyarat:** Task 7 PASS. **File:** `db/scripts/007_verify_schema.sql`.
**Instruksi Dashboard:** Aturan Umum 1–6 (read-only, aman diulang). **Hasil diharapkan:** 31 baris PASS + ringkasan.
**Kriteria:** Step 2–3. **Jika gagal:** BERHENTI; identifikasi check → perbaiki via skrip terkait → ulangi dari skrip terkait (bukan patch manual) → ulangi 006 lalu 007.

- [ ] **Step 1: Run seluruh file 007**

  Expected: `Success`. FAIL: catat error; berhenti; re-run 007.

- [ ] **Step 2: Periksa 31 baris = PASS semua**

  Result set utama: kolom `pemeriksaan` (01…31) + kolom `hasil`.
  Expected: **tepat 31 baris** `01`–`31`, seluruh `hasil = PASS`; **nol baris `FAIL`**; ditambah 1 baris `=== RINGKASAN ===` (lihat Step 3).
  Jika hanya satu grid terjangkau: salin query `with checks as (...)` dari file ke query baru → Run → periksa grid.
  PASS: 31/31 PASS. FAIL: salin **baris bernomor yang FAIL** + teksnya → BERHENTI → tabel diagnostik berikut.

- [ ] **Step 3: Periksa marker ringkasan (teks persis)**

  Baris `=== RINGKASAN ===`, kolom `hasil`:
  Expected: `VERIFY SCHEMA: ALL 31 CHECKS PASSED`
  PASS: teks identik (angka `31`). FAIL (`… CHECKS FAILED dari …`): catat angka gagal → BERHENTI.

- [ ] **Step 4: Diagnostik cepat bila ada FAIL (tabel rujukan — jangan patch manual)**

  | Nomor check gagal | Penyebab paling mungkin | Skrip yang diulang (re-run penuh) |
  |---|---|---|
  | 01, 06, 08–12, 14, 17–20 | 002/003/004/005 tidak lengkap / terpotong | skrip terkait sesuai cakupan check |
  | 02–05 | policy hilang (004/005) | 004 atau 005 |
  | 07 | grant kolom notes bocor (003) | 003 |
  | 13 | trigger signup auth.users hilang (002) | 002 |
  | 15, 16 | enum (001) / view invoker (004) | 001 / 004 |
  | 21, 22 | books UPDATE policy/grant (002) | 002 |
  | 23 | filter PUBLIC profile_stats (004) | 004 |
  | 24–26 | grant notif (005) | 005 |
  | 27 | grant activities (005) | 005 |
  | 28 | grant profiles (002) | 002 |
  | 29, 30 | grant likes/comments/follows/reviews (004) | 004 |
  | 31 | fungsi definer owner/search_path (002/005) | skrip tempat fungsi terkait dibuat |

  Alur pemulihan setelah FAIL: (1) re-run skrip terkait (idempoten) → (2) ulangi **006** (karena skrip terkait bisa mengubah grant yang diuji 006) → (3) ulangi **007** → (4) hanya bila keduanya PASS lanjut Task 9.

- [ ] **Step 5: Simpan bukti Task 8**

  E-007a (`Success`+waktu); E-007b (31 baris PASS — minimal tangkapan baris awal+akhir + konfirmasi nol FAIL); E-007c (marker `VERIFY SCHEMA: ALL 31 CHECKS PASSED`); E-007T (tanggal).
  PASS: terkumpul.

**Acceptance criteria Task 8:** 31/31 PASS; marker persis; bukti E-007a–c/T.

---

### Task 9: Gate V2 & Kumpulkan Bukti

**Tujuan:** Satu tempat memastikan SEMUA bukti ada sebelum menyentuh SCHEMA_STATE; menegakkan aturan "bukti dulu, penandaan kemudian".
**Prasyarat:** Task 7 + Task 8 PASS.
**Instruksi:** ceklist tanpa aksi database.

- [ ] **Step 1: Checklist bukti wajib (Gate V2)**

  Pastikan seluruh butir ini ada di laporan percakapan:
  | ID | Bukti wajib | Sumber |
  |---|---|---|
  | E-001a/b | `Success` + 4 baris enum | Task 2 |
  | E-002a–d | `Success` + RLS/policy/grant | Task 3 |
  | E-003a–d | `Success` + RLS/policy/notes/definer | Task 4 |
  | E-004a–e | `Success` + RLS/policy/view+indeks/invoker+PUBLIC | Task 5 |
  | E-005a–d | `Success` + RLS/policy/trigger/grant notif | Task 6 |
  | E-006a–e/T | `Success` + gagal 0 + marker `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan` + residu null|null + A/B + tanggal | Task 7 |
  | E-007a–c/T | `Success` + 31 PASS + marker `VERIFY SCHEMA: ALL 31 CHECKS PASSED` + tanggal | Task 8 |

  **Definisi Gate V2 = LULUS** hanya bila: (1) seluruh E-001…E-007 ada; (2) teks marker kedua identik persis; (3) nol langkah berstatus FAIL terbuka.
  PASS: Gate V2 LULUS → Task 10. FAIL (ada bukti kurang): ulangi langkah penghasil bukti terkait — JANGAN menandai SCHEMA_STATE.

- [ ] **Step 2: Verifikasi integritas file repo (nol perubahan tak disengaja)**

  Jalankan di terminal repo (bukan Dashboard):
  ```bash
  sha256sum docs/PRD.md
  tr -cd '\r' < docs/ROADMAP.md | wc -c
  git status --porcelain
  git diff --cached --name-only
  ```
  Expected: hash PRD = `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e`; `127`; git status identik kondisi pra-deployment (hanya pola lama + untracked); staged kosong.
  PASS: identik. FAIL (ada file SQL implementasi berubah): **BERHENTI** — laporkan diff ke pengguna; deployment dianggap tercemar.

**Acceptance criteria Task 9:** Gate V2 LULUS dengan bukti lengkap; file repo utuh.

---

### Task 10: Perbarui `db/SCHEMA_STATE.md` (HANYA setelah Gate V2 LULUS)

**Tujuan:** Merekam kenyataan eksekusi (tanggal applied/verified + checklist gate) — satu-satunya izin mengubah SCHEMA_STATE, dan hanya setelah bukti Task 9 lengkap.
**Prasyarat:** Task 9 Gate V2 **LULUS** (bila belum: JANGAN kerjakan task ini).
**Instruksi Dashboard:** tidak ada — edit file repo via editor teks.

- [ ] **Step 1: Isi kolom applied & verified untuk 001–007**

  Edit `db/SCHEMA_STATE.md` baris tabel (kolom `applied (tanggal)` dan `verified (tanggal)`) — isi **keduanya** dengan tanggal eksekusi masing-masing skrip (format `YYYY-MM-DD`; bila dikerjakan beda hari, pakai tanggal masing-masing; bila semua satu sesi: satu tanggal = E-006T/E-007T):

  Contoh dengan tanggal `2026-11-08` (ganti dengan tanggal nyata):
  ```
  | 001_enums.sql | 2026-11-08 | 2026-11-08 | pending |
  | 002_identity_books.sql | 2026-11-08 | 2026-11-08 | pending |
  | 003_library.sql | 2026-11-08 | 2026-11-08 | pending |
  | 004_reviews_social.sql | 2026-11-08 | 2026-11-08 | pending |
  | 005_activity_notifications.sql | 2026-11-08 | 2026-11-08 | pending |
  | 006_negative_tests.sql | 2026-11-08 | 2026-11-08 | pending; dua profil pertama menurut join_date dipakai sebagai A dan B |
  | 007_verify_schema.sql | 2026-11-08 | 2026-11-08 | pending; gate V2 |
  ```
  (Baris 006/007 pertahankan teks Catatan yang sudah ada — hanya kolom tanggal yang diisi.)
  Expected: 7 baris ber-tanggal; tidak ada teks Catatan yang dihapus.
  PASS: tabel terisi. FAIL (ragu tanggal/bukti): kembali Task 9.

- [ ] **Step 2: Centang checklist Gate V2 (3 dari 4 baris)**

  Ubah ke `[x]` HANYA 3 baris gate ini (baris lain tetap `[ ]`):
  ```
  - [x] 001–007 applied & verified (di atas).
  - [x] 006: `ALL NEGATIVE TESTS PASSED` (76 pemeriksaan).
  - [x] 007: `VERIFY SCHEMA: ALL 31 CHECKS PASSED`.
  - [ ] Dilaporkan ke pengguna; Execution 3 belum dimulai.   ← baris ke-4 ditandai di Task 11 Setelah laporan disampaikan
  ```
  Expected: gate 006/007 tercentang; baris ke-4 MASIH `[ ]` (ditandai nanti).
  Urutan wajib: checklist ini dilakukan **setelah** Task 9 (Gate V2 LULUS + bukti E-001…E-007 lengkap) dan **sebelum** Task 11 mengirim laporan — baris ke-4 (Dilaporkan) ditandai di Task 11 Step 4 setelah laporan benar-benar disampaikan ke pengguna.
  FAIL: jangan centang tanpa bukti.

- [ ] **Step 3: Verifikasi pasca-edit**

  ```bash
  grep -n "applied\|\[x\]" db/SCHEMA_STATE.md
  git status --porcelain
  ```
  Expected: 7 baris tabel ber-tanggal; tepat **3 `[x]`** (gate 001–007 / 006 / 007); baris "Dilaporkan ke pengguna" masih `[ ]`; git status hanya menambahkan perubahan `db/SCHEMA_STATE.md` pada pola yang sudah ada (tidak ada file SQL berubah).
  PASS: sesuai. FAIL: koreksi edit (kembalikan bagian yang tak sengaja terubah).

**Acceptance criteria Task 10:** SCHEMA_STATE ber-tanggal untuk 001–007; checklist gate tercentang; nol file SQL berubah.

---

### Task 11: Laporan Akhir & STOP

**Tujuan:** Menyampaikan hasil deployment ke pengguna dan menghentikan tahapan sebelum Execution Task 3 (butuh persetujuan terpisah — README aturan 6).
**Prasyarat:** Task 10 selesai (atau Task 9 FAIL → laporan kegagalan saja).

- [ ] **Step 1: Susun laporan akhir berisi**

  1. **Verdict:** `GATE V2 LULUS` atau `GAGAL` (dengan nomor check/test yang gagal).
  2. **Tabel eksekusi 001–007:** tanggal, hasil Success, ringkasan VERIFY.
  3. **Marker kedua** (kutipan teks persis dari E-006c dan E-007c).
  4. **Bukti:** daftar E-001…E-007 yang ditempel.
  5. **Perubahan file:** hanya `db/SCHEMA_STATE.md` (Task 10) — bukti `git status`; seluruh skrip/PRD/ROADMAP/ADR/bundle utuh (E-integritas Task 9 Step 2).
  6. **Insiden/deviasi selama deployment** (timeout, retry, akun gagal dibuat, dst.) — atau "nol insiden".

- [ ] **Step 2: Konfirmasi batasan**

  Nyatakan dalam laporan: nol commit/push; Execution Task 3 BELUM dimulai; `pg_trgm` tidak ditambahkan; tidak ada patch Table Editor.

- [ ] **Step 3: BERHENTI**

  Jangan memulai Execution Task 3, jangan mengubah file lain, jangan commit — tunggu instruksi pengguna.

- [ ] **Step 4: Tandai checklist SCHEMA_STATE baris ke-4 (hanya setelah laporan disampaikan)**

  Setelah laporan (Step 1) benar-benar disampaikan ke pengguna, kembali ke `db/SCHEMA_STATE.md` dan ubah baris ke-4 dari `[ ]` ke `[x]`:
  ```
  - [x] Dilaporkan ke pengguna; Execution 3 belum dimulai.
  ```
  Expected: tepat **4 `[x]`** di checklist Gate V2; 7 baris tabel ber-tanggal; nol file SQL berubah.
  Jangan lakukan Step 4 sebelum laporan dikirim — checklist mencerminkan kenyataan, bukan niat.
  PASS: 4 `[x]`. FAIL (laporan belum dikirim): jangan centang; kirim laporan dulu.

**Acceptance criteria Task 11:** laporan lengkap 6 butir; batasan terkonfirmasi; checklist 4 `[x]`; tahap berhenti.

---

## Prosedur Penanganan Error & Pemulihan (ringkas — berlaku lintas task)

**Tingkat 1 — error syntax/runtime saat Run skrip N:**
1. Berhenti; jangan lanjut ke N+1 (README aturan 4).
2. Salin pesan error + nomor baris ke laporan.
3. Perbaiki penyebab (prasyarat, kredensial, duplikat email, proyek salah).
4. Re-run **file N yang sama dari baris pertama** (001–005 & 007 idempoten; 006 nol residu).
5. Ulangi blok VERIFY N sebelum lanjut.

**Tingkat 2 — VERIFY gagal padahal `Success` (drift objek):**
1. Jangan memperbaiki dari Table Editor (anti-drift).
2. Re-run penuh skrip terkait; ulangi VERIFY.
3. Masih gagal → proyek tidak kosong / objek asing: **laporkan ke pengguna** untuk keputusan reset project (destruktif, perlu izin eksplisit) atau reconciliasi terarah mengikuti pola skrip.
4. Setelah perbaikan skrip terkait → ulangi 006 lalu 007 bila gate sebelumnya sudah sempat berjalan.

**Tingkat 3 — 006 gagal (daftar test / prasyarat / transaksi):**
1. `PRASYARAT GAGAL` → Task 7 Step 1/2.
2. `SET LOCAL … transaction blocks` / residu tidak null → Task 7 Step 4 (006 tidak sah; eskalasi R-4).
3. Test gagal (daftar non-kosong) → cocokkan keputusan: perbaiki skrip terkait HANYA atas instruksi pengguna (jangan mengedit skrip sendiri di luar plan); lalu ulangi 006 → 007.
4. **Tidak pernah** menandai SCHEMA_STATE sebelum Gate V2.

---

## Risiko, Dampak & Tindakan

| ID | Risiko | Dampak | Deteksi | Tindakan |
|---|---|---|---|---|
| R-1 | Project tidak kosong / berisi eksperimen | Drift skema; VERIFY gagal; 006 kacau | Task 1 Step 2 ≠ 0 tabel | Berhenti; minta keputusan pengguna (reset vs backup+lanjut) |
| R-2 | Akun uji dibuat sebelum 002 → profiles < 2 | 006 abort `PRASYARAT GAGAL` | Task 7 Step 2 count < 2 | Task 7 Step 1b (hapus+buat ulang ATAU profil manual atas izin pengguna) |
| R-11 | Profil > 2 → A/B tidak pasti (akun operator/eksperimen ada) | 006 dijalankan pada profil yang BUKAN akun uji → bukti RLS tidak valid; keputusan palsu | Task 7 Step 2 `n_profil = 2` gagal | **Step 2b**: hentikan proses; laporkan jumlah+identitas profil; prioritaskan project Supabase uji bersih; penghapusan akun BUKAN otomatis dan butuh **persetujuan eksplisit** (CASCADE); pastikan A & B teridentifikasi tepat sebelum lanjut 006 |
| R-3 | Error menengah skrip (timeout, syntax, batas waktu editor) | Skrip N gagal; batch mungkin batal total | Pesan error merah | Tingkat 1: re-run file N; 006 khusus = transaksi abort otomatis → ulangi utuh |
| R-4 | SQL Editor memecah pernyataan 006 (bukan satu sesi) | `set local role` tak berlaku → hasil 006 palsu (lolos/gagal ngawur) | Warning `SET LOCAL can only be used in transaction blocks`; B01 lolos baca notes; residu tidak null | **006 tidak sah**; jangan tandai lolos; laporkan ke pengguna (opsi: versi editor lain / keputusan eksplisit) — jangan mengedit skrip |
| R-5 | 006 daftar test gagal | Gate V2 gagal; skema salah | Step 5/6 Task 7 | Berhenti; identifikasi ID test; rujuk plan §1A/keputusan; perbaikan skrip HANYA atas izin pengguna; ulangi 006→007 |
| R-6 | 007 check tertentu FAIL | Gate V2 gagal; grant/policy menyimpang | Step 2/3 Task 8 | Tabel diagnostik Task 8 Step 4 → re-run skrip terkait → ulangi 006→007 |
| R-7 | Operator menandai SCHEMA_STATE tanpa gate | Rekaman palsu; operator berikutnya salah percaya | Task 9 checklist belum lengkap | Aturan keras: Task 10 hanya setelah Gate V2 LULUS; review akhir memverifikasi bukti |
| R-8 | Patch manual dari Table Editor | Anti-drift dilanggar; 007 kelak FAIL | Laporan operator / diff tak terduga | Tolak; kembalikan ke jalur skrip (Tingkat 2) |
| R-9 | `pg_trgm` / objek luar ditambahkan manual | Penyimpangan spek | Pemeriksaan Task 9 Step 2 + kebiasaan operator | Hapus hanya atas izin pengguna; catat insiden |
| R-10 | Kredensial akun uji bocor ke laporan publik | Risiko akun test | Saat menyusun laporan | Sebutkan hanya email; JANGAN tempel password |
| R-07 | Asumsi transaksi SQL Editor tidak terverifikasi statis | Operator menganggap file dijalankan sebagai satu batch tanpa bukti → keputasan palsu | Baca bagian "Asumsi transaksi SQL Editor (R-07)" setelah tabel Analisis Transaksional | TIDAK mengklaim atomic tanpa bukti; bila perilaku tidak pasti → wajib verifikasi runtime (006: `null|null` + 0 gagal + marker) dan Prosedur Pemulihan Tingkat 3; jangan lanjut Gate V2 |

---

## Format Laporan Akhir Deployment

```markdown
# DEPLOYMENT REPORT — Execution Task 2 (Dashboard-First)

**Tanggal:** <tanggal> · **Operator:** <nama> · **Project Ref:** <ref> · **Role:** postgres

## A. GATE V2
**LULUS | GAGAL**
- Marker 006: `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`  (E-006c)
- Marker 007: `VERIFY SCHEMA: ALL 31 CHECKS PASSED`        (E-007c)

## B. TABEL EKSEKUSI 001–007
| Skrip | Tanggal | Success? | VERIFY ringkas | Bukti |
|---|---|---|---|---|

## C. BUKTI (E-001a … E-007c/T)
(tempel output kunci)

## D. INSIDEN / DEVIASI
(nol insiden | daftar + penanganan)

## E. PERUBAHAN FILE
(hanya db/SCHEMA_STATE.md + bukti git status; sisanya utuh)
```

---

## Self-Review (skill)

1. **Spec coverage:** prasyarat → Task 1; urutan 001→007 → Task 2–8; langkah per file via Dashboard → tiap task (Tujuan/Prasyarat/Instruksi/Hasil/PASS-FAIL/Gagal); pemeriksaan pasca-file → VERIFY eksak tiap task; analisis transaksional/idempotensi → tabel khusus + Prosedur Pemulihan; runtime 006/007 → Task 7/8; RLS 2 akun uji → Task 7 (keputusan 8); kriteria marker persis → Global Constraints + Task 7 Step 6 + Task 8 Step 3 + Task 9; bukti SCHEMA_STATE → Task 9 tabel E + Task 10; risiko → tabel R-1…R-10 + tindakan per tahap. ✔
2. **Placeholder scan:** tanpa TBD/TODO; setiap query VERIFY berisi SQL penuh + expected baris eksak (4/6/4/12/7/31); tanggal memakai pola `YYYY-MM-DD` dengan instruksi ganti-tanggal-nyata (bukan nilai karangan); Task 10 contoh baris memakai tanggal contoh eksplisit. ✔
3. **Konsistensi:** marker `76`/`31` identik di Global Constraints, Task 7, 8, 9, 10, 11; akun uji = SETELAH 002 konsisten antara Task 1 Step 5 ↔ Task 7 Step 1; A/B = `order by join_date, id` konsisten dengan skrip 006; daftar check diagnostik Task 8 mencakup 01–31; aturan "berhenti pada error" konsisten README. ✔
4. **Revisi pasca-review (R-01…R-07):** R-01 (001 = 38 baris) ✔; R-02 (002 = ×2 fungsi) ✔; R-03 (check 31 → 002/005) ✔; R-04 (Step 2: `n_profil = 2` + cross-check `auth.users` email; Step 2b profil > 2 = STOP + 6 poin: hentikan/laporkan/prioritaskan project bersih/penghapusan bukan otomatis-butuh-persetujuan-eksplisit/identifikasi A&B tepat) ✔; R-05 (Step 2 checklist 3 `[x]` + baris ke-4 di Task 11 Step 4) ✔; R-06 (Step 1b SQL lengkap tanpa elipsis + `on conflict do nothing` + fallback unik) ✔; R-07 (klarifikasi asumsi transaksi SQL Editor + larangan klaim atomic tanpa bukti + kewajiban verifikasi/pemulihan) ✔. ✔
5. **Placeholder scan ulang:** tanpa TBD/TODO; tanpa `...`/elipsis dalam SQL (Step 1b SQL sekarang lengkap 14 baris); semua expected berupa baris eksak atau pola `YYYY-MM-DD` dengan instruksi ganti-nyata (bukan nilai karangan). ✔

