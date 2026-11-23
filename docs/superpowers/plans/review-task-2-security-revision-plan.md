# Review Plan — Execution Task 2 Security Revision (Statis, Pra-SQL)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to run this review plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Global override: NO SQL execution, NO database/Supabase access, NO file modifications, NO installs, NO commits.**

**Goal:** Review independen statis terhadap hasil BUILD Task 2 Security Revision sebelum SQL pertama dijalankan di Supabase — memverifikasi klaim BUILD dari file implementasi, bukan dari laporan.

**Architecture:** Reviewer membaca 8 file dalam cakupan, menjalankan perintah grep/diff/sha256sum/read-only, membandingkan kondisi aktual dengan spesifikasi keputusan di `docs/superpowers/plans/execution-task-2-database-plan.md` (acuan utama) dan kode eksak di `docs/superpowers/plans/execution-task-2-security-revision-plan.md` (sumber klaim BUILD, referensi — bukan target review). Temuan **hanya dilaporkan**, tidak diperbaiki.

**Tech Stack:** Bash read-only (`grep`, `sed`, `awk`, `diff`, `sha256sum`, `tr`, `wc`, `git status/diff/log` tanpa aksi tulis), pembacaan file. PostgreSQL TIDAK diakses.

**Spec:** `docs/superpowers/plans/execution-task-2-database-plan.md` — khususnya §1 (keputusan 1–8), **§1A (revisi audit A–E)**, §3 (matriks RLS), §6 (risiko), §8–§9 (checklist/langkah). Referensi sampingan: `execution-task-2-security-revision-plan.md` (kode eksak yang diklaim sudah diimplementasikan).

## Global Constraints

- **DILARANG** menjalankan SQL apa pun (termasuk blok `-- VERIFY`), membuka SQL Editor, atau menyentuh database/Supabase apa pun.
- **DILARANG** mengubah file implementasi apa pun selama review — termasuk `db/*`, plan doc, README, SCHEMA_STATE. Satu-satunya file yang boleh dibuat/diubah di tahap PLAN ini adalah rencana review ini sendiri.
- **DILARANG** memperbaiki temuan secara langsung; temuan = laporan saja.
- **DILARANG** menandai `db/SCHEMA_STATE.md` sebagai PASSED/menerapkan skrip apa pun.
- **DILARANG** install dependency/CLI baru; **DILARANG** commit/push.
- Jangan ubah `docs/PRD.md` (hash acuan `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e`), `docs/ROADMAP.md` (CRLF, 127 CR), ADR `0001`, `db/AUDIT_REVIEW_BUNDLE.md`.
- **Anchoring guard:** laporan BUILD Task 2 adalah **klaim yang diverifikasi ulang**, bukan bukti. Setiap klaim wajib direproduksi dari file; larangan mengutip laporan BUILD sebagai bukti kebenaran.
- Urutan kerja: PLAN → REVIEW → APPROVAL → BUILD/REVIEW → VERIFY. Dokumen ini = tahap **PLAN**; pelaksanaan review = tahap **REVIEW** setelah persetujuan.

---

## Peta File & Area Pemeriksaan

| # | File | Area utama |
|---|---|---|
| 1 | `db/scripts/002_identity_books.sql` | Grant profiles/books; hilangnya policy UPDATE books; blok VERIFY |
| 2 | `db/scripts/004_reviews_social.sql` | Filter PUBLIC di `profile_stats`; grant 4 tabel sosial; hygiene grant view |
| 3 | `db/scripts/005_activity_notifications.sql` | Logika `trg_library_activity` (INSERT/UPDATE/visibility/DELETE); integritas aktivitas review; grant activities/notifications; index; properti definer |
| 4 | `db/scripts/006_negative_tests.sql` | Fixture, urutan sesi, role switching, isolasi transaksi, **ketepatan seluruh 76 test** (37 baru + 39 lama di bawah skema baru), harness grants |
| 5 | `db/scripts/007_verify_schema.sql` | **31 checks** — struktur CTE + ketepatan tiap check mendeteksi kondisi yang dimaksud |
| 6 | `db/README.md` | Tabel eksekusi, seksi "Aturan grant & integritas", bullet keamanan |
| 7 | `db/SCHEMA_STATE.md` | Marker, status `applied` (wajib masih `pending`), catatan placeholder |
| 8 | `docs/superpowers/plans/execution-task-2-database-plan.md` | §1A, matriks §3, keputusan 7, §6, §8, §9; konsistensi angka 76/31 |

**Di luar cakupan sebagai target (diverifikasi hanya agar TIDAK berubah):** `001_enums.sql`, `003_library.sql`, `docs/PRD.md`, `docs/ROADMAP.md`, ADR `0001`, `db/AUDIT_REVIEW_BUNDLE.md`, seluruh `apps/ packages/ scripts/` (source app), dan `execution-task-2-security-revision-plan.md` (referensi klaim).

**Referensi (bukan target):** `docs/superpowers/plans/execution-task-2-security-revision-plan.md` — blok kode di dalamnya adalah spesifikasi implementasi yang diklaim diikuti; review membandingkan isi file vs blok ini (lihat Task 8).

---

## Aturan Temuan (berlaku untuk SELURUH review)

1. **Report-only.** Setiap temuan dicatat dalam format laporan akhir (di bawah) — **tidak ada perbaikan** pada file apa pun selama review.
2. **Bukti wajib.** Setiap temuan menyertakan bukti: perintah + output kunci, atau `file:baris` + kutipan.
3. **Klaim tanpa bukti = NEEDS CLARIFICATION**, bukan PASS.
4. Jangan menandai SCHEMA_STATE apa pun; jangan menjalankan skrip; jangan "sekalian membetulkan" typo yang ditemukan.
5. Temuan dikeluarkan **setelah semua task selesai** (Task 9) agar tidak memicu perbaikan dini.

---

### Task 1: Scope Control & Integritas Artefak

**Files:** Verify-only — `docs/PRD.md`, `docs/ROADMAP.md`, `docs/architecture/0001-supabase-first-backend.md`, `db/AUDIT_REVIEW_BUNDLE.md`, `db/scripts/001_enums.sql`, `db/scripts/003_library.sql`, working tree git.

- [ ] **Step 1: Hash PRD**

