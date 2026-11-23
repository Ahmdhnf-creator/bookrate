# BR-BE-OD2 — Dedicated Prisma Migration Role (Least Privilege)

**Task ID:** BR-BE-OD2  

**File:** `docs/superpowers/plans/BR-BE-OD2-prisma-migration-role.md`  

**Status:** PLAN ONLY — revisi; no implementation, no database changes, no commits  

**Gate:** OD-2 (migration role form) — candidate decision documented here, awaiting explicit user approval  

**Related OD:** OD-3 (baseline strategy), OD-4 (pooler mode) — remain OPEN  

**Approved context:** OD-1 APPROVED (`prisma@7.10.1` + `@prisma/client@7.10.1`); OD-5 APPROVED (`{sub, role}` via `set_config`)

---

## 0. Ringkasan Revisi (dokumen ini)

Revisi ini menanggapi 5 temuan wajib:

| # | Temuan | Lokasi penanganan |

|---|---|---|

| 1 | Ownership existing objects — kemampuan `bookrate_migrate` terhadap tabel milik `postgres`, mengapa `GRANT CREATE ON SCHEMA` tidak cukup untuk `ALTER`/`DROP` objek milik role lain, alternatif desain tanpa mengubah ownership semua objek, strategi migrasi tabel lama vs baru | Bagian 3, 7 |

| 2 | Prisma baseline — strategi baseline untuk hosted DB yang sudah punya 9 tabel + 2 view, tidak ada pembuatan ulang/penghapusan objek, sinkronisasi migration history pertama kali | Bagian 8 |

| 3 | Status SQL 001–007 — membedakan skrip pembentukan schema, perubahan schema, dan verifikasi; tidak menyatakan semua pending tanpa bukti; 006/007 tidak dijalankan | Bagian 2.1, 8 |

| 4 | Privilege — verifikasi kebutuhan ENUM, sequence, schema, tabel; tidak memberikan privilege berlebihan; tidak mengasumsikan `USAGE` + `CREATE` cukup untuk segalanya | Bagian 4 |

| 5 | Connection — pemisahan koneksi migration vs runtime, kebutuhan direct connection dan kompatibilitas Prisma 7, tidak memasukkan secret ke repository | Bagian 5, 6 |

---

## 1. Tujuan dan Scope

### Tujuan

Menentukan dan merancang role database terpisah `bookrate_migrate` untuk Prisma Migrate, dengan hak akses minimum (least privilege), yang terpisah dari role runtime `bookrate_app`. Role ini hanya dipakai untuk operasi migrasi skema (Prisma Migrate) dan **tidak pernah** dipakai untuk request pengguna (runtime).

### Scope (dikelilingi oleh dokumen ini)

| Di dalam scope | Di luar scope (tidak dilakukan oleh plan ini) |

|---|---|

| Desain role `bookrate_migrate` (atribut, privilege, pembatasan) | Pembuatan role di database (`CREATE ROLE`) |

| Pemetaan privilege minimum yang diperlukan Prisma Migrate (khusus objek yang role ini **membuat**) | Pemberian/penangkapan grant (`GRANT`/`REVOKE`) |

| Pemisahan kredensial migrasi vs runtime di `prisma.config.ts` dan `DATABASE_URL` | Instalasi dependensi Prisma (`prisma@7.10.1`, adapter) |

| Strategi baseline untuk DB hosted yang sudah memiliki objek SQL | Menjalankan Prisma Migrate atau migrasi apa pun |

| Kompatibilitas dengan SQL 001–007 dan 007 (31 checks) | Mengubah konfigurasi environment atau `.env` |

| Proteksi RLS: role migrasi bukan boundary RLS untuk data pengguna | Mengubah ownership objek tabel/view/function |

| Langkah verifikasi read-only dan rollback (dokumentasi prosedur) | Commit atau implementasi apa pun |

### Batasan keras (dipatuhi oleh dokumen ini)

- Tidak membuat role (`CREATE ROLE` dilarang).

- Tidak menjalankan `ALTER ROLE`, `GRANT`, `REVOKE`, atau perubahan database lainnya.

- Tidak menjalankan Prisma Migrate.

- Tidak menginstal dependensi.

- Tidak mengubah `db/scripts/001`–`007`.

- Tidak mengubah ownership objek database.

- Tidak mengubah konfigurasi environment.

- Tidak membuat commit git.

- Tidak memulai build atau implementasi.

---

## 2. Kondisi Database Saat Ini (dari dokumentasi, belum diverifikasi langsung)

### 2.1 Status SQL 001–007 (bedakan kategori, janganAnggap semua pending sebagai fakta DB)

`db/SCHEMA_STATE.md` mencatat semua skrip 001–007 sebagai `pending` (belum ada baris `applied`). **Ini adalah catatan berkas, bukan bukti kondisi DB nyata.** Catatan SCHEMA_STATE.md baris 5 secara eksplisit: *"Isi database hosted belum diverifikasi — jangan anggap kosong."* Oleh karena itu, plan ini **tidak menyatakan** bahwa semua skrip belum dijalankan di DB hosted; catatan pending hanya dipakai sebagai indikasi yang perlu diverifikasi melalui query read-only (paket query sebelumnya) sebelum baseline.

| Skrip | Kategori | Isi ringkas | Dijalankan? |

|---|---|---|---|

| `001_enums.sql` | Pembentukan schema | 4 ENUM (reading_status, activity_type, notification_type, library_visibility); pg_trgm ditunda | Status `pending` di SCHEMA_STATE; DB belum diverifikasi |

| `002_identity_books.sql` | Pembentukan schema | `profiles` + trigger signup + `books` + RLS + grant eksplisit | Status `pending` di SCHEMA_STATE; DB belum diverifikasi |

| `003_library.sql` | Pembentukan schema | `library_entries` + RLS + hak kolom notes + fungsi `library_entry_notes` | Status `pending` di SCHEMA_STATE; DB belum diverifikasi |

| `004_reviews_social.sql` | Pembentukan schema | `reviews`, `likes`, `comments`, `follows` + view `book_rating_summary`, `profile_stats` + RLS | Status `pending` di SCHEMA_STATE; DB belum diverifikasi |

| `005_activity_notifications.sql` | Pembentukan schema | `activities`, `notifications` + trigger + RLS + grant eksplisit | Status `pending` di SCHEMA_STATE; DB belum diverifikasi |

| `006_negative_tests.sql` | Verifikasi (tes otorisasi negatif) | 76 assertions, satu transaksi diakhiri ROLLBACK | **Tidak boleh dijalankan** oleh agent ini (batasan keras) |

| `007_verify_schema.sql` | Verifikasi (audit akhir) | 31 checks: RLS 9 tabel, policy, grant, fungsi definer (owner `postgres`) | **Tidak boleh dijalankan** oleh agent ini (batasan keras) |

