# Execution Task 2 — Core Database Schema & RLS (Dashboard-First)

**Status:** BUILD ARTIFACTS READY — artefak siap direview; SQL belum dijalankan; menunggu eksekusi manual via Supabase Dashboard
**Date:** 2026-11-08 (keputusan final pengguna) · rencana awal 2026-11-06
**Sumber:** PRD FR-01…FR-12 + NFR, ROADMAP (Execution 2, baris 18–19/88/96–100/114), ADR 0001, `bookrate-roadmap-alignment.md`, keputusan final pengguna 2026-11-08.
**Batasan:** tanpa menjalankan SQL, tanpa menyentuh hosted Supabase, tanpa install tool, tanpa mengubah source app, tanpa commit, tanpa lanjut ke Execution 3.

## 1. Keputusan final (acuan — menggantikan seluruh opsi terbuka plan lama)

| # | Keputusan |
|---|---|
| 1 | **Library visibility:** tiap entri punya `visibility` PUBLIC/PRIVATE; pemilik bisa mengubah; **catatan pribadi (`notes`) selalu hanya terlihat pemilik** (tersembunyi bahkan pada entri PUBLIC) |
| 2 | **Book metadata:** Google Books / Open Library; disimpan ke `books` dengan **dedup via external identifier** (google_books_id, openlibrary_id, isbn10, isbn13 — unique) |
| 3 | **Review soft delete:** kolom `deleted_at`; review terhapus **tidak tampil di tabel maupun view** dan **tidak masuk perhitungan rating**; tanpa kebijakan DELETE (hanya soft-delete via UPDATE) |
| 4 | **Activities & notifications:** hanya dibuat **database trigger** (SECURITY DEFINER); **tanpa policy INSERT untuk client** — anti-forgery |
| 5 | **Rating aggregate:** **view** `book_rating_summary` yang hanya menghitung review aktif (`deleted_at is null`) |
| 6 | **pg_trgm: DITUNDA** — tidak dibuat sekarang (dicatat di 001) |
| 7 | **Profile statistics:** agregat **publik** via view `profile_stats` — hanya angka; **tidak membocorkan detail entri privat**; **revisi 2026-11-08:** `books_read`/`currently_reading` hanya menghitung entri **PUBLIC** (jejak privat tidak dihitung — alasan §1A-D) |
| 8 | **RLS testing:** kombinasi **SQL Editor + dua akun uji** (login nyata di Dashboard) |

Arsitektur: Supabase Hosted · Dashboard-first · **tanpa** Supabase CLI, Docker, local Supabase, Edge Functions, custom API untuk MVP · file SQL di repo = source of truth · status penerapan dicatat di `db/SCHEMA_STATE.md`.

## 1A. Revisi Audit Keamanan (2026-11-08 — sebelum SQL dijalankan)

Lima temuan audit → keputusan (penajaman, bukan perubahan arsitektur; produk 1–8 tetap):

| # | Temuan | Keputusan hasil revisi | Alasan |
|---|---|---|---|
| A | Private activity leakage | **Invarian:** aktivitas library (BOOK_*/READING_PROGRESS_UPDATED) ada ⟺ entri ada DAN PUBLIC; PRIVATE→PUBLIC tanpa retroaktif; PUBLIC→PRIVATE & DELETE entri publik = purge tipe library; aktivitas review tak di-purge; feed following (hanya aktivitas dari akun yang diikuti) | Aktivitas dari entri PRIVATE membocorkan judul/fakta bacaan; toggle visibility bukan peristiwa membaca; purge bertipe menjaga konten review yang memang publik |
| B | Book metadata integrity | Klien **INSERT-only** (`ON CONFLICT DO NOTHING`, first-writer-wins); tanpa policy/grant UPDATE/DELETE; koreksi = operator via SQL Editor; pencarian provider live dari client tanpa API secret | Update bebas = vandalisme metadata bersama; Dashboard-first sudah menyediakan jalur operator |
| C | Notification column permissions | Grant `UPDATE (read)` saja + RLS own dipertahankan; anon nol grant | Menjaga integritas baris buatan trigger; notifikasi = data privat butuh login |
| D | Profile statistics privacy | `books_read`/`currently_reading` **hanya entri PUBLIC**; stats pribadi = klien hitung dari baris RLS sendiri (tanpa view kedua) | Penajaman keputusan 7: "tanpa bocor detail privat" mencakup jejak agregat koleksi privat; angka publik wajib hanya berasal dari jejak publik |
| E | Explicit grants | Pola `REVOKE ALL` → grant minimal per tabel/anon/authenticated di 002/004/005; 007 audit 31 checks termasuk grant matrix & fungsi definer | Default privileges Supabase terlalu luas; RLS + privilege SQL wajib sama-sama membatasi |

