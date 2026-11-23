# BookRate Database (Prisma Migrate + SQL, Dashboard-first untuk SQL)

Sumber kebenaran skema adalah **hibrida** (ADR 0002):

- **Struktur yang didukung Prisma** (enum, tabel, kolom, FK internal, unique constraint, index standar) → **Prisma Migrate**, dijalankan dari mesin dev dengan koneksi migrasi di `packages/db/prisma.config.ts` (Prisma 7; `directUrl` sudah dihapus dari schema) — role migrasi terpisah, bukan role runtime. **Check constraint (standar maupun expression) TIDAK didukung PSL Prisma 7 → tetap milik SQL.** Versi Prisma: kandidat pin `prisma@7.10.1` + `@prisma/client@7.10.1` + adapter `@prisma/adapter-pg` (pin major 7, **patch = UNVERIFIED**) + `dotenv` (wajib untuk `prisma.config.ts`) — menunggu persetujuan OD-1; jangan install tanpa pin — tag `latest` CLI = RC v8.
- **Objek PostgreSQL khusus** — RLS, policies, grants, triggers, functions, views, partial index, **semua check constraint**, expression check, FK ke `auth.users` — **hanya lewat file SQL di `scripts/`**, dieksekusi **manual** melalui Supabase Dashboard → SQL Editor. Prisma tidak mengelola objek-objek ini dan migration generation tidak boleh menghapusnya.

Tanpa Supabase CLI, Docker, local Supabase, Edge Functions, atau custom API untuk MVP. Skrip `001`–`007` adalah kontrak keamanan yang **tidak diubah** (76 assertions di 006, 31 checks di 007).

## Urutan eksekusi (wajib berurutan)

| # | Skrip | Isi ringkas |
|---|---|---|
| 1 | `scripts/001_enums.sql` | 4 enum (reading_status, activity_type, notification_type, library_visibility); pg_trgm ditunda |
| 2 | `scripts/002_identity_books.sql` | `profiles` + trigger signup + `books` (dedup identifier, **insert-only utk klien**) + RLS + **grant eksplisit** |
| 3 | `scripts/003_library.sql` | `library_entries` (visibility, progress, notes) + RLS + hak kolom notes + fungsi `library_entry_notes` |
| 4 | `scripts/004_reviews_social.sql` | `reviews` (soft delete), `likes`, `comments`, `follows` + view `book_rating_summary` + `profile_stats` + RLS |
| 5 | `scripts/005_activity_notifications.sql` | `activities`, `notifications` (insert hanya trigger; **aktivitas library hanya dari entri PUBLIC**; notifikasi: UPDATE hanya kolom `read`) + trigger + RLS + grant eksplisit |
| 6 | `scripts/006_negative_tests.sql` | 76 negative authorization test (2 akun uji + anon); satu transaksi, diakhiri ROLLBACK (nol residu) |
| 7 | `scripts/007_verify_schema.sql` | Audit akhir 31 checks: RLS 9 tabel, policy, grant eksplisit per tabel, kolom notifikasi, fungsi definer (owner/proconfig), ketiadaan policy UPDATE books, stats hanya PUBLIC |

## Aturan kerja