Run: `sha256sum docs/PRD.md`
Expected: `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e`

- [ ] **Step 2: Line-ending ROADMAP**

Run: `file docs/ROADMAP.md` lalu `tr -cd '\r' < docs/ROADMAP.md | wc -c`
Expected: `with CRLF line terminators`; `127`

- [ ] **Step 3: Status git tanpa staging/commit baru**

Run: `git status --porcelain` lalu `git diff --cached --name-only`
Expected: (a) daftar hanya berisi pola pra-adas (` M README.md`, ` M docs/PRD.md`, ` M docs/ROADMAP.md`) + entri untracked; **tidak ada** entri staged; (b) `git diff --cached` kosong. Catat hash `git log -1 --format=%H` sebagai bukti posisi (tanpa membandingkan/perubahan apa pun).

- [ ] **Step 4: 001 & 003 identik dengan snapshot bundle**

Run (bandingkan konten setelah normalisasi fence/indentasi — pola yang terbukti bekerja):
```bash
awk '/<!-- BEGIN: db\/scripts\/001_enums.sql -->/{f=1;next} /<!-- END: db\/scripts\/001_enums.sql -->/{f=0} f' db/AUDIT_REVIEW_BUNDLE.md | sed -e '/^```/d' -e '/^<!-- /d' -e 's/^[[:space:]]*//' -e '/^$/d' > /tmp/opencode/r001.txt
diff /tmp/opencode/r001.txt <(sed -e 's/^[[:space:]]*//' -e '/^$/d' db/scripts/001_enums.sql)
```
Expected: **hanya baris marker fence** (` ```sql ` / ` ``` `) yang berbeda; seluruh baris SQL identik. Ulangi pola sama untuk `003_library.sql`.

- [ ] **Step 5: ADR & bundle tak tersentuh**

Run: `grep -n "Dashboard-first" docs/architecture/0001-supabase-first-backend.md | head -2` dan `grep -c "ALL RLS TESTS PASSED" db/AUDIT_REVIEW_BUNDLE.md`
Expected: ADR memuat keputusan Dashboard-first (isi utuh); bundle → **1** (satu-satunya lokasi teks marker lama yang sah — bundle memang sengaja basi).

- [ ] **Step 6: Tidak ada artefak eksekusi SQL / file di luar cakupan**

Run: `git status --porcelain` (lagi, teliti) dan `ls db/scripts/`
Expected: tidak ada file log/backup/`.sql.new`/migration baru; `db/scripts/` hanya `001`–`007`; seluruh perubahan sesi BUILD berada di dalam `db/` + `docs/superpowers/` (untracked, tanpa staged).

**Acceptance criteria Task 1:** Hash PRD cocok; ROADMAP 127 CR; 001/003 identik bundle; ADR/bundle utuh; working tree tanpa staged/commit/artefak eksekusi.

---

### Task 2: Review `002_identity_books.sql` — Grants & Insert-Only Books

**Files:** `db/scripts/002_identity_books.sql`

- [ ] **Step 1: Policy UPDATE books sudah hilang total**

Run: `grep -rn "books_update_authenticated" db/scripts/`
Expected: **nol hasil** (tidak ada di skrip mana pun).

- [ ] **Step 2: Ekstrak matriks grant aktual 002**

Run: `grep -n "^revoke all on table\|^grant " db/scripts/002_identity_books.sql`
Expected persis 6 baris grant/revoke:
1. `revoke all on table public.profiles from anon, authenticated;`
2. `grant select on table public.profiles to anon, authenticated;`
3. `grant update on table public.profiles to authenticated;`
4. `revoke all on table public.books from anon, authenticated;`
5. `grant select on table public.books to anon, authenticated;`
6. `grant insert on table public.books to authenticated;`
**Tidak boleh** ada grant UPDATE/DELETE books ke role klien mana pun, maupun INSERT/DELETE profiles ke klien.

- [ ] **Step 3: Derive matriks kebijakan & bandingkan spesifikasi**

Run: `grep -n "create policy\|TANPA policy" db/scripts/002_identity_books.sql`
Expected: 4 policy — `profiles_select_public`, `profiles_update_own`, `books_select_public`, `books_insert_authenticated`; komentar `books: TANPA policy update/delete (insert-only; koreksi operator via SQL Editor)`.
Bandingkan dengan §3 plan doc: `books` INSERT=authenticated, UPDATE=**tidak ada**, DELETE=**tidak ada**; `profiles` INSERT=**tidak ada**, UPDATE=own, DELETE=**tidak ada** → cocok.

- [ ] **Step 4: Blok VERIFY benar & tak menyesatkan**

Read bagian `-- VERIFY` di akhir file.
Expected: (a) komentar `harapkan 4 policy (2 profiles + 2 books), tanpa insert/delete di profiles, tanpa update/delete di books` — angka 4 = 2+2 konsisten; (b) query grant `table_privileges` untuk profiles/books ada dengan komentar `profiles=select,update; books=select,insert`.

- [ ] **Step 5: Jalur klien ON CONFLICT tetap sah (statis)**

Reasoning check: `INSERT ... ON CONFLICT DO NOTHING` hanya butuh hak INSERT → dibuktikan K03 di 006 (Task 5). Pastikan 002 tidak menghapus policy `books_insert_authenticated` dan tidak menambahkan policy apapun selain 4 di Step 3.

**Acceptance criteria Task 2:** matriks grant persis 6 baris tanpa UPDATE/DELETE books; hanya 4 policy; VERIFY konsisten; selaras §3.

---

### Task 3: Review `004_reviews_social.sql` — Statistik PUBLIC & Grant Sosial

**Files:** `db/scripts/004_reviews_social.sql`

- [ ] **Step 1: Filter visibility di `profile_stats`**

Run: `grep -n "l.visibility = 'PUBLIC'" db/scripts/004_reviews_social.sql`
Expected: **tepat 2** — subquery `books_read` (`... visibility = 'PUBLIC' and l.status = 'FINISHED'`) dan `currently_reading` (`... visibility = 'PUBLIC' and l.status = 'READING'`). Urutan predicate persis `visibility` dulu `status` kemudian (mengikat check 007 #23).

- [ ] **Step 2: Kolom lain tak berubah**

Read view `profile_stats`.
Expected: `reviews_count` (dengan `deleted_at is null`), `followers_count`, `following_count` tanpa filter visibility; tanpa view kedua; komentar Keputusan 7 memuat "revisi audit 2026-11-08" + "hanya angka yang berasal dari entri PUBLIC".

- [ ] **Step 3: Grant 4 tabel sosial — ekstrak & bandingkan matriks**

Run: `grep -n "^revoke all on table public\.\|^grant " db/scripts/004_reviews_social.sql`
Expected (tabel sosial): reviews → revoke, select (anon+auth), `insert, update` auth (tanpa delete); likes → revoke, select, `insert, delete` (tanpa update); comments → revoke, select, `insert, delete` (tanpa update); follows → revoke, select, `insert, delete` (tanpa update).
Cocokkan §3: reviews DELETE=**tidak ada** ✓; likes/comments/follows UPDATE=**—** ✓.

- [ ] **Step 4: Hygiene grant kedua view**

Run: `grep -n "revoke all on view\|grant select on public\." db/scripts/004_reviews_social.sql`
Expected: 2 pasang revoke+grant untuk `book_rating_summary` dan `profile_stats` (anon, authenticated).

- [ ] **Step 5: Tak ada perubahan tak terduga**

Run: `grep -c "create policy" db/scripts/004_reviews_social.sql` dan `grep -n "security_invoker" db/scripts/004_reviews_social.sql`
Expected: jumlah policy tetap **10** (3 reviews + 3 likes + 2 comments... hitung aktual dari file: reviews 3, likes 3, comments 3, follows 3 = 12 — reviewer mencatat angka aktual dan memastikan **identik dengan pra-revisi** via bundle snapshot bila perlu); `book_rating_summary` tetap `security_invoker = on` (keputusan 5 utuh).

**Acceptance criteria Task 3:** 2 filter PUBLIC dengan urutan benar; matriks grant 4 tabel = §3; hygiene view; keputusan 5/7 tercatat.

---

### Task 4: Review `005_activity_notifications.sql` — Logika Trigger & Grant

**Files:** `db/scripts/005_activity_notifications.sql`

- [ ] **Step 1: Properti fungsi & event trigger**

Run:
```bash
grep -n "create or replace function public.trg_library_activity" db/scripts/005_activity_notifications.sql
grep -n "after insert or update or delete on public.library_entries" db/scripts/005_activity_notifications.sql
grep -c "security definer set search_path = ''" db/scripts/005_activity_notifications.sql
```
Expected: 1 fungsi dengan `security definer set search_path = ''`; event **insert or update or delete** tepat 1; jumlah definer di file = **5** (`trg_review_activity`, `trg_library_activity`, `trg_like_notification`, `trg_comment_notification`, `trg_follow_notification`).
Pastikan blok pembuatan trigger memakai **drop-lalu-create** (guard `if exists ... drop ... end if; create ...`), bukan `if not exists ... create` — syarat idempoten agar perubahan event diterapkan saat re-run.

- [ ] **Step 2: Walkthrough matriks logika `trg_library_activity`**

Read **seluruh** fungsi, lalu petakan setiap cabang ke tabel di bawah. Reviewer menandai ✅ bila kode benar mengimplementasikan baris itu, ❌ bila tidak (❌ = temuan):

| # | Skenario (tg_op · visibility · perubahan) | Harapan (keputusan §1A-A) |
|---|---|---|
| 1 | INSERT entri PRIVATE (apa pun statusnya) | **tanpa** insert aktivitas; `return new` |
| 2 | INSERT entri PUBLIC, status WANT_TO_READ | `BOOK_ADDED` |
| 3 | INSERT entri PUBLIC, status READING | `BOOK_STARTED` |
| 4 | INSERT entri PUBLIC, status FINISHED | `BOOK_FINISHED` |
| 5 | UPDATE, entri masih PRIVATE, status/progress berubah | **tanpa** aktivitas; **tanpa** purge; `return new` |
| 6 | UPDATE, kini PRIVATE, lama PUBLIC | **purge** aktivitas library (actor+book); `return new` |
| 7 | UPDATE, kini PUBLIC, lama PRIVATE, TANPA aksi baca (visibility saja) | **tanpa** aktivitas retroaktif (`return new` di cabang `old.visibility = 'PRIVATE'`) |
| 8 | UPDATE, kini PUBLIC, status berubah ke READING/FINISHED | `BOOK_STARTED`/`BOOK_FINISHED` |
| 9 | UPDATE, kini PUBLIC, status mundur ke WANT_TO_READ | **tanpa** aktivitas (`return new`) |
| 10 | UPDATE, kini PUBLIC, progress berubah | `READING_PROGRESS_UPDATED` |
| 11 | UPDATE, kini PUBLIC, tak ada perubahan relevan (dan lama sudah PUBLIC) | **tanpa** aktivitas |
| 12 | DELETE entri lama-nya PUBLIC | **purge** aktivitas library; `return old` |
| 13 | DELETE entri lama-nya PRIVATE | tanpa purge; `return old` |
| 14 | Purge **hanya** menyentuh tipe `BOOK_ADDED, BOOK_STARTED, BOOK_FINISHED, READING_PROGRESS_UPDATED` | `REVIEW_CREATED`/`RATING_CREATED` **tidak pernah** masuk daftar filter |

- [ ] **Step 3: Bukti statis pendukung matriks**

Run:
```bash
grep -c "activity_type in ('BOOK_ADDED'" db/scripts/005_activity_notifications.sql
grep -c "old.visibility" db/scripts/005_activity_notifications.sql
grep -n "return old" db/scripts/005_activity_notifications.sql
```
Expected: filter purge tepat **2** (cabang DELETE + cabang PUBLIC→PRIVATE); `old.visibility` ≥ 3; `return old` ada (cabang DELETE).

- [ ] **Step 4: Aktivitas review tak tercemar purge**

Run: `awk '/create or replace function public.trg_review_activity/,/end \$\$;/' db/scripts/005_activity_notifications.sql | grep -c visibility`
Expected: **0** — `trg_review_activity` tidak mengenal `visibility` sama sekali (tetap independen; diuji V15).
Pastikan fungsi review **tidak ikut diubah** (struktur pemetaan rating-only vs berkonten utuh).

- [ ] **Step 5: Grant activities & notifications**

Run: `grep -n "^revoke all on table public.activities\|^revoke all on table public.notifications\|^grant" db/scripts/005_activity_notifications.sql`
Expected:
1. `revoke all on table public.activities from anon, authenticated;` + `grant select on table public.activities to anon, authenticated;` (tanpa I/U/D klien)
2. `revoke all on table public.notifications from anon, authenticated;`
3. `grant select (id, user_id, notification_type, actor_id, review_id, comment_id, read, created_at) on public.notifications to authenticated;` (8 kolom = seluruh kolom tabel)
4. `grant update (read) on public.notifications to authenticated;` — **tepat 1** baris grant UPDATE, hanya `read`
5. **Tidak ada** grant apa pun ke `anon` pada notifications (kolom maupun tabel)

- [ ] **Step 6: Index purge & policy tetap**

Run: `grep -n "activities_actor_book_idx\|create policy" db/scripts/005_activity_notifications.sql`
Expected: index `activities_actor_book_idx (actor_id, book_id)` ada; policy tetap 3 (`activities_select_public using (true)`, `notifications_select_own`, `notifications_update_own`) — feed tetap publik (keputusan §1A-A: jejak publik sah), UPDATE notif tetap dibatasi RLS own.

- [ ] **Step 7: Selaras matriks §3 plan doc**

Bandingkan hasil Step 5–6 dengan baris `activities`/`notifications` §3: activities SELECT=publik (invarian §1A), I/U/D=**tidak ada**; notifications UPDATE=**hanya kolom `read`** (grant + RLS own), anon tak punya apa pun.

**Acceptance criteria Task 4:** matriks 14 baris terpetakan ✅ tanpa ❌; filter purge=2 dan tak menyentuh review; grant persis Step 5; definer=5; drop-create guard; selaras §3.

---

### Task 5: Review `006_negative_tests.sql` — Fixture, Sesi, Transaksi, 76 Test

**Files:** `db/scripts/006_negative_tests.sql`

- [ ] **Step 1: Hitungan & identitas test**

Run:
```bash
grep -c "^select public._t006_expect" db/scripts/006_negative_tests.sql
for p in A B K N S V AN P; do printf "%s=" $p; grep -o "'$p[0-9][0-9] " db/scripts/006_negative_tests.sql | sort -u | wc -l; done
grep -o "'[ABPSKVN][0-9][0-9] \|'AN[0-9][0-9] " db/scripts/006_negative_tests.sql | sort | uniq -d
```
Expected: total **76**; A=21, B=13, K=4, N=4, S=1, V=18, AN=8, P=7 (21+13+4+4+1+18+8+7=76); **nol duplikat ID**. (Catatan pola: prefix `AN` tidak cocok pola `[ABPSKVN][0-9][0-9]` — wajib dihitung terpisah; menghitung dengan pola lama saja = false negative.)

- [ ] **Step 2: Urutan sesi & header**

Run: `grep -n "^-- =\+ \(FIXTURE\|SESI\|POSTGRES\|RINGKASAN\)" db/scripts/006_negative_tests.sql`
Expected urutan: FIXTURE → SESI A → SESI B → SESI A KEMBALI → SESI V → SESI ANON → POSTGRES → RINGKASAN; header memuat `(76 pemeriksaan)` dan daftar sesi lengkap.

- [ ] **Step 3: Role switching & klaim JWT**

Run: `grep -c "set local role" db/scripts/006_negative_tests.sql; grep -c "reset role" db/scripts/006_negative_tests.sql; grep -c "reset request.jwt.claims" db/scripts/006_negative_tests.sql; grep -c "set_config('request.jwt.claims'" db/scripts/006_negative_tests.sql`
Expected: `set local role` = **6** (A, B, A-kembali, V-A, V-B, ANON); `reset role` = **6** (B, A-kembali, V-A, V-B, ANON, POSTGRES); `reset request.jwt.claims` = **6** (sama); `set_config` = **5** (lima sesi authenticated; ANON tanpa klaim).
Verify per blok: sesi ANON memakai `set local role anon` **tanpa** `set_config`; POSTGRES hanya reset (superuser).

- [ ] **Step 4: Isolasi transaksi**

Run: `grep -c "^begin;" db/scripts/006_negative_tests.sql; grep -ci "^commit" db/scripts/006_negative_tests.sql; grep -c "^rollback;" db/scripts/006_negative_tests.sql; grep -n "create table public._t006\|drop table if exists public._t006" db/scripts/006_negative_tests.sql`
Expected: `begin` = 1, `commit` = **0**, `rollback` = 1; harness dibuat dengan `create table` + didahului `drop table if exists` (idempoten); klaim "nol residu" sah karena semua DML fixture/test ada di dalam transaksi yang di-rollback.

- [ ] **Step 5: Fixture & harness grants**

Run: `grep -n "'book_v1'\|'book_v2'\|to anon" db/scripts/006_negative_tests.sql | head -10`
Expected: fixture membuat 2 buku (`t006-book-v1`, `t006-book-v2`) + key id `book_v1`/`book_v2` di `_t006_ids` (total 9 key); **tepat 2** grant anon: `grant select on public._t006_ids to anon;` dan `grant select, insert on public._t006_results to anon;` — pada tabel harness saja, **bukan** tabel produk (verifikasi: tidak ada `to anon` lain di file).
Fixture insert berjalan **sebelum** `set local role` pertama (role postgres) — aman untuk RLS/grant.

- [ ] **Step 6: Ketepatan test baru — K (books insert-only)**

Read K01–K04.
Expected: K01 `UPDATE books` → `expect_fail` (42501; sah karena tanpa grant UPDATE — bukan karena RLS); K02 INSERT baru → pass; K03 `ON CONFLICT (google_books_id) DO NOTHING` duplikat → pass (bukti jalur upsert tanpa hak UPDATE); K04 (blok POSTGRES) judul `book1` masih `Buku Uji 006-1` → membuktikan K01 benar-benar tak berefek (bukan sekadar error).

- [ ] **Step 7: Ketepatan test baru — N (kolom notifikasi)**

Read N01–N04.
Expected: N01 `SET notification_type`, N02 `SET actor_id`, N03 `SET user_id` → `expect_fail` (42501 akibat grant kolom — **bukan** keberhasilan karena RLS); subquery WHERE-nya hanya memakai kolom yang di-grant SELECT (notification_type, user_id) agar kegagalan murni dari SET; N04 (sesi B) `SET read` pada notif A → `expect_0rows` (grant SET read ada, RLS own menolak 0 baris) — membedakan gate kolom vs gate baris. P07 (POSTGRES) membuktikan N01/N02 tak berefek (type & actor utuh).

- [ ] **Step 8: Ketepatan test baru — S/P (statistik)**

Read S01, A20, P06, A21.
Expected urutan & matematika: S01 berada **sebelum** A20 (verifikasi urutan baris: `grep -n "S01\|A20"` — nomor baris S01 < A20); saat S01: `entry_pub` PUBLIC FINISHED → books_read=1, `entry_priv` PRIVATE READING → dihitung 0 → `books_read=1 AND currently_reading=0`. P06 (POSTGRES, akhir): setelah A20 `entry_priv` PUBLIC READING → sedang=1; `entry_pub` tetap baca=1; `vb1` PRIVATE (V13) tak dihitung; `vb2` terhapus (V16) → `baca=1 AND sedang=1`. A21 tetap 1 baris.

- [ ] **Step 9: Ketepatan test baru — V (state machine visibility)**

Read V01–V18 baris per baris; telusuri state `vb1`/`vb2` dan cocokkan ke matriks Task 4:
Expected rangkaian: V01 insert PRIVATE (V02 aktivitas=0) → V03 insert PUBLIC vb2 (V04 ≥1 BOOK_ADDED) → V05 status di PRIVATE (V06 tetap 0) → V07 V→P saja (V08=0, tak retroaktif) → V09 progress saat PUBLIC (V10 ≥1) → V11 review berkonten (V12 REVIEW_CREATED=1) → V13 P→V (V14 library=0 **purge**, V15 review **tetap=1**) → V16 DELETE vb2 (V17 library=0) → V18 sesi B update visibility milik A → `expect_0rows`.
Verifikasi silang: V12/V15 membuktikan integritas aktivitas review saat purge; V14/V17 membuktikan anti-bocor pasca-transisi/penghapusan.

- [ ] **Step 10: Ketepatan test baru — ANON (termasuk AN08)**

Read AN01–AN08 + sesi ANON.
Expected: sesi `set local role anon` tanpa klaim; AN01 SELECT `notes` → 42501 (hak kolom); AN02/AN03 INSERT → 42501; AN04 UPDATE notifications → 42501 (anon nol grant); AN05 feed ≥1; AN06 `profile_stats` ≥1; AN07 `entry_pub` terlihat=1; **AN08 target `book_v1`** (entri PRIVATE sejak V13) = 0 baris — **bukan** `entry_priv` (yang sudah PUBLIC sejak A20; target `entry_priv` akan false-fail — deviasi terdaftar, keputusan pengguna).
Catat: AN05/AN06 tak menyentuh `_t006_ids` tetapi tetap butuh INSERT `_t006_results` → divalidasi Step 5 (grant anon).

- [ ] **Step 11: Regresi 39 test lama di bawah skema baru**

Untuk tiap test lama, pastikan prasyaratnya **masih terpenuhi** setelah revisi. Periksa khusus:
- A06/A07/B10: INSERT activities/notifications tetap ditolak (kini karena policy **dan** grant) ✓ — `expect_fail` 42501.
- A02/B01: `notes` tetap tanpa grant SELECT ✓ (003 tak berubah).
- A08: `profiles` UPDATE grant ada + RLS own → 0 baris ✓.
- A13: tepat 3 notifikasi — pastikan grant `select (… notification_type …)` mencakup kolom filter-nya ✓ (Step 5 Task 4).
- A14/A15: `SET read` tetap lolos grant+RLS ✓.
- B05: UPDATE review oleh B → grant update ada → 0 baris RLS ✓. **B06:** DELETE review oleh B — kini **tanpa grant DELETE** → 42501; `expect_0rows` menerima 42501 (kode `exception when others` dengan daftar sqlstate) → tetap PASS. Catat sebagai observasi desain (lihat Risiko FP-2).
- A16–A19: soft-delete via UPDATE tetap sah (grant update) ✓.
- A20: transisi V→P kini melewati cabang "tanpa retroaktif" — hasil **sama** seperti perilaku lama (aktivitas tetap 0) ✓.
- Fixture: `entry_priv` (PRIVATE, READING) kini **tak** membuat aktivitas (perilaku lama membuat BOOK_STARTED) — pastikan **tidak ada** test lama yang bergantung pada keberadaan aktivitas `entry_priv` (B12 hanya `count >= 1`; aman).
- B12/B13/A18/P01–P05: tak terdampak grant baru (role/postgres tetap bypass) ✓.

- [ ] **Step 12: Desain helper `expect_*` & risiko false positive**

Read 4 fungsi helper.
Expected: `expect_fail`/`expect_0rows` menerima sqlstate `42501, 23505, 23514` — **catat** (jangan perbaiki) bahwa error dengan kode itu dihitung lolos walau penyebabnya bukan yang dimaksud (lihat Risiko FP-2). `expect_true` mengubah exception → FAIL (aman). Ringkasan RINGKASAN memakai `count(*)` dinamis (tanpa hardcode 76 di query).

**Acceptance criteria Task 5:** 76 test unik dgn distribusi benar; 8 sesi urut; 6/6/6/5 role-switch; begin/rollback tanpa commit; 2 grant harness anon saja; seluruh 37 test baru terbukti mengukur klaimnya; 39 test lama tak ada yang dirusak skema baru (termasuk B06 via daftar sqlstate).

---

### Task 6: Review `007_verify_schema.sql` — 31 Checks

**Files:** `db/scripts/007_verify_schema.sql`

- [ ] **Step 1: Struktur & hitungan**

Run: `grep -c "union all select '" db/scripts/007_verify_schema.sql; grep -c "union all select '\|  select '01 " db/scripts/007_verify_schema.sql; grep -n "^)" db/scripts/007_verify_schema.sql`
Expected: union = **30**; total (30 + 1 awal `select '01`) = **31**; tepat satu `)` penutup CTE setelah check 31. Header memuat `Kini 31 checks (20 awal + 11 revisi audit 2026-11-08)`.