**Pembedaan kunci:** 001–005 adalah skrip **pembentukan schema** (membuat tabel, view, fungsi, trigger, policy, grant). 006 dan 007 adalah skrip **verifikasi** (tidak membentuk schema; 006 tes otorisasi, 007 audit akhir). Kedua kategori terakhir **tidak boleh dijalankan** dalam fase ini.

### 2.2 Objek yang diharapkan ada (berdasarkan isi skrip 001–005, belum diverifikasi di DB nyata)

| Kategori | Jumlah (harapan) | Sumber |

|---|---|---|

| Tabel `public` | 9: profiles, books, library_entries, reviews, likes, comments, follows, activities, notifications | 007:11-18 |

| View `public` | 2: book_rating_summary, profile_stats | 007:41-43 |

| ENUM `public` | 4: reading_status, activity_type, notification_type, library_visibility | 007:36-39 |

| Fungsi `public` | 8: set_updated_at, handle_new_user, library_entry_notes, trg_review_activity, trg_library_activity, trg_like_notification, trg_comment_notification, trg_follow_notification | 007:80-92, 185-195 |

| Trigger publik (non-internal) | 9+ (termasuk signup di auth.users) | 007:28-33 |

| Indeks | ~13, termasuk partial `reviews_one_active_per_book` | 004:28-34, 007:45-46 |

| Policy RLS | ~23 | 007:22-25 |

| Check constraint | ~10 | 007:123-126 |

| FK ke `auth.users` | 1: profiles.id | 002:8 |

### 2.3 Persyaratan ownership dari SQL 007 (tercantum eksplisit dalam skrip, bukan asumsi)

| Check | Baris 007 | Objek | Syarat owner |

|---|---|---|---|

| #11 | 89-92 | `library_entry_notes` | `owner = 'postgres'` |

| #31 | 185-195 | 7 fungsi (set_updated_at, handle_new_user, trg_*) | `owner = postgres` + `prosecdef` + `search_path=''` |

**Konsekuensi:** 8 fungsi khusus tersebut **harus tetap dimiliki `postgres`**. Role `bookrate_migrate` **tidak boleh** menjadi owner fungsi ini. 007 tidak memeriksa owner tabel/view/sequence → kebijakan ownership untuk kategori itu ditentukan oleh plan ini (bagian 7).

### 2.4 Atribut role `postgres` (dari catatan pengguna, belum diverifikasi ulang di DB nyata)

- `rolbypassrls = true` (bypass RLS)

- `rolsuper = false` (bukan superuser)

- `postgres` adalah owner default objek Supabase dan role yang diharapkan menjalankan 007 (`007:3`: "Jalankan … sebagai postgres (SQL Editor default)").

### 2.5 Konfigurasi migrasi saat ini (repo, belum ada)

- `packages/db/prisma.config.ts` → **belum ada** (dibuat di Task 3/4, gate OD-1 + OD-3).

- `DATABASE_URL` → tidak ada di file konfigurasi repo.

- Dependensi Prisma → belum terpasang (OD-1 disetujui, instalasi tertunda).

- → Belum ada koneksi migrasi yang terkonfigurasi; OD-2 akan menentukan isi `datasource.url`.

---

## 3. Desain Role `bookrate_migrate`

### Atribut role (kandidat, belum dibuat)

| Atribut | Nilai | Alasan |

|---|---|---|

| Nama | `bookrate_migrate` | Terpisah dari `bookrate_app` (runtime) dan `postgres` |

| LOGIN | `true` | Prisma Migrate perlu login untuk menjalankan DDL |

| NOINHERIT | `true` | Privilege grup hanya tercapai via `SET ROLE`, tidak mewarisi otomatis (ADR Decision 7 pola) |

| NOBYPASSRLS | `true` | Tidak boleh bypass RLS — role migrasi bukan security boundary untuk data pengguna |

| NOSUPERUSER | default | Tidak perlu superuser untuk migrasi skema |

| NOCREATEDB / NOCREATEROLE | default | Tidak perlu membuat database/role lain |

| NOREPLICATION | default | Tidak perlu replikasi |

| Password | Di-set di luar repo (Dashboard / `ALTER ROLE` manual) | Tidak pernah di-commit ke repo (ADR Decision 7 pola) |

| Membership | **Tidak** anggota `postgres`/`authenticated`/`service_role`; `pg_read_all_stats` opsional (verifikasi) | Role migrasi bukan runtime, tidak butuh akses data pengguna |

### Posisi dalam arsitektur

```

postgres (bypassrls, non-superuser)

   ├── pemilik 8 fungsi SQL 007 (TETAP)

   ├── owner 9 tabel + 2 view + objek SQL 001–005 (jika skrip dijalankan sbg postgres)

   └── jalankan 001–007 via SQL Editor (manual)

bookrate_migrate (dedicated, least privilege)

   └── Prisma Migrate hanya: CREATE/USAGE pada schema public untuk OBJEK BARU yang didefinisikan schema.prisma

       Tidak mengubah objek milik postgres (tabel/view/fungsi lama)

bookrate_app (runtime, NOINHERIT NOBYPASSRLS)

   └── via withUserContext: SET LOCAL ROLE authenticated + set_config(request.jwt.claims)

```

### Langkah dalam transaksi Prisma (runtime, bukan migrasi)

Tidak ada koneksi dari `bookrate_migrate` ke alur runtime. Runtime tetap:

1. `SET LOCAL ROLE authenticated;`

2. `SELECT set_config('request.jwt.claims', '{"sub":"<uuid>","role":"authenticated"}', true);`

3. Query lewat handle transaksi `tx`

4. `COMMIT`/`ROLLBACK` menghapus konteks (transaction-scoped)

---

## 4. Privileke Minimum yang Diperlukan

Privilege ini **diusulkan dalam plan, belum diberikan** (GRANT dilarang oleh batasan keras). Pengajuan dilakukan oleh user setelah review.

### 4.1 Privilege untuk Prisma Migrate (hanya untuk objek BARU yang role ini buat)

Prisma Migrate membuat objek baru (tabel, sequence, enum, view, index standar) yang didefinisikan di `schema.prisma`. Objek ini menjadi milik role yang menjalankan migrasi (`bookrate_migrate`).

| Privilege | Objek | Alasan | Untuk objek baru atau lama? |

|---|---|---|---|

| `USAGE` | schema `public` | Memungkinkan akses ke schema untuk membuat objek | Baru |

| `CREATE` | schema `public` | Memungkinkan membuat tabel, sequence, enum, view, index dalam schema | Baru |

**Tidak cukup untuk segalanya:** `USAGE` + `CREATE` pada schema hanya cukup untuk **membuat objek baru**. Ini **tidak** memungkinkan `bookrate_migrate` untuk:

- `ALTER`/`DROP` tabel/view/fungsi yang dimiliki `postgres` (hanya owner atau superuser yang bisa).

- Mengubah grant pada objek milik role lain.

- Membaca/menulis data di tabel aplikasi (butuh `SELECT`/`INSERT`/`UPDATE`/`DELETE` yang tidak diberikan).

