# ADR 0002: Prisma ORM over Supabase PostgreSQL with RLS as the Security Boundary

- Status: Accepted
- Date: 2026-11-15
- Amends: `docs/architecture/0001-supabase-first-backend.md` — bagian *database access path* dan *migration workflow*; Supabase Auth, RLS Exposure Gate, Custom-API Trigger Criteria, dan seluruh larangan alat (Supabase CLI/Docker/Deno/local Supabase/Edge Functions) dari ADR 0001 **tetap berlaku**.
- Related: `docs/ROADMAP.md` — "Adopsi Prisma"; `db/README.md`; rencana implementasi `docs/superpowers/plans/2026-11-15-prisma-adoption-plan.md`
- Evidence: riset arsitektur 2026-11-14/15 (dokumentasi resmi PostgreSQL, Supabase, Prisma, PostgREST, PgBouncer + audit isi repository). **Belum ada tes yang dijalankan**; semua klaim runtime ditandai UNVERIFIED di bawah.

## Context

ADR 0001 menetapkan backend Supabase-first dengan akses data langsung dari client dan
manajemen skema Dashboard-first (file SQL manual). Riset arsitektur terbaru memutuskan
bahwa web MVP akan mengakses data lewat **server Next.js dengan Prisma Client**, tanpa
melemahkan PostgreSQL RLS sebagai security boundary. Pertanyaan kritis yang harus
dijawab ADR ini: role database apa yang dipakai Prisma, bagaimana identitas Supabase
Auth sampai ke RLS di dalam transaksi Prisma, dan objek apa yang tetap harus dikelola
SQL murni.

## Decision

1. **Database: PostgreSQL melalui Supabase** (hosted) — tetap satu-satunya database.
2. **ORM: Prisma.** **Prisma Client hanya untuk server** (Next.js di Vercel).
   **Mobile (Expo) tidak pernah memakai Prisma Client** — mobile memakai Supabase JS
   langsung ke PostgREST dengan RLS yang sama.