- [ ] **Step 2: Semantik check 21–31 — tabel verifikasi**

Untuk tiap baris, baca SQL check dan pastikan **ia benar-benar mendeteksi** kondisi klaimnya (✅ deteksi benar / ⚠️ deteksi lemah / ❌ tak mendeteksi → temuan):

| # | Klaim check | Logika deteksi yang benar | Jebakan yang diperiksa |
|---|---|---|---|
| 21 | books tanpa policy UPDATE/DELETE | `not exists pg_policies cmd IN (UPDATE,DELETE)` | tak terkecoh policy INSERT/SELECT |
| 22 | books tanpa grant UPDATE/DELETE klien | `not exists table_privileges grantee anon/auth, priv UPDATE/DELETE` | mencakup **kedua** grantee; bukan cuma authenticated |
| 23 | profile_stats hanya PUBLIC | selisih `length`/`replace 'PUBLIC'` ≥2 di viewdef **dan** `like '%visibility%'` | pembagi 4 vs panjang kata 6 (integer division: 1 kemunculan→1, 2→3) — pastikan ≥2 tak lolos dengan 1 kemunculan; ejaan harus persis `PUBLIC` |
| 24 | UPDATE notif = hanya `read` | `string_agg(column UPDATE grantee authenticated) = 'read'` | grant level-tabel ikut terbaca (per kolom) → multi-kolom ≠ 'read'; urutan `order by column_name` (1 kolom aman) |
| 25 | anon nol grant notif | `not exists` di **column_privileges** DAN **table_privileges** | kedua katalog dicek |
| 26 | notif tanpa INSERT/DELETE authenticated | `not exists` table_privileges | tetap mengizinkan SELECT kolom & UPDATE `read` (tidak ikut tercakup) |
| 27 | activities klien hanya SELECT | `not exists` priv I/U/D untuk **kedua** grantee | tak mengecek kebijakan (policy terpisah di check 02) |
| 28 | profiles tanpa INSERT/DELETE klien | `not exists` I/D klien | UPDATE own tetap diizinkan (tidak ikut tercakup) |
| 29 | likes/comments/follows tanpa UPDATE auth | `not exists` UPDATE pada `table_name IN (...)` | mencakup ketiga tabel |
| 30 | reviews tanpa DELETE klien | `not exists` DELETE grantee anon+auth | UPDATE tetap ada (soft-delete) |
| 31 | 7 fungsi definer owner+search_path | `count(*) = 7` atas 7 nama + `prosecdef` + `proowner = 'postgres'::regrole` + `proconfig @> array['search_path=']` | daftar 7 nama **tak** memuat `library_entry_notes` (tercakup check 08–12) — pastikan cakupan 8/8 fungsi definer **kumulatif** antar check; `oid = regrole` sah via cast implisit |