### 4.2 Privilege untuk objek spesifik (verifikasi, bukan asumsi)

| Objek | Privilege yang perlu divalidasi | Catatan |

|---|---|---|

| ENUM (baru, dari Prisma) | `CREATE` pada schema | Dibuat oleh `bookrate_migrate`; menjadi miliknya |

| Sequence (baru, dari Prisma) | `CREATE` pada schema | Dibuat oleh `bookrate_migrate`; `USAGE` pada sequence diberikan otomatis kepada owner |

| Schema `public` | `USAGE` + `CREATE` | Minimum untuk Prisma Migrate membuat objek baru |

| Tabel (baru, dari Prisma) | Owner = `bookrate_migrate` | Prisma Migrate membuatnya; owner otomatis = role migrasi |

| View (baru, dari Prisma) | Owner = `bookrate_migrate` | Sama dengan tabel |

| Tabel lama (001–005, milik postgres) | **Tidak ada** | `bookrate_migrate` tidak mengubah; bukan owner |

| Fungsi 007 (milik postgres) | **Tidak ada** | Syarat 007: owner tetap `postgres` |

| Tabel data pengguna (runtime) | **Tidak ada** | Akses data lewat `bookrate_app` + RLS |

### 4.3 Privilege yang TIDAK dibutuhkan (dikeluarkan sengaja)

| Privilege | Alasan penolakan |

|---|---|

| `SELECT/INSERT/UPDATE/DELETE` pada tabel data pengguna | Role migrasi bukan runtime; akses data lewat `bookrate_app` + RLS |

| `EXECUTE` pada fungsi 007 | Fungsi dipakai runtime via `bookrate_app`, bukan migrasi |

| `BYPASSRLS` / `SUPERUSER` | Melanggar prinsip least privilege; role migrasi bukan security boundary |

| Membership `postgres` / `authenticated` / `service_role` | Role migrasi tidak boleh mewarisi akses runtime atau super-user |

| `CREATEDB` / `CREATEROLE` | Tidak perlu untuk migrasi skema dalam satu database |

### 4.4 Catatan tentang default privileges

`db/README.md` aturan 1: grant eksplisit, bukan default privileges. Jika `pg_default_acl` sudah memberikan hak pada `PUBLIC` untuk tabel baru (UNVERIFIED), tabel baru dari Prisma Migrate bisa terbaca klien tanpa grant eksplisit. Hal ini **di luar** cakupan `bookrate_migrate` dan menjadi temuan untuk OD-3 / aturan 8 `db/README.md`.

---

## 5. Pemisahan Migration Credential dan Runtime Credential

| Aspek | Migration (`bookrate_migrate`) | Runtime (`bookrate_app`) |

|---|---|---|

| Koneksi | `prisma.config.ts` (`datasource.url`) | `DATABASE_URL` (driver adapter `@prisma/adapter-pg`) |

| Pool | Direct connection (migrasi) | Transaction pooler Supabase (port 6543, OD-4) |

| Dipakai oleh | Prisma Migrate CLI hanya | `withUserContext` di `packages/db/src/client.ts` |

| Digunakan untuk request pengguna? | **TIDAK** | Ya, via `SET LOCAL ROLE` + `set_config` |

| Password | Di-set di luar repo, tidak di-commit | Di-set di luar repo, tidak di-commit |

| Lokasi secret | Tidak ada file di repo (belum ada `.env`) | Tidak ada file di repo (belum ada `.env`) |

### Berkas konfigurasi yang akan merujuk ke kredensial ini (belum dibuat/diubah)

- `packages/db/prisma.config.ts` — `datasource.url` = koneksi migrasi (`bookrate_migrate` atau `postgres`, tergantung keputusan OD-2 final). `directUrl` sudah dihapus dari schema oleh Prisma 7 (ADR Decision 11).

- `packages/db/src/client.ts` — instance tunggal `PrismaClient` dengan adapter + `DATABASE_URL` (runtime, `bookrate_app`).

- Tidak ada `.env` saat ini; variabel environment akan diisi oleh user saat implementasi (di luar batasan keras ini).

---

## 6. Kebutuhan Koneksi Supabase

### 6.1 Jenis koneksi yang dibutuhkan Prisma Migrate (Prisma 7)

| Kebutuhan | Detail |

|---|---|

| Koneksi langsung (direct) | Prisma Migrate **tidak bekerja melalui PgBouncer transaction pooling** untuk DDL (butuh prepared statements / setelan sesi yang tidak didukung transaction mode). Harus menggunakan direct connection ke Postgres. |

| Host | Supabase project host (UNVERIFIED — belum ada `DATABASE_URL`) |

| Port | 5432 (direct) untuk migrasi; 6543 (transaction pooler) untuk runtime (OD-4) |

| SSL | Supabase wajibkan SSL (UNVERIFIED) |

| `?pgbouncer=true` | Hanya untuk runtime via adapter, **bukan** untuk migrasi (OD-4 UNVERIFIED dengan adapter) |

### 6.2 Kompatibilitas Prisma 7

- OD-1 APPROVED: `prisma@7.10.1` + `@prisma/client@7.10.1`.

- Prisma 7: `prisma.config.ts` wajib untuk project dengan migrasi/introspeksi; `directUrl` dihapus dari schema; `prisma generate` eksplisit (tidak lagi implicit setelah `migrate`); generator wajib `output` di project.

- Flag CLI berubah: `--to-schema-datamodel` → `--to-schema`; `--from-url` → `--from-config-datasource` (hanya satu datasource per diff; tidak bisa membandingkan dua URL).

- Flag CLI perlu verifikasi via `--help` saat implementasi (UNVERIFIED sampai CLI terpasang).

### 6.3 Koneksi yang TIDAK dibolehkan untuk `bookrate_migrate`

- Tidak melalui `DATABASE_URL` runtime (pooler).

- Tidak digunakan dalam `withUserContext` atau apapun yang menyentuh data request pengguna.

- Tidak ada koneksi migrasi yang aktif saat aplikasi melayani traffic (migrasi dijalankan secara terpisah, dari mesin dev atau CI yang diizinkan).

---

## 7. Ownership Objek Database

### 7.1 Masalah utama: `GRANT CREATE ON SCHEMA` tidak cukup untuk `ALTER`/`DROP` objek milik role lain

Di PostgreSQL, hanya **owner objek** atau **superuser** yang dapat menjalankan `ALTER`/`DROP` pada objek tersebut. `GRANT CREATE ON SCHEMA public TO bookrate_migrate` hanya memberikan hak untuk **membuat objek baru** dalam schema tersebut. Ini **tidak** memberikan hak untuk:

- `ALTER TABLE` / `DROP TABLE` pada tabel yang dimiliki `postgres`.

- Mengubah grant pada objek milik `postgres`.

- Membuat ulang atau memodifikasi fungsi yang dimiliki `postgres`.