Matriks §3 di bawah sudah diselaraskan dengan keputusan ini.

## 2. Arsitektur database

**Sembilan tabel + dua view** (tabel ke-10 tidak ditambahkan; `notes` aman via hak kolom + fungsi):

```
auth.users ──1:1── profiles(id PK, username UNIQUE)
books (referensi publik, dedup identifier)
 ├── library_entries UNIQUE(user_id, book_id), visibility, progress CHECK 0–100, notes
 ├── reviews UNIQUE partial (user_id, book_id) WHERE deleted_at IS NULL, rating CHECK 0.5–5 step 0.5
 │    ├── likes PK(review_id, user_id)
 │    │    └── comments (content CHECK 1–5000)
 ├── activities  (trigger-only insert; 6 tipe enum)
 └── notifications (trigger-only insert; 3 tipe enum, is_read)
follows PK(follower_id, following_id) CHECK follower ≠ following
```

**View:**
- `book_rating_summary(book_id, rating_count, avg_rating)` — `security_invoker = on`, hanya review aktif (keputusan 5).
- `profile_stats(profile_id, books_read, reviews_count, followers_count, following_count, currently_reading)` — agregat server-side (owner view; hanya angka, tanpa baris detail — keputusan 7).

**Constraint/wajib dijaga di SQL:** FK semua relasi; `library_entries` unique + progress range; `reviews` interval rating `round(rating*2)=rating*2` + range 0.5–5.0 + partial unique 1 review aktif; `follows` no-self; `comments` panjang konten; `books` minimal satu identifier + unique per identifier; `profiles.username` unik + panjang 3–30.

**Index:** library(user_id) · reviews(book_id) active, reviews(user_id) · likes(review_id) · comments(review_id) · follows(follower_id), follows(following_id) · activities(created_at DESC), activities(user_id, created_at DESC) · notifications(user_id, is_read, created_at DESC) · books unique per identifier.

**Trigger (semua `SECURITY DEFINER`, `search_path = ''`, schema-qualified):**
| Trigger | Event | Hasil |
|---|---|---|
| `on_auth_user_created` | INSERT auth.users | buat `profiles` (username dari meta / fallback unik) |
| `*_set_updated_at` | UPDATE | isi `updated_at` |
| `trg_reviews_activity` | INSERT reviews | activity: rating-only → `RATING_CREATED`, berkonten → `REVIEW_CREATED*` |
| `trg_library_activity` | INSERT/UPDATE library | `BOOK_ADDED` / `BOOK_STARTED` / `BOOK_FINISHED` / `READING_PROGRESS_UPDATED` |
| `trg_likes_notification` | INSERT likes | notif `REVIEW_LIKED` ke pemilik review (kecuali diri sendiri) |
| `trg_comments_notification` | INSERT comments | notif `REVIEW_COMMENTED` ke pemilik review (kecuali diri sendiri) |
| `trg_follows_notification` | INSERT follows | notif `NEW_FOLLOWER` ke penerima follow |

\*Pemetaan event review: rating tanpa teks → `RATING_CREATED`; ada judul/konten → `REVIEW_CREATED` (catatan implementasi, bukan keputusan produk).

**Keamanan trigger (keputusan teknis):** fungsi definer dijalankan sebagai owner tabel (`postgres` dari SQL Editor) → bypass RLS atas tabel miliknya sendiri untuk keperluan insert aktivitas/notifikasi; `search_path` dikosongkan + referensi schema-qualified (anti search-path hijack); klien **tidak** punya policy INSERT di `activities`/`notifications`; memanggil fungsi trigger langsung dari klien error ("trigger functions can only be called as triggers") — diverifikasi di 007. Fungsi `library_entry_notes(uuid)` = satu-satunya fungsi EXECUTE untuk klien: SECURITY DEFINER dengan **cek kepemilikan di dalam fungsi** (`user_id = auth.uid()`), di-revoke dari `public`/`anon`, di-grant ke `authenticated` — **SECURITY DEFINER tidak dianggap otomatis aman**; ada di 007 untuk audit owner/proconfig.