- [ ] **Step 3: Cakupan check 1–20 (struktur + spot-check)**

Read check 01–20.
Expected: tetap identik pra-revisi kecuali komentar; spot-check kunci: 07 (notes tanpa grant SELECT), 02/03 (activities/notifications tanpa policy INSERT), 14 (5 trigger fungsional — daftar nama tak berubah), 16 (`security_invoker` book_rating_summary), 20 (library_entries 4 policy). Pastikan tak ada check yang **bertentangan** dengan revisi (mis. check yang masih mengklaim `books` punya UPDATE policy — tidak ada).

- [ ] **Step 4: Ringkasan dinamis & marker**

Read blok `=== RINGKASAN ===`.
Expected: `count(*)` atas CTE (bukan angka mati); pesan sukses `VERIFY SCHEMA: ALL 31 CHECKS PASSED` muncul dari `count(*)` saat semua pass; pesah gagal menghitung `count(*) filter (where not pass)`.

**Acceptance criteria Task 6:** 31 check struktur benar; tabel semantik 21–31 terpetakan tanpa ❌; cakupan definer 8/8 kumulatif; ringkasan dinamis.

---

### Task 7: Review Dokumentasi — README, SCHEMA_STATE, Plan Doc

**Files:** `db/README.md`, `db/SCHEMA_STATE.md`, `docs/superpowers/plans/execution-task-2-database-plan.md`