Oleh karena itu, 9 tabel + 2 view yang (jika skrip 001–005 telah dijalankan) dimiliki `postgres` **tidak dapat** diubah oleh `bookrate_migrate` tanpa mengubah ownership — yang dilarang oleh batasan keras plan ini.

### 7.2 Alternatif desain: tidak mengubah ownership seluruh objek

Alih-alih mengubah ownership semua objek lama ke `bookrate_migrate`, plan ini menggunakan pendekatan **pisahkan objek lama dan baru**:

| Kategori objek | Owner | Diubah oleh `bookrate_migrate`? | Alasan |

|---|---|---|---|

| 9 tabel lama (001–005) | `postgres` | **TIDAK** | Dibuat oleh skrip SQL manual sbg `postgres`; `bookrate_migrate` bukan owner, `GRANT CREATE` tidak cukup untuk ALTER/DROP |

| 2 view lama (001–005) | `postgres` | **TIDAK** | Sama di atas |

| ENUM lama (001–005) | `postgres` | **TIDAK** | Sama di atas |

| 8 fungsi 007 | `postgres` (TETAP) | **TIDAK** | Syarat eksplisit 007 checks #11, #31 |

| Trigger + policy + check constraint | `postgres` (pembuat) | **TIDAK** | Terikat tabel yang bukan milik `bookrate_migrate` |

| Tabel baru (dari Prisma Migrate) | `bookrate_migrate` | Ya | Prisma Migrate membuatnya; owner otomatis = role migrasi |

| Sequence baru (dari Prisma Migrate) | `bookrate_migrate` | Ya | Sama di atas |

| ENUM baru (dari Prisma Migrate) | `bookrate_migrate` | Ya | Sama di atas |

| View baru (dari Prisma Migrate) | `bookrate_migrate` | Ya | Sama di atas |

### 7.3 Strategi migrasi untuk tabel lama vs tabel baru

**Tabel lama (001–005, milik `postgres`):**

- Prisma Migrate **tidak mencoba mengelola** tabel lama ini. Mereka didefinisikan di SQL 001–005, bukan di `schema.prisma`.

- Jika `schema.prisma` mencakup tabel yang sudah ada di DB dengan definisi yang berbeda, Prisma Migrate diff akan mendeteksi drift → **HENTIKAN** (ADR Decision 13), jangan `resolve`/apply/reset.

- Perubahan pada tabel lama dilakukan melalui skrip SQL 001–005 (idempoten) dieksekusi manual via SQL Editor, bukan melalui Prisma Migrate.

**Tabel baru (dari Prisma Migrate):**

- Didefinisikan di `schema.prisma` dan dibuat oleh Prisma Migrate melalui koneksi `bookrate_migrate`.

- `bookrate_migrate` menjadi owner otomatis.

- Sebelum tabel baru dipakai: `ENABLE ROW LEVEL SECURITY` + `REVOKE ALL FROM anon, authenticated` + grant minimal via skrip SQL idempoten (bukan Prisma), lalu verifikasi `pg_policies` + `007`.

---

## 8. Prisma Baseline (kondisi DB hosted belum diverifikasi — audit dulu)

### 8.1 Kondisi awal — status belum cukup diketahui (prasyarat audit)

`db/SCHEMA_STATE.md` mencatat semua skrip 001–005 sebagai `pending` (belum ada baris `applied`). **Ini adalah catatan berkas, bukan bukti kondisi DB hosted nyata.** Catatan SCHEMA_STATE.md baris 5 secara eksplisit: *"Isi database hosted belum diverifikasi — jangan anggap kosong."*

Karena demikian, pada titik ini **belum cukup diketahui** apakah database hosted:

- Memiliki 9 tabel + 2 view dari skrip 001–005, atau

- Masih kosong, atau

- Memiliki objek lain yang tidak diketahui.

**Baseline tidak boleh ditentukan sebelum audit database read-only selesai.** Jika status objek database belum cukup diketahui, audit database menjadi prerequisite dan **STOP** di sini — jangan menebak.

### 8.2 Perbedaan: baseline migration vs initial migration

| Aspek | Baseline migration (objek SUDAH ADA di DB) | Initial migration (objek BELUM ADA di DB) |

|---|---|---|

| Definisi | Mengakui objek yang sudah ada di database tanpa mencoba membuatnya. | Membuat objek yang benar-benar belum ada di database. |

| Perintah SQL yang dihasilkan | Tidak ada `CREATE TABLE`/`CREATE VIEW` untuk objek lama — objek sudah ada. | Ada `CREATE TABLE`/`CREATE VIEW`/`CREATE ENUM` untuk objek baru. |

| `prisma migrate resolve --applied` | **BOLEH** ditandai applied hanya jika objeknya benar-benar sudah ada di DB. | **DILARANG** ditandai applied jika SQLnya membuat objek yang belum ada di DB (melanggar finding 3). |

| Risiko bila disalahgunakan | Menandai applied untuk objek yang tidak ada = Prisma berpendapat objek sudah ada padahal tidak. | Menandai applied untuk objek baru yang belum dibuat = Prisma melompati pembuatan, objek tidak pernah terbentuk. |

| Pengelolaan | Tersisa dikelola SQL manual (001–005), owned by `postgres`. | Dikelola Prisma Migrate, owned by `bookrate_migrate`. |

### 8.3 Experiment C — uji perilaku diff terhadap tabel lama (WAJIB, BELUM DIJALANKAN)

Experiment C harus tetap menguji apakah Prisma diff menghasilkan perintah CREATE, ALTER, atau DROP yang menyentuh tabel lama ketika datamodel Prisma hanya memuat objek baru. Eksperimen ini bersifat diagnostik dan tidak boleh dijalankan pada database hosted/production atau database berisi data nyata tanpa persetujuan eksplisit dan lingkungan uji terisolasi.

Yang diuji:
- Kondisi sumber: representasi database uji yang memuat tabel lama sesuai inventaris SQL 001–005.
- Kondisi target: datamodel Prisma yang hanya memuat objek baru yang memang direncanakan dikelola Prisma.
- Hasil: seluruh SQL diff diperiksa untuk setiap CREATE, ALTER, dan DROP, termasuk nama objek dan dependensinya.
Kriteria interpretasi:
- Catat apakah diff mencoba DROP tabel lama yang tidak direpresentasikan dalam datamodel.
- Catat apakah diff mencoba ALTER tabel lama atau membuat ulang objek lama.
- Catat apakah diff hanya menghasilkan CREATE untuk objek baru yang dimaksud.
- Simpan versi Prisma, versi PostgreSQL, konfigurasi datasource/schema, command/flag aktual, input schema, dan output SQL agar kesimpulan dapat direproduksi.
Batas kesimpulan: hasil hanya berlaku untuk konfigurasi dan versi yang benar-benar diuji. Hasil tidak boleh digeneralisasi ke konfigurasi Prisma, schema PostgreSQL, atau versi lain. Sampai Experiment C lulus, Option B berstatus BELUM TERVALIDASI dan tidak boleh dipilih sebagai strategi final.