**Hak kolom (keputusan 1 — catatan pribadi):** `REVOKE SELECT` tabel `library_entries` dari `anon`/`authenticated`, lalu `GRANT SELECT` hanya kolom non-notes; pemilik membaca/menulis notes via UPDATE (grant kolom notes untuk UPDATE) dan membaca via `library_entry_notes()`. Tidak ada policy yang terlalu luas: UPDATE/DELETE/INSERT selalu `user_id = auth.uid()`.

## 3. RLS per tabel (default-deny — semua tabel `ENABLE ROW LEVEL SECURITY`)

| Tabel | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| profiles | publik | **tidak ada** (trigger signup saja) | own | **tidak ada** |
| books | publik | authenticated (dedup via unique) | **tidak ada** (insert-only; koreksi operator via SQL Editor) | **tidak ada** |
| library_entries | own **atau** visibility=PUBLIC (kolom tanpa notes) | own | own (ubah visibility/progress/status/notes) | own |
| reviews | `deleted_at IS NULL` | own | own + aktif (edit / soft-delete) | **tidak ada** (soft-delete only) |
| likes | hanya di atas review aktif | own + review aktif | — | own |
| comments | hanya di atas review aktif | own + review aktif | **tidak ada** | own |
| follows | publik | own + no-self | — | own (unfollow) |
| activities | publik (hanya aktivitas dari entri PUBLIC & review publik — invarian §1A) | **tidak ada** (trigger only) | **tidak ada** | **tidak ada** |
| notifications | own | **tidak ada** (trigger only) | own, **hanya kolom `read`** (grant kolom + RLS own) | **tidak ada** |

`auth.uid()` dipakai bentuk `(select auth.uid())` agar evaluasi per-baris stabil. Tidak ada policy dengan `using (true)` yang membuka tulis; hanya SELECT publik pada profil/buku/review/follow yang memang publik per PRD.

## 4. Urutan eksekusi via Supabase Dashboard (manual)

| # | Langkah (Dashboard → SQL Editor) | Gate sebelum lanjut |
|---|---|---|
| A | **Prasyarat:** project Supabase hosted; buat **2 akun uji** (Authentication → Users); buka SQL Editor | Konfirmasi pengguna |
| B | Jalankan `001_enums.sql` → VERIFY enum | Bersih → catat di SCHEMA_STATE |
| C | `002_identity_books.sql` → VERIFY tabel/trigger/RLS | Negative test profil+buku (sebagian di 006) |
| D | `003_library.sql` → VERIFY | Lanjut |
| E | `004_reviews_social.sql` → VERIFY (constraint + 2 view) | Lanjut |
| F | `005_activity_notifications.sql` → VERIFY trigger | Lanjut |
| G | `006_negative_tests.sql` (isi 2 UUID uji di header) — seluruh asersi dalam satu transaksi lalu **ROLLBACK** (nol residu) | **Semua asersi PASS** |
| H | `007_verify_schema.sql` → audit relrowsecurity/policy/grant/fungsi | **V2 lulus = Execution 2 selesai** → laporkan, berhenti sebelum Execution 3 |

Setelah tiap langkah: perbarui `db/SCHEMA_STATE.md` (tanggal + hasil VERIFY). Perubahan skema **hanya** lewat skrip di repo (aturan anti-drift).

## 5. Artefak yang dibuat/diubah (BUILD ini)

**Baru:** `db/README.md`, `db/SCHEMA_STATE.md`, `db/scripts/001…007` (9 file).
**Diubah:** dokumen ini (rewrite final decisions); ADR §Decision (tegas: tanpa CLI/Docker/local/Edge Functions, Dashboard-first, `db/SCHEMA_STATE.md`); ROADMAP baris 114 (Open Decision → **Resolved**).
**Tidak disentuh:** `docs/PRD.md` (tidak ada alasan perubahan), source app, konfigurasi, lockfile.

## 6. Risiko & konsekuensi (termasuk tanpa migration tracking)