- [ ] **Step 1: README — tabel eksekusi vs realitas skrip**

Read baris tabel 002/005/006/007.
Expected: 002 menyebut **insert-only** + **grant eksplisit**; 005 menyebut **aktivitas library hanya dari entri PUBLIC** + **UPDATE hanya kolom `read`**; 006 = **76** test; 007 = **31** checks (dengan daftar cakupan). Cocokkan dengan temuan Task 2–6.

- [ ] **Step 2: README — seksi aturan & bullet**

Expected: seksi `## Aturan grant & integritas (revisi audit 2026-11-08)` berisi tepat 5 aturan (grant eksplisit/anti-drift · books insert-only · aktivitas ⟺ PUBLIC · notif kolom read · statistik tanpa jejak privat); bullet terakhir memuat `dua akun uji + sesi anon` dan `tanpa service_role key`.

- [ ] **Step 3: SCHEMA_STATE — status & marker**

Run: `grep -n "ALL\|applied\|USER_A\|join_date\|Catatan" db/SCHEMA_STATE.md`
Expected: marker `006: ALL NEGATIVE TESTS PASSED (76 pemeriksaan)`; marker `007: VERIFY SCHEMA: ALL 31 CHECKS PASSED`; **semua** baris `applied`/`verified` masih `—` (tidak ada yang ditandai PASSED/dikerjakan); baris 006-catatan memakai `dua profil pertama menurut join_date` (**tanpa** `<USER_A>`); ada catatan `direvisi pasca-audit keamanan 2026-11-08 ... belum ada baris applied`.