### 8.4 Dua strategi yang berbeda — Option A dan Option B

Kedua opsi berikut bukan dua variasi dari satu baseline. Option A memodelkan objek lama dan baru bersama-sama; Option B mengecualikan objek lama dari datamodel Prisma dan mengelola hanya objek baru. Keduanya tetap menunggu audit database, eksperimen, dan persetujuan user.

Option A — Combined schema (objek lama + objek baru dimodelkan di Prisma)
- schema.prisma memuat model untuk tabel lama yang hendak direpresentasikan, serta model/enum untuk objek baru.
- Strategi ini membutuhkan mekanisme baseline yang valid untuk database hosted yang objek lamanya sudah ada. Mekanisme tersebut belum ditetapkan.
- Baseline tidak boleh diasumsikan valid hanya karena file migration dapat digenerate atau migrate resolve --applied dapat dijalankan.
- Sebelum dipertimbangkan, harus dibuktikan bahwa baseline menggambarkan objek existing secara akurat, tidak mencoba membuat ulang objek yang sudah ada, dan migration history tersinkron dengan kondisi database.
- Perlu audit apakah Prisma diff akan mempertahankan objek SQL-only (RLS, policy, trigger, function, view, partial index, check constraint, FK khusus) atau menghasilkan perubahan yang tidak diinginkan.
- Status: BELUM DITETAPKAN. Baseline mechanism masih unknown sampai eksperimen terpisah berhasil dan direview.
Option B — New-objects-only schema (objek lama dikecualikan)
- schema.prisma hanya memuat objek baru yang secara eksplisit dipilih untuk dikelola Prisma Migrate. Tabel/view/fungsi lama dari SQL 001–005 tidak dimasukkan.
- Ini bukan baseline strategy untuk tabel lama. Tidak ada baseline Prisma untuk objek lama karena objek tersebut berada di luar cakupan Prisma.
- Migration history Prisma hanya mencakup objek yang dikelola Prisma; ia tidak menyatakan atau merekam bahwa tabel lama telah dibaseline oleh Prisma.
- Tabel lama tidak tersedia sebagai model standar Prisma Client. Akses terhadap tabel tersebut harus tetap melalui mekanisme lain yang telah disetujui (misalnya Supabase/PostgREST atau SQL khusus yang aman); jangan mengklaim ada model Prisma untuk objek yang tidak dimodelkan.
- Option B hanya dapat diterima jika Experiment C membuktikan bahwa diff tidak menghasilkan DROP, ALTER, maupun CREATE terhadap tabel lama. Bila salah satu muncul, Option B gagal pada konfigurasi yang diuji dan harus dihentikan untuk evaluasi ulang.
- Status: BELUM TERVALIDASI sampai Experiment C selesai, hasilnya terdokumentasi, dan user menyetujui.
Larangan klaim: jangan menyebut Option B sebagai “baseline tabel lama”, “baseline untuk existing tables”, atau menyatakan bahwa tabel lama tercatat dalam migration history Prisma.

### 8.5 Alur evaluasi terpisah untuk Option A dan Option B (BELUM FINAL)

Tidak ada command final, file migration final, atau langkah migrate resolve yang ditetapkan pada bagian ini. Semua command Prisma harus diverifikasi terhadap --help versi CLI yang benar-benar digunakan saat task implementasi nanti. Jangan jalankan command pada database hosted dalam tahap plan ini.

Alur Option A — combined schema
1. Selesaikan audit database read-only: objek yang ada, ownership, dependensi, schema, dan status _prisma_migrations.
2. Susun datamodel gabungan hanya berdasarkan hasil audit dan keputusan eksplisit tentang objek yang memang akan dimodelkan Prisma.
3. Rancang eksperimen baseline di database uji terisolasi yang merepresentasikan kondisi existing database.
4. Verifikasi mekanisme baseline dari dokumentasi/CLI Prisma versi yang dipakai dan buktikan dengan eksperimen bahwa baseline tidak menjalankan ulang DDL existing, tidak melewatkan pembuatan objek baru, serta menghasilkan migration history yang konsisten.
5. Periksa semua SQL diff/migration untuk CREATE, ALTER, dan DROP pada objek lama maupun baru. Hentikan bila ada perubahan tak terduga atau objek SQL-only terancam.
6. Laporkan hasil dan risiko. Option A tetap BELUM FINAL sampai user menyetujui strategi dan prosedur yang terbukti.
Alur Option B — new-objects-only schema
1. Selesaikan audit database read-only dan tetapkan secara eksplisit daftar objek lama yang tetap dikelola SQL manual serta daftar objek baru yang akan dikelola Prisma.
2. Buat datamodel uji yang hanya memuat objek baru; pastikan tidak ada model/enum lama yang terselip.
3. Jalankan Experiment C hanya pada database uji terisolasi dengan konfigurasi yang dicatat lengkap.
4. Review output diff. Wajib terbukti tidak ada CREATE, ALTER, atau DROP yang menyentuh tabel lama. Jika ada, tandai Option B gagal untuk konfigurasi tersebut dan STOP.
5. Tentukan cakupan migration history: hanya objek baru yang dikelola Prisma. Proses pembuatan migration dan pencatatan history harus diverifikasi tersendiri sebelum dipakai.
6. SQL diff yang dihasilkan belum otomatis menjadi migration. Ia baru dapat dipertimbangkan sebagai migration setelah cakupan diff terbukti benar, file SQL direview, dan prosedur migration-history telah ditetapkan serta diuji.
7. Jangan menjalankan migrate resolve --applied sebelum DDL yang bersangkutan benar-benar sudah ada di database, kecuali ada prosedur baseline yang tervalidasi dan memang mensyaratkan pencatatan tersebut. resolve hanya mencatat status migration; ia tidak mengeksekusi DDL.
8. Laporkan hasil dan minta persetujuan eksplisit. Option B tetap BELUM FINAL sampai user menyetujui.
Gerbang bersama untuk A dan B
- Status database hosted belum terverifikasi: STOP.
- Perilaku diff terhadap objek lama belum terbukti: STOP.
- Ada DROP/`ALTER`/`CREATE` tak terduga terhadap objek lama atau objek SQL-only: STOP.
- Flag/command Prisma 7 belum diverifikasi: jangan menuliskan command sebagai prosedur final.
- Tidak ada apply, resolve, reset, role/privilege change, atau perubahan database dalam tahap plan/review ini.
### 8.6 Sinkronisasi migration history pertama kali

- `_prisma_migrations` tabel (jika belum ada) dibuat oleh Prisma Migrate saat pertama kali migration dijalankan/resolve.

- Baseline `0_init` hanya ditandai applied jika objeknya benar-benar sudah ada di DB (tidak ada `CREATE` yang belum dieksekusi).