1. Sebelum Run: salin seluruh isi skrip → SQL Editor → **Run**; baca blok `-- VERIFY`.
2. Setelah sukses/tidak: perbarui `../SCHEMA_STATE.md` (tanggal + hasil).
3. **Perubahan skema hanya lewat skrip di repo** — jangan mengubah skema langsung dari Table Editor UI (anti-drift).
4. Berhenti pada error; jangan lanjut ke nomor berikutnya.
5. Sebelum skrip besar pada project yang sudah berisi data: gunakan backup Dashboard.
6. Gate V2: `006` (semua asersi PASS) + `007` (audit lolos) = Execution Task 2 selesai → laporkan, jangan mulai Execution 3 tanpa persetujuan.
7. **Pembagian jalur (ADR 0002):** perubahan struktur oleh Prisma Migrate tidak menggantikan skrip SQL untuk objek keamanan — setelah Prisma migration pun, jalankan ulang skrip SQL yang relevan (idempoten, `if not exists`) **dan pasangkan dengan diff** (`prisma migrate diff` hosted-vs-schema, flag Prisma 7 — verifikasi via `--help`) agar drift kolom terdeteksi, lalu verifikasi dengan `007`. **Jangan pernah** menjalankan `prisma migrate` yang menghasilkan DROP objek yang tidak dikelola Prisma (policy/grant/trigger/function/view/check constraint) tanpa review manual SQL hasil generate.
8. **Tabel baru wajib RLS (ADR 0002 Decision 12):** setiap tabel yang lahir dari Prisma Migrate wajib `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + `REVOKE ALL … FROM anon, authenticated` lalu grant minimal (default-deny) **sebelum dipakai**, dan diverifikasi (`pg_policies` + `007`). Alasan: Prisma tidak bisa menulis `ENABLE ROW LEVEL SECURITY` dan `007` hanya meng-assert 9 tabel lama — tabel baru tidak otomatis terpantau.
9. **Larangan reset & aturan henti (ADR 0002 Decision 13):** `prisma migrate reset` dan menerima auto-reset/prompt drift `migrate dev` pada database hosted **DILARANG tanpa persetujuan tertulis**. Bila diff menunjukkan drift atau objek/tabel yang tidak dikenal → **HENTIKAN**, laporkan, jangan `resolve`/apply/reset sampai persetujuan.
10. **Akses aplikasi hanya lewat helper (ADR 0002 Decision 14):** aplikasi web/mobile **tidak pernah** membuat atau meng-import `PrismaClient` — instance hanya hidup di `packages/db/src/client.ts` (tidak diekspor dari API publik paket), dan seluruh akses data user melewati `withUserContext`. `apps/web/src/lib/db.ts`, bila ada, hanya re-export helper. Ditegakkan statis (grep) di Task 8.

## Aturan grant & integritas (revisi audit 2026-11-08)

1. **Grant eksplisit, bukan default privileges** — setiap tabel di-`REVOKE ALL` dari `anon`/`authenticated` lalu di-grant minimal (lihat matriks di plan revisi). **Kolom baru wajib ditambahkan ke daftar grant** (anti-drift) — 007 memantau.
2. **`books` insert-only untuk klien** — pencarian = Google Books/Open Library live dari client (**tanpa API secret di client**); simpan = `INSERT ... ON CONFLICT DO NOTHING` (first-writer-wins); **koreksi metadata = operator via SQL Editor** (owner bypass RLS). Tanpa policy/grant UPDATE/DELETE untuk client.
3. **Aktivitas library ⟺ entri PUBLIC** — trigger tidak pernah membuat aktivitas publik dari entri PRIVATE; `PUBLIC → PRIVATE`/`DELETE` entri publik mem-purge aktivitas library tipe `BOOK_*`/`READING_PROGRESS_UPDATED` (aktivitas review tetap); `PRIVATE → PUBLIC` tanpa aktivitas retroaktif.
4. **Notifikasi: UPDATE hanya kolom `read`** — `notification_type`/`actor_id`/`user_id`/dst. hanya bisa ditulis trigger definer; RLS tetap membatasi baris ke milik sendiri.
5. **Statistik publik tanpa jejak privat** — `profile_stats.books_read`/`currently_reading` hanya menghitung entri `PUBLIC`; statistik pribadi pemilik dihitung klien dari baris miliknya via RLS.

## Keamanan yang melekat pada skrip

- RLS aktif di 9/9 tabel sejak pembuatan (default-deny).
- Aktivitas & notifikasi hanya dari trigger (SECURITY DEFINER, `search_path = ''`); client tanpa policy INSERT.
- Catatan pribadi (`library_entries.notes`) tidak dapat di-SELECT dari tabel; hanya via fungsi `library_entry_notes(uuid)` dengan cek kepemilikan.
- Review: soft delete `deleted_at`; view rating hanya menghitung review aktif.
- Statistik profil: hanya angka agregat publik (`profile_stats`), tanpa detail library privat.
- Negative test memakai SQL Editor + dua akun uji + sesi anon (keputusan pengguna 2026-11-08) — tanpa service_role key.