- [ ] **Step 4: Plan doc — §1A, §3, keputusan 7**

Run: `grep -n "## 1A. Revisi Audit Keamanan\|insert-only; koreksi operator\|invarian §1A\|hanya kolom \`read\`\|revisi 2026-11-08" docs/superpowers/plans/execution-task-2-database-plan.md`
Expected: §1A ada (tabel 5 temuan A–E); baris §3 `books` UPDATE=**tidak ada**; baris `activities` SELECT=publik invarian §1A; baris `notifications` UPDATE=**hanya kolom `read`**; baris keputusan 7 memuat penajaman PUBLIC.

- [ ] **Step 5: Plan doc — §6, §8, §9 & angka konsisten**

Run: `grep -n "ALL RLS TESTS PASSED\|<USER_A>" docs/superpowers/plans/execution-task-2-database-plan.md; grep -c "76" docs/superpowers/plans/execution-task-2-database-plan.md; grep -n "31 checks PASS\|76 pemeriksaan" docs/superpowers/plans/execution-task-2-database-plan.md`
Expected: **nol** `ALL RLS TESTS PASSED`/`<USER_A>`; §6 memuat 5 baris risiko revisi (aktivitas/poison/notif/agregat/default-privileges); §8 = checklist 006 (76) + 007 (31 checks); §9 langkah 4 tanpa placeholder dengan `(76 pemeriksaan)`.