- Apabila `_prisma_migrations` sudah ada (migrasi Prisma pernah dijalankan sebelumnya), tidak membuat baseline baru; gunakan migration history yang ada sebagai titik awal.

---

## 9. Kompatibilitas SQL 007

### 9.1 Checks yang relevan dengan ownership

| Check | Baris | Syarat | Implikasi untuk `bookrate_migrate` |

|---|---|---|---|

| #11 | 89-92 | `library_entry_notes` owner = `postgres` | Role migrasi **tidak boleh** membuat ulang/mengubah fungsi ini |

| #31 | 185-195 | 7 fungsi owner = `postgres`, `prosecdef=true`, `search_path=''` | Role migrasi **tidak boleh** menjadi owner fungsi ini |

### 9.2 Checks yang TIDAK terpengaruh oleh `bookrate_migrate` (asalkan tidak diubah)

Semua check lain (RLS 9 tabel, policy, grant per tabel, kolom notifikasi, trigger, enum, view, indeks, check constraint, FK) — karena `bookrate_migrate` tidak mengubah objek SQL 001–007.

### 9.3 Risiko drift migrasi

- Prisma Migrate diff mungkin mendeteksi objek SQL-only (check constraint, trigger, function, view, RLS, partial index, FK ke `auth.users`) sebagai "tidak dikenal" atau mencoba dropnya.

- **Aturan henti (ADR Decision 13):** bila diff menunjukkan drift atau objek tak dikenal → HENTIKAN, laporkan, jangan `resolve`/apply/reset sampai persetujuan.

- `prisma migrate reset` dan auto-reset `migrate dev` pada hosted **dilarang tanpa persetujuan tertulis pengguna**.

---

## 10. Proteksi RLS

### Prinsip

- RLS tetap **satu-satunya boundary authorization baris data** untuk semua jalur (ADR Security invariant).

- `bookrate_migrate` **tidak dipakai** untuk akses data pengguna; tidak butuh `BYPASSRLS`.

- `bookrate_app` (runtime) = non-owner, tanpa grant langsung, hanya anggota `authenticated` (untuk `SET LOCAL ROLE authenticated`), fail-closed (`42501`) tanpa konteks transaksi.

### Catatan RLS penting

- `NOBYPASSRLS` pada role **tidak otomatis memaksa table owner tunduk pada RLS**. Secara default, owner tabel dapat melewati RLS pada tabel miliknya sendiri (kecuali `FORCE ROW LEVEL SECURITY` diaktifkan — postgresql.org ddl-rowsecurity).

- Oleh karena itu, tabel yang dikelola `bookrate_migrate` (owner = `bookrate_migrate`) **tidak otomatis dilindungi RLS hanya karena role memiliki NOBYPASSRLS**. Evaluasi pemberian `ALTER TABLE ... FORCE ROW LEVEL SECURITY` pada tabel yang memerlukan proteksi RLS terhadap owner-nya sendiri.

- `bookrate_migrate` **tidak boleh** menjadi role runtime. Role migrasi digunakan untuk operasi skema (Prisma Migrate) saja, dan tidak pernah dipakai untuk request pengguna melalui `withUserContext`.

### Risiko jika `bookrate_migrate` memiliki akses data

Jika role migrasi diberikan `SELECT`/`INSERT` pada tabel data dan sengaja atau tidak sengaja dipakai untuk request pengguna, RLS akan diabaikan (owner bypass RLS pada objek miliknya sendiri, kecuali FORCE RLS — postgresql.org ddl-rowsecurity). Mitigasi: role migrasi tidak diberikan privilege data pada tabel aplikasi.

### Tabel baru dari Prisma Migrate

Tanpa `ENABLE ROW LEVEL SECURITY` + revoke-grant default-deny, tabel baru bisa langsung terbaca `anon` via PostgREST (default ACL Supabase, `pg_default_acl` UNVERIFIED). Oleh karena itu tabel baru **wajib** dipasangkan skrip SQL pelengkap segera setelah migrasi, sebelum tabel dipakai.

---

## 11. Risiko dan Mitigasi

| Risiko | Dampak | Mitigasi (dalam plan) |

|---|---|---|

| `bookrate_migrate` coba `ALTER`/`DROP` tabel lama milik `postgres` | Gagal (bukan owner) atau butuh ownership change (dilarang) | Prisma Migrate **tidak mengelola** tabel lama; hanya objek baru di `schema.prisma` |

| `bookrate_migrate` menjadi owner tabel baru → bypass RLS pada tabel miliknya sendiri | Data bocor bila role digunakan untuk runtime | Role migrasi **tidak pernah** dipakai runtime; tabel baru wajib `ENABLE RLS` + default-deny via skrip SQL terpisah |

| Prisma Migrate drop objek SQL-only (policy/trigger/function/check constraint) | Kehilangan objek keamanan, 007 gagal | Aturan henti Decision 13; review manual SQL hasil generate sebelum apply; jalankan ulang skrip SQL relevan setelah migrasi |

| Kredensial migrasi bocor (disimpan di repo) | Akses penuh skema | Tidak ada secret di repo; password di-set di luar repo |

| `pg_default_acl` memberikan hak `PUBLIC` pada tabel baru | Tabel baru bocor tanpa grant eksplisit | Deteksi via RUN 5a (paket query sebelumnya); mitigasi di skrip SQL pelengkap, bukan role migrasi |

| `bookrate_migrate` diberikan `EXECUTE` pada fungsi 007 | Mengubah perilaku fungsi definer | Tidak ada grant EXECUTE pada role migrasi; fungsi tetap `postgres` |

| Role migrasi digunakan untuk request pengguna (pelanggaran arsitektur) | RLS diabaikan, audit rusak | Pemisahan fisik koneksi (`prisma.config.ts` vs `DATABASE_URL`); peninjauan code (Task 8 grep enforces single PrismaClient location) |

| Tidak ada koneksi migrasi yang terkonfigurasi saat ini | Tidak dapat menjalankan Prisma Migrate | Task 3/4 membuat `prisma.config.ts` setelah OD-2 disetujui |

| Baseline `0_init` mencakup tabel yang sudah ada di DB | Pembuatan ulang tabel → error / drop data | Baseline hanya mencakup objek di `schema.prisma`; tabel lama tidak disertakan |

---

## 12. Langkah Implementasi (rencana, BELUM FINAL — tidak dieksekusi)
Bagian ini adalah urutan kerja kandidat, bukan instruksi untuk langsung menjalankan migrasi. BELUM FINAL sampai audit, eksperimen, review, dan persetujuan eksplisit user selesai. Tidak ada perubahan database, role, privilege, atau migration history yang diizinkan hanya berdasarkan plan ini.