| Risiko | Mitensi |
|---|---|
| Tanpa migration tracking otomatis — skrip bisa terlewat/diulang | `db/SCHEMA_STATE.md` + skrip idempoten (DO-guard) + 007 audit |
| Tanpa diff otomatis Dashboard vs repo (drift) | Aturan: perubahan hanya via skrip; 007 berkala |
| Tanpa rollback down | Forward-only; backup Dashboard sebelum skrip besar |
| SQL Editor `set local role` untuk uji bisa dibatasi | Fallback tercatat: login akun uji nyata + query dari app/dashboard (keputusan 8 sudah memperbolehkan kombinasi) |
| `SECURITY DEFINER` disalahgunakan (search_path/owner) | `search_path = ''`, schema-qualified, cek kepemilikan di dalam fungsi, audit 007 (prosecdef/proconfig/owner) |
| Kolom notes bocor via SELECT publik | REVOKE + grant kolom selektif; fungsi notes ber-ownership-check; uji negatif di 006 |
| Client memalsukan aktivitas/notifikasi | Tanpa policy INSERT; hanya trigger; diuji di 006 (INSERT client harus gagal) |
| Aktivitas membocorkan entri PRIVATE | Invarian trigger §1A: aktivitas library hanya dari entri PUBLIC; purge pada PUBLIC→PRIVATE & DELETE; diuji V01–V18 di 006 |
| Buku di-poison client (update metadata) | Klien INSERT-only + `ON CONFLICT DO NOTHING`; tanpa policy/grant UPDATE; koreksi operator via SQL Editor; diuji K01–K04 |
| Notifikasi dimanipulasi kolom | Grant `UPDATE (read)` saja + RLS own; anon nol grant; diuji N01–N04, AN04 |
| Agregat profil membocorkan library privat | `profile_stats` hanya menghitung entri PUBLIC; stats pribadi via RLS client-side; diuji S01, P06 |
| Default privileges Supabase terlalu luas | REVOKE ALL → grant eksplisit di 002/004/005; audit 31 checks di 007 |
| Pemetaan event rating-only vs review berkonten | Heuristik tercatat di §2 — dapat diubah di iterasi UI feed tanpa ubah skema |

## 7. Prasyarat eksekusi (manual pengguna)

1. Project Supabase hosted sudah ada + akses SQL Editor.
2. **Dua akun uji** dibuat di Dashboard (Authentication → Users) — untuk 006.
3. Pemahaman: seluruh eksekusi manual, satu per satu, berurutan 001→007.

## 8. Checklist verifikasi akhir Execution 2

- [ ] 7 skrip + README + SCHEMA_STATE ter-commit (setelah persetujuan commit).
- [ ] Semua skrip sukses di SQL Editor; SCHEMA_STATE semua `applied` + tanggal.
- [ ] 006: seluruh asersi PASS (dua akun + anon, 76 pemeriksaan), rollback bersih.
- [ ] 007: 31 checks PASS (grant eksplisit, stats hanya PUBLIC, notifikasi kolom read, books insert-only, fungsi definer).
- [ ] Toolchain (`lint/typecheck/build`) tetap exit 0.
- [ ] PRD hash identik; ROADMAP masih CRLF; tanpa commit tanpa persetujuan.

## 9. Langkah manual menjalankan skrip (ringkas)

1. Buka Supabase Dashboard → project → **SQL Editor**.
2. Salin seluruh isi `db/scripts/00N_*.sql` → tempel → **Run**.
3. Baca blok `-- VERIFY` di bawah skrip (hasil query tampil di panel).
4. Untuk 006: siapkan 2 akun uji (Authentication → Users); skrip memakai dua profil pertama otomatis (tanpa placeholder). Jalankan — pastikan muncul `ALL NEGATIVE TESTS PASSED: 76 pemeriksaan`.
5. Tandai status di `db/SCHEMA_STATE.md` (tanggal + catatan).
6. Ulangi untuk nomor berikutnya; **berhenti bila ada error** — jangan lanjut.

## 10. Laporan akhir (posisi sekarang)

**Status: ARTEFAK SIAP DIREVIEW.** Tidak ada SQL dijalankan, tidak ada hosted Supabase diakses, tidak ada tool/source/PRD yang berubah, tidak ada commit, Execution 3 belum dimulai. Menunggu review pengguna atas artefak `db/` + pembaruan dokumen, lalu eksekusi manual §9.