- [ ] **Step 6: Konsistensi angka lintas dokumen**

Run: `grep -rc "76" db/README.md db/SCHEMA_STATE.md docs/superpowers/plans/execution-task-2-database-plan.md db/scripts/006_negative_tests.sql | grep -v ":0"; grep -rc "31" db/README.md db/SCHEMA_STATE.md docs/superpowers/plans/execution-task-2-database-plan.md db/scripts/007_verify_schema.sql | grep -v ":0"`
Expected: **tidak ada** file yang menyebut angka usang (70/67/39 test sebagai total, 20 checks sebagai total) — grep silang `grep -rn "\b70 pemeriksaan\|39 lama + 31\|20 checks" db/ docs/superpowers/plans/execution-task-2-database-plan.md` → nol.

**Acceptance criteria Task 7:** README/SCHEMA_STATE/plan doc selaras dengan skrip (76/31/marker/aturan); SCHEMA_STATE sepenuhnya `pending`; nol placeholder/marker lama di luar bundle.

---

### Task 8: Verifikasi Silang Klaim BUILD vs Kode Eksak

**Files:** 8 file cakupan + `execution-task-2-security-revision-plan.md` (referensi)

- [ ] **Step 1: Reproduksi seluruh klaim numerik laporan BUILD**

Run kumpulan:
```bash
grep -c "revoke all on table" db/scripts/002_identity_books.sql db/scripts/004_reviews_social.sql db/scripts/005_activity_notifications.sql
grep -c "security definer set search_path = ''" db/scripts/002_identity_books.sql db/scripts/003_library.sql db/scripts/005_activity_notifications.sql
grep -c "l.visibility = 'PUBLIC'" db/scripts/004_reviews_social.sql
grep -c "^select public._t006_expect" db/scripts/006_negative_tests.sql
grep -c "union all select '\|  select '01 " db/scripts/007_verify_schema.sql
```
Expected: **2 / 4 / 2**; **2 / 1 / 5**; **2**; **76**; **31** — identik dengan klaim laporan BUILD. Deviasi dari angka ini = temuan MAJOR.

- [ ] **Step 2: Daftar deviasi terdaftar — pastikan TIDAK ada deviasi lain**

Daftar **lengkap** deviasi yang disetujui pengguna selama BUILD (hanya ini yang sah):
1. AN08 menarget `book_v1` (bukan `entry_priv`);
2. 2 grant anon harness di 006 (`_t006_ids` SELECT, `_t006_results` SELECT+INSERT);
3. SCHEMA_STATE baris catatan 006 → mekanisme `join_date` (bukan `<USER_A>`);
4. Komentar VERIFY 002 → `4 policy (2 profiles + 2 books)` (koreksi typo aritmetika plan);
5. §8 plan doc: penghapusan baris checklist 007 lama (digantikan blok 006+007).

Verifikasi silang: bandingkan blok kode kunci di revision plan vs file aktual — (a) fungsi `trg_library_activity` (identik kecuali disetujui), (b) blok grant 002/004/005 (identik), (c) check 21–31 (identik), (d) tes V01–V18/AN/K/N/S (identik kecuali AN08). **Temuan bila ada deviasi keenam** di luar daftar.

- [ ] **Step 3: Seluruh klaim laporan BUILD yang bersifat semantik diverifikasi ulang**

Ulangi secara independen (tanpa mengutip laporan): anti-bocor aktivitas (Task 4 matriks), integritas review, kolom notif, insert-only buku, statistik PUBLIC — pastikan setiap klaim punya pasangan bukti di Task 2–6. Klaim tanpa pasangan = NEEDS CLARIFICATION.

**Acceptance criteria Task 8:** semua angka reproduksi identik; tepat 5 deviasi terdaftar; setiap klaim semantik berpasangan bukti.

---

### Task 9: Susun Laporan Akhir Review (Report-Only)

**Files:** Tidak ada — output berupa laporan percakapan (atau file baru **hanya bila diminta pengguna**).

- [ ] **Step 1: Kumpulkan temuan dari Task 1–8** dengan format di bagian "Format Laporan Akhir" — setiap temuan: ID, severity, file:area, bukti (command+output / file:baris), ekspektasi vs aktual.

- [ ] **Step 2: Beri verdict per file** (8 baris) — PASS / FAIL / NEEDS CLARIFICATION.

- [ ] **Step 3: Terapkan aturan gate** (bagian bawah) → verdict akhir.

- [ ] **Step 4: Sampaikan laporan + BERHENTI** — tunggu persetujuan pengguna sebelum tahap berikutnya (perbaikan = tahap terpisah dengan otorisasi sendiri). **Jangan memperbaiki apa pun.**

**Acceptance criteria Task 9:** laporan memuat semua bagian wajib; nol perubahan file; gate ditentukan aturan, bukan opini.

---

## Risiko Review & False Positive / False Negative