### Fase 0: Persiapan dan audit read-only
1. [ ] User mereview plan ini; belum ada persetujuan implementasi hanya karena plan telah direvisi.
2. [ ] Audit read-only database hosted untuk mengonfirmasi objek aktual, schema, ownership, dependensi, role, pg_default_acl, dan keberadaan/status _prisma_migrations.
3. [ ] Cocokkan hasil audit dengan inventaris SQL 001–005. Catatan file SCHEMA_STATE.md bukan bukti kondisi database hosted.
4. [ ] Jangan membuat role, mengubah grant/ownership, memasang dependency, atau menjalankan SQL/migration pada fase ini.
### Fase 1: Persiapan eksperimen di lingkungan terisolasi
1. [ ] Tentukan database uji yang aman dan representatif; jangan gunakan hosted/production untuk eksperimen diff yang berpotensi menghasilkan DDL destruktif.
2. [ ] Catat versi Prisma CLI/Client, versi PostgreSQL, datasource/schema configuration, dan flag yang tersedia melalui --help.
3. [ ] Siapkan fixture/schema uji yang mencerminkan objek lama dari inventaris dan objek baru yang direncanakan. Jangan mengubah SQL 001–007 yang dilindungi.
### Fase 2: Evaluasi Option A — combined schema (jika dipilih untuk diuji)
1. [ ] Modelkan objek lama + baru pada datamodel uji sesuai audit.
2. [ ] Identifikasi dan validasi mekanisme baseline yang benar untuk existing database; jangan menganggap migrate diff sebagai baseline.
3. [ ] Buktikan pada database uji bahwa baseline dan migration history konsisten serta tidak menjalankan ulang DDL existing atau melewatkan pembuatan objek yang belum ada.
4. [ ] Review semua SQL CREATE/`ALTER`/`DROP`, termasuk objek SQL-only. Jika ada perubahan tak diinginkan, STOP.
5. [ ] Dokumentasikan hasil, batasan, dan status Option A. Jangan finalisasi tanpa persetujuan user.
### Fase 3: Evaluasi Option B — new-objects-only schema (jika dipilih untuk diuji)
1. [ ] Modelkan hanya objek baru; keluarkan seluruh tabel/view/fungsi lama dari datamodel Prisma.
2. [ ] Jalankan Experiment C di lingkungan uji terisolasi.
3. [ ] Periksa apakah diff menghasilkan CREATE, ALTER, atau DROP terhadap tabel lama. Option B hanya lolos jika tidak ada satu pun operasi tersebut terhadap tabel lama.
4. [ ] Jika lolos, validasi terpisah bagaimana file SQL diff menjadi migration dan bagaimana migration history dikelola. Diff SQL tidak otomatis merupakan migration dan bukan baseline untuk objek lama.
5. [ ] Jangan menandai migration applied sebelum DDL terkait benar-benar ada, kecuali prosedur baseline khusus telah dibuktikan valid dan disetujui.
6. [ ] Dokumentasikan hasil, batas konfigurasi eksperimen, dan status Option B. Jangan finalisasi tanpa persetujuan user.
### Fase 4: Keputusan dan implementasi (hanya setelah gate persetujuan)
1. [ ] Bandingkan hasil Option A dan Option B; pilih strategi hanya setelah bukti eksperimen dan risiko dipaparkan kepada user.
2. [ ] Minta persetujuan eksplisit untuk strategi final, command, file migration, target database, dan setiap tindakan yang mengubah database.
3. [ ] Setelah disetujui, buat/update file konfigurasi dan migration sesuai strategi final. Secret tetap di environment dan tidak di-commit.
4. [ ] Review SQL migration lengkap sebelum eksekusi. Tidak boleh ada DROP/`ALTER`/`CREATE` terhadap objek lama yang tidak secara eksplisit disetujui.
5. [ ] Eksekusi migration hanya setelah persetujuan terpisah untuk target dan tindakan database.
6. [ ] Terapkan RLS/default-deny dan grant minimal untuk setiap tabel baru sebelum tabel digunakan; jangan menjalankan ulang SQL 001–007 secara massal.
### Fase 5: Verifikasi dan dokumentasi (gate terpisah)
1. [ ] Verifikasi struktur, ownership, grants, RLS, policies, dan migration history berdasarkan kriteria yang telah disetujui.
2. [ ] Skrip 007 (31 checks) hanya dijalankan setelah prasyarat dan persetujuan verifikasi terpenuhi; jangan menganggapnya bagian otomatis dari migration.
3. [ ] Skrip 006 (76 negative assertions) hanya dijalankan sebagai pengujian terpisah setelah prasyaratnya terpenuhi dan disetujui; bukan bagian migration.
4. [ ] Perbarui db/SCHEMA_STATE.md hanya berdasarkan hasil aktual yang terverifikasi.
5. [ ] Buat/update workflow migration terpisah setelah strategi final disetujui.
Catatan command: Bagian ini sengaja tidak menetapkan command prisma migrate diff final. Command dan flag hanya boleh ditulis setelah versi CLI, cakupan diff, konfigurasi schema/datasource, dan hasil Experiment C diverifikasi. migrate diff tidak dengan sendirinya menetapkan migration history; migrate resolve tidak menjalankan DDL.

Larangan tetap: prisma migrate reset, auto-reset migrate dev pada hosted, perubahan ownership, perubahan role/privilege, serta eksekusi SQL 001–007 tidak dilakukan tanpa persetujuan eksplisit yang sesuai.

Status: BELUM FINAL — menunggu audit, eksperimen, review, dan persetujuan user.

## 13. Langkah Verifikasi dan Rollback

### Verifikasi read-only (tidak mengubah DB)

| Verifikasi | Query/Metode | Kriteria lulus |

|---|---|---|

| Owner 8 fungsi 007 | `pg_proc` + `pg_get_userbyid(proowner)` | Semua = `postgres` |

| Owner tabel/view/sequence | `pg_class.relowner` | Tabel lama = `postgres`; tabel baru (Prisma) = `bookrate_migrate` |

| `bookrate_migrate` tanpa privilege data | `information_schema.table_privileges` | 0 baris untuk `bookrate_migrate` pada tabel aplikasi |

| `bookrate_migrate` bukan anggota berbahaya | `pg_auth_members` | Tidak anggota `postgres`/`authenticated`/`service_role` |

| RLS aktif pada tabel baru | `pg_class.relrowsecurity` | `true` pada semua tabel aplikasi |

| 007 lolos | Eksekusi skrip 007 (sql editor) | `ALL 31 CHECKS PASSED` |

| 006 lolos | Eksekusi skrip 006 (sql editor, transaksi + ROLLBACK) | `ALL 76 ASSERTIONS PASSED` |

### Rollback (bila masalah)

- **Tidak ada `prisma migrate reset`** pada hosted tanpa persetujuan tertulis (Decision 13).

- Rollback migrasi = `prisma migrate resolve` untuk menandai migration sebagai applied/unapplied sesuai hasil review, atau revert file migrasi + baseline baru — **hanya setelah review manual dan persetujuan user**.

- Rollback konfigurasi = hapus `prisma.config.ts` / `schema.prisma` yang baru dibuat (file kode, bukan DB).