3. **Prisma Migrate** mengelola struktur yang didukung Prisma: enum, tabel, kolom,
   PK/FK internal, unique constraint, index standar. **Check constraint (termasuk
   yang "standar") TIDAK dikelola Prisma** — PSL Prisma 7 tidak mendukungnya
   (bukti: docs v7 tanpa `@@check`, issue `prisma/orm#3388` masih open sejak 2019;
   `@@check` baru di-merge 2026-08-12 untuk jalur v8 via PR #29972) → tetap milik SQL
   (lihat Decision 4).
4. **SQL tetap menjadi satu-satunya jalur** untuk: RLS enable/force, policies,
   grants/revokes (termasuk kolom-level), triggers, functions (termasuk SECURITY
   DEFINER), views (`security_invoker`), partial index, **semua check constraint**
   (expression maupun standar, mis. `004:21-24`), FK ke `auth.users`, serta skrip
   tes `006`/`007`. **`db/scripts/001`–`007` tidak diubah.**
   Alasan: objek-objek ini tidak terwakili di `schema.prisma`; Prisma Migrate tidak
   boleh mengelolanya (risiko ter-drop saat diff) — termasuk perilaku diff terhadap
   check constraint yang wajib diuji dry-run dulu (UNVERIFIED sampai Task 4).
5. **Supabase Auth tetap** sebagai identity provider; sisi server memverifikasi token
   melalui `supabase.auth.getClaims()` (verifikasi signature) — bukan `getSession()`.
6. **RLS tetap menjadi batas keamanan database** untuk semua jalur akses (Prisma di
   server maupun PostgREST untuk mobile).
7. **Koneksi runtime (`DATABASE_URL`)** memakai role dedicated **`bookrate_app`**:
   `LOGIN NOINHERIT NOBYPASSRLS`, **bukan owner tabel mana pun**, **tanpa grant langsung
   ke tabel**, dan **hanya** anggota role `authenticated` (untuk memungkinkan
   `SET LOCAL ROLE authenticated`). Query runtime pengguna **tidak pernah** memakai
   superuser, `service_role`, atau role `BYPASSRLS`.
   - **Membership dikonfigurasi eksplisit sesuai versi PostgreSQL** (jangan mengandalkan
     default): PG≥16 → `GRANT authenticated TO bookrate_app WITH INHERIT FALSE, SET TRUE;`
     PG<16 → grant polos + atribut role `NOINHERIT` (klausa `WITH INHERIT/SET` tidak ada).
     *`CREATE ROLE` default = `INHERIT` (postgresql.org/docs/current/role-membership.html),
     dan default opsi INHERIT pada `GRANT` untuk PG≥16 tidak dinyatakan eksplisit di
     dokumentasi yang dikutip → treat sebagai risiko inherit, netralkan dengan
     `INHERIT FALSE`.*
   - **Wajib diverifikasi** setelah grant: `has_table_privilege('bookrate_app','public.profiles','select')`
     = **false**. Bila `true` (mewarisi grant `authenticated`, mis. `002:119`), fail-closed
     `42501` tidak tercapai → **remediasi: grant ulang dengan `INHERIT FALSE`, ulangi tes**.
   - **SQL pembuatan role tidak memuat password atau placeholder rahasia** — password
     di-set terpisah (Dashboard/`ALTER ROLE` di luar repo), tidak pernah di-commit.
8. **Koneksi migrasi** terpisah dari runtime dan hanya untuk Prisma Migrate/DDL —
   tidak pernah dipakai saat runtime. Pada **Prisma 7** pemetaannya via
   `prisma.config.ts` (`datasource.url` = koneksi migrasi; `directUrl` sudah dihapus
   dari schema oleh Prisma 7) sementara runtime memakai driver adapter
   (`@prisma/adapter-pg`) dengan `DATABASE_URL`. Lihat Decision 11.
9. **Propagasi identitas transaction-scoped** (pola yang sudah dirancang di
   `db/scripts/006_negative_tests.sql:149-151`): di dalam satu `$transaction`
   (API Prisma 7 — lihat Decision 11):
   - `SET LOCAL ROLE authenticated;`
   - `SELECT set_config('request.jwt.claims', '{"sub":"<uuid>","role":"authenticated"}', true);`
   - seluruh query berjalan lewat handle `tx` transaksi yang sama;
   - `COMMIT`/`ROLLBACK` menghapus kedua konteks secara otomatis (transaction-scoped);
   - tanpa konteks → role runtime tanpa grant → **fail-closed** (`42501`).
   Dilarang: `set_config(..., false)` dan `SET` level sesi pada jalur runtime.
10. **Pooling (kandidat, menunggu verifikasi environment deployment):** runtime memakai
    transaction pooler Supabase (port 6543, `?pgbouncer=true`); migrasi memakai
    direct connection. `SET LOCAL`/`set_config(..., true)` aman di transaction pooling
    karena berada di dalam blok transaksi eksplisit.
11. **Platform Prisma 7 (kandidat pin `prisma@7.10.1` + `@prisma/client@7.10.1`,
    menunggu persetujuan OD-1)** — konsekuensi wajib dari Prisma 7 (bukti: release
    `7.0.0`, github.com/prisma/orm/releases/tag/7.0.0):
    - **`prisma.config.ts` wajib** untuk project dengan migrasi/introspeksi;
      `datasource.url` & env loading pindah ke config (CLI tidak lagi memuat env
      otomatis → butuh `dotenv` di config).
    - **`PrismaClient` wajib driver adapter** (`@prisma/adapter-pg`) atau
      `accelerateUrl`; `new PrismaClient({datasourceUrl})` sudah dihapus.
    - **`prisma generate` eksplisit** (tidak lagi implicit setelah `migrate`);
      generator **wajib `output`** di project.
    - **Flag CLI berubah**: `--to-schema-datamodel` → `--to-schema`; `--from-url` →
      `--from-config-datasource` (hanya satu datasource per diff; tidak bisa
      membandingkan dua URL) — **flag persis diverifikasi via `--help` saat
      implementasi (UNVERIFIED sampai CLI terpasang)**.
    - **Pin eksplisit wajib**: tag npm `latest` CLI `prisma` = `8.0.0-rc.33` (RC!)
      sedangkan `@prisma/client` `latest` = `7.10.1` — install tanpa versi menghasilkan
      pasangan tidak cocok. Berlaku juga untuk **`@prisma/adapter-pg`** (wajib pin
      **major 7** yang kompatibel — **nomor patch = UNVERIFIED**: cek dist-tags &
      peer dependency di registry saat implementasi, **jangan mengarang angka patch**)
      dan **`dotenv`** (wajib terpasang sebagai dependency karena `prisma.config.ts`
      memakai `import 'dotenv/config'` — bukan asumsi bawaan).
    - API transaksi Prisma 7 = `$transaction` (docs default prisma.io kini menampilkan
      v8 `db.transaction` → rujuk `prisma.io/docs/orm/v7/…`).
12. **Setiap tabel BARU hasil Prisma Migrate wajib menjalani proses RLS** sebelum
    dipakai: SQL pairing `ALTER TABLE … ENABLE ROW LEVEL SECURITY` + revoke-grant
    default-deny, lalu verifikasi (`pg_policies`, `007`, diff). Alasan: Prisma tidak
    dapat menulis `ENABLE ROW LEVEL SECURITY`, dan `007` hanya meng-assert **9 tabel
    lama** (`007_verify_schema.sql:56`) sehingga tidak menangkap tabel baru; dengan
    default ACL Supabase (`pg_default_acl`, UNVERIFIED) tabel baru bisa langsung
    terbaca `anon` via PostgREST.
13. **`prisma migrate reset` dan auto-reset `migrate dev` (termasuk menerima prompt
    reset/drift) pada database hosted DILARANG tanpa persetujuan tertulis pengguna.**
    Reset meng-drop seluruh schema → policy, trigger, function, view, grant, dan data
    ikut hilang. Bila diff menunjukkan **drift atau objek yang tidak dikenal**:
    **HENTIKAN proses**, catat di laporan, jangan `resolve`/apply/reset sampai
    persetujuan.
14. **Seluruh query data pengguna wajib melewati helper konteks** (`withUserContext`)
    di `@bookrate/db` — kode aplikasi (Next.js **dan** mobile) **dilarang membuat /
    meng-import `PrismaClient` sendiri**. **Lokasi tunggal instance `PrismaClient`
    = `packages/db/src/client.ts`** (adapter `PrismaPg` + `DATABASE_URL`, diisi pada
    Task 4); instance itu dipakai internal paket dan **tidak dire-ekspor** dari
    `packages/db/src/index.ts` — API publik `@bookrate/db` hanya `withUserContext`
    (+ tipe; admin/system query bila kelak dibutuhkan harus bernama eksplisit).
    `apps/web/src/lib/db.ts`, bila ada, **hanya re-export helper** — tanpa
    `new PrismaClient`. Ditegakkan statis (grep/lint) di Task 8.

## Evidence status

### Proven (dokumentasi resmi / kode sumber / isi repository — BUKAN hasil tes)

| Fakta | Sumber |
|---|---|
| Superuser & `BYPASSRLS` selalu melewati RLS; owner tunduk hanya via FORCE | postgresql.org/docs/current/ddl-rowsecurity.html |
| Owner `postgres` Supabase punya `bypassrls`; panduan resmi Prisma membuat role `prisma … bypassrls createdb` | supabase.com/docs/guides/database/postgres/row-level-security; supabase.com/docs/guides/database/prisma |
| `SET ROLE` menuntut opsi `SET` pada membership; `NOINHERIT` membuat privilege grup hanya tercapai via `SET ROLE`; PG<16 `INHERIT` = atribut role, PG≥16 = opsi membership | postgresql.org/docs/current/sql-set-role.html; /sql-createrole.html |
| Default `CREATE ROLE` = **INHERIT** (atribut role); `GRANT` membership: opsi **SET default aktif**; inherit diatur **per-membership** (`WITH INHERIT`) pada PG≥16; default opsi INHERIT pada `GRANT` tidak dinyatakan eksplisit | postgresql.org/docs/current/role-membership.html (§21.3); /sql-grant.html |
| Prisma **v8 masih RC** (`prisma` npm `latest` = `8.0.0-rc.33`), stable = **7.10.1** (`@prisma/client` `latest`); v7.0.0 = stable release dengan `prisma.config.ts` wajib, adapter wajib, `directUrl` dihapus, flag diff berubah, generate eksplisit | registry.npmjs.org dist-tags (2026-11-15); github.com/prisma/orm/releases/tag/7.0.0 |
| PSL Prisma 7 tidak mendukung check constraint (docs v7 tanpa `@@check`; `prisma/orm#3388` open sejak 2019; `@@check` di-merge 2026-08-12 → jalur v8) | prisma.io/docs/orm/v7/prisma-schema/data-model/models; github.com/prisma/orm/issues/3388; /pull/29972 |
| `auth.uid()` membaca `request.jwt.claim.sub` lalu fallback `request.jwt.claims::jsonb->>'sub'` — kedua GUC didukung; `set_config('request.jwt.claims', …, true)` kompatibel | kode sumber supabase/auth: `migrations/20211202183645_update_auth_uid.up.sql` |
| `getClaims()` memverifikasi signature (JWKS lokal / Auth server); `getSession()` tidak boleh dipercaya di server | supabase.com/docs/guides/auth/server-side/nextjs |
| `SET LOCAL ROLE` impersonation + GUC `request.jwt.claims` transaction-scoped | postgrest.org/en/stable/references/auth.html; /references/transactions.html |
| Transaction pooling: state sesi hilang antar transaksi; server connection dipinjam hanya selama transaksi | supabase.com/docs/guides/database/connecting-to-postgres; pgbouncer.org/usage.html |
| Query lewat `db` di dalam callback transaksi keluar dari transaksi; rollback saat throw | prisma.io/docs/orm/fundamentals/transactions |
| Pola konteks di repo: `set local role authenticated` + `set_config('request.jwt.claims', …, true)` | `db/scripts/006_negative_tests.sql:149-151` |
| Policy memakai `auth.uid()` (23×), `auth.jwt()` (0×); 9 tabel RLS; owner fungsi definer = `postgres` | grep `db/scripts/002-005`; `db/scripts/007_verify_schema.sql:89,185` |
| Semua skrip 001–007 berstatus `pending` (belum ada eksekusi yang tercatat) | `db/SCHEMA_STATE.md:8-16` |

### Not yet verified (butuh koneksi database nyata — jangan dianggap benar/salah sebelum tes)

- Isi database Supabase hosted saat ini (**tidak boleh dianggap kosong sebelum diverifikasi**).
- Pembuatan & perilaku `bookrate_app` pada project ini (`pg_roles`, membership, `pg_auth_members`).
- Versi PostgreSQL project (menentukan semantik `INHERIT` PG<16 vs ≥16).
- `pg_default_acl` (grant default `anon`/`authenticated` untuk tabel baru).
- Perilaku `auth.uid()` pada versi yang terpasang di project (source code terverifikasi; versi runtime belum).
- Semua hasil tes: 006 (76 assertions) dan 007 (31 checks) — **belum pernah dijalankan**.
- perilaku pooler runtime (transaction mode) dengan Prisma.
- Flag CLI Prisma 7 yang tepat (`--help`) dan perilaku `migrate diff` terhadap check
  constraint/introspeksi objek SQL-only (uji dry-run Task 4).
- Integrasi driver adapter `@prisma/adapter-pg` + pooler Supabase (`?pgbouncer=true`)
  — panduan Supabase–Prisma ditulis untuk konfigurasi klasik.
- Efektivitas inherit membership `bookrate_app` pada PG≥16 (netralisasi `INHERIT FALSE`
  diverifikasi lewat `has_table_privilege`, Task 2).

## Security invariants

- RLS tetap satu-satunya authorization boundary baris data untuk semua jalur.
- Runtime Prisma tidak pernah memakai superuser, `service_role`, atau `BYPASSRLS`.
- `bookrate_app` bukan owner tabel dan tidak punya grant langsung; tidak pernah
  di-grant membership `postgres`/`service_role`.
- Setiap akses data user-scoped berada di dalam transaksi Prisma dengan
  `SET LOCAL ROLE` + `set_config('request.jwt.claims', …, true)` transaction-scoped.
- Tidak ada konteks user yang bocor antar-request (wajib dibuktikan tes, bukan diasumsikan).
- Mobile tidak pernah memakai Prisma Client; aplikasi web hanya mengakses data lewat
  `withUserContext` — tanpa akses client mentah (Decision 14).
- `006` (76 assertions) dan `007` (31 checks) tidak pernah dimodifikasi; klaim lulus
  hanya dari output eksekusi aktual.
- Pemisahan koneksi runtime (`DATABASE_URL`) vs migrasi (`prisma.config.ts`).
- Tabel baru selalu melewati `ENABLE ROW LEVEL SECURITY` + revoke-grant default-deny
  sebelum dipakai (Decision 12); gate `007` tidak otomatis menangkapnya.
- Tanpa `prisma migrate reset`/auto-reset pada hosted tanpa persetujuan tertulis;
  drift/objek tak dikenal = HENTI + lapor (Decision 13).
- Tidak ada password/rahasia di file SQL role (Decision 7).

## Consequences

- Server Next.js menjadi titik kepercayaan tambahan (ia memegang kredensial runtime);
  RLS tetap melindungi terhadap klien dan kebocoran pool, bukan terhadap server yang
  sudah dikompromikan — sama seperti model PostgREST.
- Setiap akses data user menambah biaya `BEGIN`/`COMMIT` (ditampung transaction pooler).
- Skema menjadi dual-managed: Prisma Migrate (struktur) + SQL scripts (keamanan/objek
  khusus) — membutuhkan urutan kerja dan review migrasi yang disiplin.
- Workflow Dashboard-first ADR 0001 berubah menjadi **hybrid** untuk struktur tabel.

## Rejected alternatives

- **Role runtime `bypassrls` (mengikuti panduan resmi Prisma Supabase):** akan
  menonaktifkan RLS untuk seluruh jalur server dan mematikan nilai 76 negative test.
- **Owner + `FORCE ROW LEVEL SECURITY`:** di Supabase owner `postgres` memiliki
  `bypassrls`; FORCE tidak menundukkan role `BYPASSRLS` (PostgreSQL docs).
- **Prisma middleware/ORM filter sebagai otorisasi:** bukan mekanisme keamanan; RLS tetap boundary.
- **State sesi (`SET` / `set_config(..., false)`):** tidak aman di transaction pooling.

## Open Decisions

| # | Keputusan | Konsekuensi bila belum dipilih |
|---|---|---|
| OD-1 | Versi Prisma mayor. **Kandidat (revisi 2026-11-15): pin `prisma@7.10.1` + `@prisma/client@7.10.1`** — v8 masih RC (`8.0.0-rc.33`), v7 stabil & selaras `$transaction`/`schema.prisma` | Rencana mengasumsikan Prisma 7 (API `$transaction`, `prisma.config.ts`, adapter); bila disetujui v8 saat sudah GA, seluruh Decision 11 dan Task 3–5 harus ditinjau ulang (API `db.transaction`, `contract.prisma`) |
| OD-2 | Bentuk role migrasi: `postgres` via koneksi migrasi (kandidat utama) vs role dedicated `bookrate_migrate` | Cek 007 nomor 11 & 31 menuntut owner fungsi = `postgres`; role dedicated akan membuat cek itu gagal kecuali ada langkah transfer ownership — 007 tidak boleh diubah |
| OD-3 | Strategi baseline Prisma Migrate (tiga perbandingan: history ↔ schema ↔ hosted; Decision 13) | Bergantung pada hasil verifikasi isi database (Plan Task 1) — asumsi "kosong" dilarang |
| OD-4 | Mode pooler final untuk runtime (transaction 6543 kandidat utama vs direct/session) + perilaku `?pgbouncer=true` dengan adapter | Menentukan connection string Vercel dan konfigurasi `prisma.config.ts`/adapter |
| OD-5 | Payload klaim: minimal `{sub, role}` (kandidat utama) vs meneruskan JWT terverifikasi utuh | Policy saat ini hanya memakai `auth.uid()`; berubah bila kelak ada kebutuhan `aal`/custom claims |
| OD-6 | Nilai `idle_in_transaction_session_timeout` | Transaksi menggantung dapat memblokir pool |
| OD-7 | Konfirmasi runtime `auth.uid()` pada project (T-08) | Source code terverifikasi; perilaku versi terpasang belum |