| ID | Jenis | Risiko | Mitigasi dalam plan |
|---|---|---|---|
| FP-1 | False positive (lolos) | Verifikasi statis tidak bisa membuktikan perilaku runtime (evaluasi RLS, urutan fire trigger, efek grant PG aktual) — kondisi bisa salah walau teks benar | Tandai sebagai **sisa risiko statis** di laporan; satu-satunya bukti penuh = eksekusi 006/007 (tahap terpisah) |
| FP-2 | False positive (lolos) | `expect_fail`/`expect_0rows` menerima `23505`/`23514` — test bisa "lulus" karena constraint salah alih-alih penolakan hak | Catat sebagai OBSERVATION per test yang relevan (B06, A09, A11); jangan perbaiki |
| FP-3 | False positive (lolos) | Check 007 memakai pola string (`like`, jumlah kemunculan) — bisa lolos/padahal salah ejaan atau bentuk viewdef berbeda di PG tertentu | Reviewer memeriksa logika heuristik (divisor, ejaan `PUBLIC`) dan menandai ⚠/temuan bila rapuh |
| FP-4 | False positive (lolos) | `expect_fail` mencatat 42501 tanpa memverifikasi **pesan/objek** mana yang menolak (tabel vs kolom vs policy) | Cross-check manual: telusuri grant/policy yang menimbulkan 42501 per test (Task 5 Step 6–7) |
| FN-1 | False negative (temuan terlewat) | Pola grep `'[ABPSKVN][0-9][0-9]'` tak menangkap `AN01–AN08` → hitungan salah | Step 1 Task 5 memakai penghitungan per-prefix + pola `AN` terpisah |
| FN-2 | False negative | Bundle diindentasi → diff 001/003 penuh noise | Task 1 Step 4 memakai normalisasi whitespace yang terbukti (hanya beda fence) |
| FN-3 | False negative | Review ter-anchor pada klaim/laporan BUILD (confirmation bias) | Global constraint anchoring guard; Task 8 memaksa reproduksi angka dari file |
| FN-4 | False negative | Deviasi tak terdaftar tersembunyi di bagian jarang dibaca | Task 8 Step 2 membandingkan blok kode eksak revision plan vs aktual |
| R-1 | Residual | Asumsi default privileges Supabase (grant saat CREATE) tak bisa diverifikasi statis dari repo | Catat sebagai asumsi; ditangani check 22/24–30 **setelah** SQL dijalankan di Supabase |
| R-2 | Residual | Urutan eksekusi 001→007 manual bisa keliru di tangan operator | Di luar cakupan review statis; diatur README + SCHEMA_STATE |

---

## Format Laporan Akhir Review

```markdown
# REVIEW REPORT — Execution Task 2 Security Revision (Statis)

**Tanggal:** <tanggal> · **Reviewer:** <agent> · **Acuan:** execution-task-2-database-plan.md (+ §1A)

## A. GATE
**PASS | FAIL | NEEDS CLARIFICATION**

## B. VERDICT PER FILE
| # | File | Verdict | Catatan singkat |
|---|---|---|---|
| 1 | db/scripts/002_identity_books.sql | PASS/FAIL/NEEDS CLARIFICATION | … |
| … | (8 baris — semua file cakupan) | | |

## C. TEMUAN
| ID | Severity | File:area | Ekspektasi (spesi) | Aktual (bukti) | Status |
|---|---|---|---|---|---|
| R2-01 | BLOCKER/MAJOR/MINOR/OBSERVATION | … | … | `cmd` → output / `file:baris` | open |

## D. BUKTI VERIFIKASI
(Perintah + output kunci untuk tiap Task 1–8 — ringkas, dapat direproduksi.)

## E. SISA RISIKO STATIS
(Daftar FP/FN/Residual yang diterima tanpa perbaikan.)
```

**Definisi severity:**
- **BLOCKER** — saat SQL dijalankan nanti akan gagal total atau kebocoran keamanan nyata (mis. skrip 006 abort, privasi PRIVATE bocor).
- **MAJOR** — test/check tidak mendeteksi kondisi yang diklaim, atau dokumen/skrip saling bertentangan sedemikian rupa sehingga operator salah menindak.
- **MINOR** — inkonsistensi kosmetik/typo tanpa dampak perilaku.
- **OBSERVATION** — keterbatasan desain yang diketahui/risiko residu (tidak menghalangi PASS).

**Aturan gate:**
- **FAIL** bila ada ≥1 temuan BLOCKER atau MAJOR yang **terkonfirmasi**.
- **NEEDS CLARIFICATION** bila ada temuan yang buktinya tidak cukup untuk memutuskan (ambiguitas spesi/kode) — sebutkan pertanyaan spesifik ke pengguna.
- **PASS** hanya bila seluruh 8 file verdict PASS, nol BLOCKER/MAJOR, dan seluruh acceptance criteria Task 1–8 terpenuhi dengan bukti.
- OBSERVATION/MINOR tetap dilaporkan walau gate PASS.

**Aturan temuan (diulang — mengikat):** temuan **hanya dilaporkan, tidak diperbaiki** selama tahap review; tidak ada perubahan file, tidak ada eksekusi SQL, tidak ada penandaan SCHEMA_STATE, tidak ada commit. Perbaikan (bila pengguna menyetujui) = tahap terpisah setelah REVIEW/APPROVAL.

---

## Self-Review (skill)

1. **Spec coverage:** Tujuan & batasan → header + Global Constraints; daftar file & area → Peta File; langkah berurutan verifiable → Task 1–9 (setiap step punya Run/Expected); acceptance criteria per langkah → blok di akhir tiap Task; risiko FP/FN → tabel Risiko; format laporan → bagian Format Laporan; aturan report-only → Aturan Temuan + pengulangan di Format. Fokus pemeriksaan (trigger, review integrity, grants, notif, statistik, fixture/sesi/transaksi, ketepatan test, 31 checks, konsistensi dokumen, scope control) → Task 4, 4-Step4, 2/3/4-Step5, 4-Step5, 3, 5, 6, 7, 1. ✔
2. **Placeholder scan:** tanpa TBD/TODO; setiap step berisi perintah + expected eksak (angka 76/31/6-6-6-5/2-4-2/2-1-5 diturunkan dari spesifikasi). ✔
3. **Konsistensi:** angka 76 = 21+13+4+4+1+18+8+7 (Task 5 Step 1 konsisten dengan Task 6/7/8); check 31 = 30 union + 1; daftar 5 deviasi (Task 8) = yang disetujui pengguna saat BUILD; pola grep AN diperhitungkan (FN-1). ✔