- Semua skrip SQL pelengkap harus idempoten (`IF NOT EXISTS`, DO block) agar dapat diulang tanpa efek samping.

---

## 14. Acceptance Criteria

| # | Kriteria | Bukti (diharapkan, belum ada) |

|---|---|---|

| AC-1 | Role `bookrate_migrate` dibuat dengan atribut `LOGIN NOINHERIT NOBYPASSRLS`, tanpa superuser/createdb/createrole | Output `CREATE ROLE` / `pg_roles` (user jalankan, belum) |

| AC-2 | `bookrate_migrate` tidak memiliki privilege data (`SELECT/INSERT/UPDATE/DELETE`) pada tabel aplikasi | `information_schema.table_privileges` = 0 baris untuk role ini (belum diverifikasi) |

| AC-3 | 8 fungsi SQL 007 tetap dimiliki `postgres` | `pg_proc.proowner = 'postgres'` untuk 8 fungsi (belum diverifikasi) |

| AC-4 | `prisma.config.ts` ada dengan `datasource.url` ke koneksi migrasi, tanpa secret hardcode | File ada, env untuk password (belum dibuat) |

| AC-5 | `packages/db/src/client.ts` tetap lokasi tunggal `PrismaClient` runtime, tidak diekspor dari `index.ts` | File ada, enforced by Task 8 grep (belum ada implementasi) |

| AC-6 | 007 lolos: `VERIFY SCHEMA: ALL 31 CHECKS PASSED` | Output eksekusi 007 (belum dijalankan) |

| AC-7 | 006 lolos: `ALL NEGATIVE TESTS PASSED` (76) | Output eksekusi 006 (belum dijalankan) |

| AC-8 | Tabel baru dari Prisma Migrate memiliki `ENABLE ROW LEVEL SECURITY` + default-deny sebelum dipakai | Skrip SQL pelengkap + verifikasi `pg_policies` (belum dibuat) |

| AC-9 | Tidak ada `prisma migrate reset`/auto-reset pada hosted tanpa persetujuan tertulis | Kebijakan tercatat dalam plan ini (terpenuhi secara dokumen) |

| AC-10 | Role migrasi tidak pernah dipakai untuk request pengguna (koneksi terpisah dari runtime) | `prisma.config.ts` ≠ `DATABASE_URL` (belum ada file keduanya) |

| AC-11 | Baseline `0_init` tidak mencakup tabel lama milik `postgres` | Isi file `packages/db/migrations/0_init/migration.sql` (belum dibuat) |

| AC-12 | `bookrate_migrate` hanya memiliki `USAGE` + `CREATE` pada schema `public` (tidak lebih) | Hasil verifikasi grant (belum dijalankan) |

---

## 15. File yang Dibaca dan Diubah

### File yang dibaca (referensi, tidak diubah)

| File | Tujuan pembacaan |

|---|---|

| `docs/architecture/0002-prisma-orm-backend.md` | ADR: Decision 7 (role runtime), Decision 8 (migrasi terpisah runtime), Decision 11 (Prisma 7), Decision 12 (tabel baru RLS), Decision 13 (no reset), Open Decisions OD-2 |

| `docs/superpowers/plans/2026-11-15-prisma-adoption-plan.md` | Tech stack, gate OD, Task 1 verifikasi DB, Task 4 baseline, Task 8 enforcemen |

| `db/README.md` | Aturan hybrid Prisma+SQL, grant eksplisit, tabel baru wajib RLS, larangan reset |

| `db/SCHEMA_STATE.md` | Status 001–007 (pending), catatan DB belum diverifikasi |

| `db/scripts/007_verify_schema.sql` | Check #11 & #31 owner = postgres untuk 8 fungsi |

| `db/scripts/001`–`005` | Objek yang diharapkan (tabel, view, fungsi, trigger, policy, grant) |

### File yang dibuat (dokumen plan saja)

| File | Status |

|---|---|

| `docs/superpowers/plans/BR-BE-OD2-prisma-migration-role.md` | **Direvisi oleh agent ini** (plan ini, tidak mengubah DB) |

### File yang sengaja TIDAK diubah

- `db/scripts/001`–`007` (dilindungi)

- `db/SCHEMA_STATE.md` (tidak diubah oleh agent ini)

- `docs/architecture/0002-prisma-orm-backend.md` (ADR tidak diubah)

- `docs/superpowers/plans/2026-11-15-prisma-adoption-plan.md` (tidak diubah)

- Semua file kode/aplikasi lainnya

---

## 16. Temuan dan Risiko yang Masih UNVERIFIED

| # | Item | Alasan belum terverifikasi |

|---|---|---|

| UV-1 | Atribut aktual `postgres` di DB hosted (`rolbypassrls`, `rolsuper`) | Butuh akses DB (dilarang fase ini); catatan pengguna disebutkan `rolbypassrls=true`, `rolsuper=false` |

| UV-2 | Owner aktual semua objek (tabel, view, sequence, fungsi) | Butuh query read-only (paket query sebelumnya) |

| UV-3 | Keberadaan `bookrate_migrate` dan `bookrate_app` di DB | Belum pernah diverifikasi |

| UV-4 | `pg_default_acl` (grant default `anon`/`authenticated` untuk tabel baru) | Belum diverifikasi; risiko tabel baru bocor |

| UV-5 | Apakah koneksi role kustom bisa lewat pooler Supabase (port 6543) | OD-4 masih OPEN; butuh verifikasi environment |

| UV-6 | Flag CLI Prisma 7 yang tepat (`--help`) dan perilaku `migrate diff` terhadap check constraint | Belum ada CLI terpasang |

| UV-7 | Kompatibilitas `@prisma/adapter-pg` + `?pgbouncer=true` dengan pooler Supabase | Belum terpasang, UNVERIFIED |

| UV-8 | Hasil eksekusi 006 (76 assertions) dan 007 (31 checks) | Belum pernah dijalankan |

| UV-9 | Apakah tabel 9 + 2 view sudah benar-benar ada di DB hosted | SCHEMA_STATE.md catat `pending`, tapi DB belum diverifikasi |

---

## 17. Status dan Langkah Selanjutnya

- **OD-2:** Kandidat `bookrate_migrate` (dedicated, least privilege) terdokumentasi dalam plan ini. **Masih OPEN** — menunggu persetujuan eksplisit user.

- **OD-3, OD-4, OD-6, OD-7:** Masih OPEN.

- **Tidak ada implementasi yang dimulai.** Tidak ada role dibuat, tidak ada SQL dijalankan, tidak ada dependency dipasang, tidak ada commit.

- **Langkah selanjutnya (setelah user menyetujui plan ini):** User menjalankan paket query read-only untuk mengonfirmasi kondisi DB, lalu membuat role `bookrate_migrate` di luar repo, baru kemudian Task 3/4 (buat `prisma.config.ts` dan `schema.prisma`).

**Berhenti di sini.** Menunggu review dan persetujuan Anda sebelum implementasi.