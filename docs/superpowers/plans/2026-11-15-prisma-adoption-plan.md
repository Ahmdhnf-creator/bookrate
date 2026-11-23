# BookRate Prisma Adoption — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mengadopsi PostgreSQL + Prisma (Prisma Client server-side, Prisma Migrate + SQL hybrid) pada BookRate tanpa melemahkan RLS sebagai security boundary, dengan role runtime dan identity propagation yang terverifikasi.

**Architecture:** Role runtime `bookrate_app` (LOGIN NOINHERIT NOBYPASSRLS, bukan owner, tanpa grant langsung, membership `authenticated` **dikonfigurasi eksplisit** `WITH INHERIT FALSE, SET TRUE` pada PG≥16 / `NOINHERIT` role-level pada PG<16 — lihat ADR 0002 Decision 7) mengakses data hanya di dalam transaksi Prisma yang diawali `SET LOCAL ROLE authenticated` + `set_config('request.jwt.claims', …, true)`. Migrasi struktur jalan lewat role migrasi terpisah via koneksi di `prisma.config.ts` (Prisma 7); RLS/policies/grants/triggers/functions/views/check constraints tetap dijalankan dari skrip SQL `db/scripts/` via SQL Editor. Detail: `docs/architecture/0002-prisma-orm-backend.md`.

**Tech Stack:** Prisma ORM 7 — **kandidat pin `prisma@7.10.1` + `@prisma/client@7.10.1` (menunggu persetujuan OD-1; jangan pasang tanpa pin — tag `latest` CLI = RC v8)** — dengan `prisma.config.ts` + driver adapter `@prisma/adapter-pg` (**pin major 7; patch = UNVERIFIED**) + `dotenv`, PostgreSQL hosted Supabase (PostgREST/PgBouncer transaction pooler), Supabase Auth (`getClaims()`), Next.js di Vercel, Bun + Turborepo + Biome.

**Spec:** `docs/architecture/0002-prisma-orm-backend.md` (ADR yang mengimplementasikan plan ini; berisi Evidence status: Proven vs Not-yet-verified).

## Global Constraints

- READ-ONLY terhadap `docs/PRD.md` — tidak diubah, tidak ada keputusan produk yang berubah.
- `db/scripts/001`–`007` **tidak diubah**; 006 = 76 assertions, 007 = 31 checks — jumlah pemeriksaan tidak boleh berkurang; klaim lulus hanya dari output eksekusi aktual.
- Runtime query pengguna **tidak pernah** memakai superuser, `service_role`, atau role `BYPASSRLS`.
- Mobile (Expo) **tidak pernah** memakai Prisma Client — hanya Supabase JS.
- Larangan alat tetap berlaku: tanpa Supabase CLI, Docker, Deno, local Supabase, Edge Functions.
- Tanpa `set_config(..., false)` dan tanpa `SET` level sesi pada jalur runtime — transaction-scoped only.
- Database hosted **tidak boleh dianggap kosong** sebelum Task 1.
- **`prisma migrate reset` dan auto-reset `migrate dev` (menerima prompt reset/drift) pada database hosted DILARANG tanpa persetujuan tertulis pengguna** (ADR 0002 Decision 13).
- **Drift atau objek tak dikenal pada diff baseline/migrasi → HENTIKAN proses, laporkan, jangan `resolve`/apply/reset sampai persetujuan** (ADR 0002 Decision 13).
- **Seluruh query data pengguna wajib lewat `withUserContext`**; aplikasi dilarang meng-import Prisma Client global/membuat `PrismaClient` sendiri — ditegakkan statis di Task 8 (ADR 0002 Decision 14).
- Dependency Prisma **wajib dipin eksplisit** (kandidat `prisma`/`@prisma/client` = `7.10.1`; `@prisma/adapter-pg` = pin major 7 dengan **patch UNVERIFIED**; `dotenv` wajib untuk `prisma.config.ts`) — instalasi tanpa versi menarik RC v8 yang tidak cocok dengan client stable.
- **Setiap tabel baru** dari Prisma Migrate wajib `ENABLE ROW LEVEL SECURITY` + revoke-grant default-deny + verifikasi sebelum dipakai (ADR 0002 Decision 12).
- Semua butuh koneksi database ditandai UNVERIFIED sampai dijalankan dan dicatat hasilnya.
- Open Decisions OD-1…OD-7 di ADR 0002 adalah **gate**: task yang bergantung padanya berhenti sampai pengguna menyetujui.
- Jangan menghapus dokumen rencana historis di `docs/superpowers/plans/`.
- Jangan commit tanpa melaporkan perubahan lebih dulu (ikuti workflow roadmap: review + persetujuan).

## Review Focus

1. **Koneksi runtime ternyata memakai role yang salah** (superuser/bypassrls) — paling mahal karena diam-diam mematikan RLS. Test: Task 2 memeriksa `rolsuper`/`rolbypassrls`/owner via query katalog; Task 7 mengulang pemeriksaan lewat DSN runtime aktual.
2. **Konteks identitas bocor antar-request di transaction pooler** — test: Task 7 leak test: dua request berurutan dengan sub berbeda pada pool sama; request kedua tidak boleh melihat baris request pertama.
3. **`prisma migrate` menghapus objek tak dikelola Prisma** (policy/grant/trigger/function/view) — test: setiap Task 4/5 wajib review diff SQL hasil generate terhadap daftar objek SQL-only di ADR 0002 §Decision 4, plus `007` sebagai pengawas.
4. **Query berjalan di luar transaksi/konteks** (pakai `db` alih-alih `tx` di dalam callback) — test: Task 6 memasang pengembangan fail-closed (akses tanpa `SET ROLE` → `42501`) dan Task 7 mengujinya.
5. **Gate V2 rusak oleh setup role baru** (grant/policy drift) — test: Task 8 menjalankan ulang 006 + 007 tanpa modifikasi dan membandingkan jumlah assertions/checks persis 76/31.
6. **Role mewarisi privilege `authenticated` tanpa `SET ROLE`** (PG≥16 inherit membership) → fail-closed meleset — test: Task 2 `has_table_privilege('bookrate_app',…) = false` + remediasi `INHERIT FALSE`.
7. **Tabel baru tanpa RLS / client mentah dipakai di aplikasi** — test: Task 4 (workflow tabel baru = enable RLS + default-deny) dan Task 8 (grep statis: tidak ada import Prisma Client global di `apps/web`).

---

### Task 1: Verifikasi kondisi database Supabase saat ini

**Files:**
- Create: `docs/superpowers/plans/2026-11-15-db-verification-report.md` (hasil pemeriksaan read-only)

**Interfaces:**
- Produces: laporan kondisi DB (versi PG, isi `public`, role yang ada, grant default, status skrip 001–007) yang menjadi input gate OD-3 (baseline) dan Task 2.

- [ ] **Step 1: Susun daftar pemeriksaan read-only** (tanpa DDL, tanpa mutasi) — **TIGA fence terpisah; jalankan dalam Run TERPISAH dan berurutan. DILARANG menggabungkan beberapa fence dalam satu script/Run.**

**FENCE A — semua versi (PG<16 & PG≥16), jalankan lebih dulu — pemeriksaan versi EKSPLISIT + pemeriksaan versi-netral (TANPA kolom opsi membership):**

```sql
select version();
select current_setting('server_version_num')::int as server_version_num;
  -- GATE VERSI EKSPLISIT: 160000 = PG16. Baca & CATAT hasil ini SEBELUM memilih fence
  -- berikutnya: FENCE B1 bila < 160000, FENCE B2 bila >= 160000.
select nspname from pg_namespace where nspname in ('public','auth');
select tablename, rowsecurity from pg_tables where schemaname = 'public' order by tablename;
select count(*) as policy_count from pg_policies where schemaname = 'public';
select rolname, rolsuper, rolbypassrls, rolinherit, rolcreatedb, rolcreaterole, rolcanlogin
  from pg_roles where rolname in ('postgres','anon','authenticated','service_role','bookrate_app');
select grantee, table_name, privilege_type from information_schema.table_privileges
  where table_schema = 'public' and grantee in ('anon','authenticated') order by table_name;
select defaclrole::regrole, defaclobjtype, defaclacl from pg_default_acl;
select prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'auth' and p.proname = 'uid';
select count(*) from information_schema.tables where table_name = '_prisma_migrations';
```

FENCE A **tidak memuat satu pun query `pg_auth_members` dengan kolom opsi** — karena itu aman dijalankan di semua versi.

**FENCE B — query membership options; jalankan HANYA SATU cabang, dalam Run TERPISAH kedua (setelah FENCE A):**

*Cabang B1 — **PostgreSQL < 16** (`server_version_num < 160000`):*

```sql
-- PG<16: satu-satunya kolom opsi di pg_auth_members adalah admin_option (ada sejak 9.1).
-- Dua kolom opsi yang baru tersedia di PG16 tidak ditulis di fence ini sama sekali.
select r.rolname, g.rolname as member_of, m.admin_option
  from pg_auth_members m join pg_roles r on r.oid = m.member
  join pg_roles g on g.oid = m.roleid
  where r.rolname = 'bookrate_app';
select rolname, rolinherit from pg_roles where rolname = 'bookrate_app';
  -- rolinherit = false → inherit dinetralisasi lewat atribut role (ADR 0002 Decision 7).
```

*Cabang B2 — **PostgreSQL ≥ 16** (`server_version_num >= 160000`):*

```sql
-- PG16+: inherit_option & set_option BARU tersedia mulai PG16 (admin_option sudah ada sejak 9.1).
select r.rolname, m.inherit_option, m.set_option, m.admin_option
  from pg_auth_members m join pg_roles r on r.oid = m.member
  join pg_roles g on g.oid = m.roleid
  where r.rolname = 'bookrate_app';
  -- 0 baris = role 'bookrate_app' BELUM ADA (hasil kosong karena role belum dibuat —
  -- bedakan dari "query tidak dijalankan karena versi lama").
```

**ATURAN EKSEKUSI (wajib, anti-gabung):**
1. Jalankan **FENCE A** lebih dulu; catat `server_version_num`.
2. Pilih **hanya satu** cabang FENCE B sesuai hasil langkah 1; jalankan sebagai **Run terpisah**.
3. Cabang yang tidak dipilih **tidak disalin** ke script mana pun — **dilarang menyalin B1 dan B2 bersamaan** dalam satu script/Run.
4. Pada PG<16, **cabang B2 tidak pernah dijalankan**: kolom `inherit_option`/`set_option` tidak ada → error *parse-time* (WHERE/komentar tidak bisa mencegahnya, karena itu pemisahan fence ini).

- [ ] **Step 2: Jalankan pemeriksaan via Supabase Dashboard SQL Editor (read-only)**

Expected: **Run terpisah & berurutan** (FENCE A, lalu **satu** cabang FENCE B sesuai versi); laporan berisi hasil aktual tiap baris; **tidak ada asumsi database kosong** — bila `public` berisi tabel, catat daftar lengkapnya.

- [ ] **Step 3: Cocokkan dengan `db/SCHEMA_STATE.md`**

Expected: selisih antara status `pending` di dokumen dengan isi DB aktual didokumentasikan (mis. skrip pernah dijalankan manual tanpa dicatat).

- [ ] **Step 4: Periksa `auth.uid()` runtime (OD-7)**

Expected: `prosrc` memuat `current_setting('request.jwt.claim.sub'` dan `request.jwt.claims` — cocokkan dengan sumber `supabase/auth` migration `20211202183645_update_auth_uid.up.sql`. Bila berbeda, catat sebagai temuan dan T-08 di Task 7 wajib diverifikasi sebelum arsitektur dianggap final.

- [ ] **Step 5: Tulis laporan dan laporkan ke pengguna; hentikan untuk persetujuan OD-3 (baseline strategy) sebelum Task 4**

Run: tulis `docs/superpowers/plans/2026-11-15-db-verification-report.md`
Expected: laporan tersimpan; keputusan baseline menunggu persetujuan.

---

### Task 2: Finalisasi role database dan keamanan RLS

**Files:**
- Create: `db/scripts/008_app_role.sql` (idempoten; role runtime + membership; **bukan** pengganti 001–007)
- Modify: `db/SCHEMA_STATE.md` (tambahkan baris `008_app_role.sql`)

**Interfaces:**
- Consumes: hasil Task 1 (versi PG → semantik INHERIT; apakah `bookrate_app` sudah ada).
- Produces: role `bookrate_app` yang dipakai `DATABASE_URL`; aturan grant tetap utuh untuk Task 4/7.

- [ ] **Step 1: Tulis `db/scripts/008_app_role.sql`** — idempoten (DO block / exception-safe) dan **TANPA password atau placeholder rahasia apa pun**:

```sql
-- 008_app_role.sql (draf — final setelah versi PG hasil Task 1 diketahui)
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'bookrate_app') then
    create role bookrate_app login noinherit nobypassrls;
    -- TANPA klausa password: password di-set terpisah via Dashboard / ALTER ROLE
    -- yang TIDAK di-commit (keputusan ADR 0002 Decision 7).
  end if;
end $$;

-- Membership dengan opsi EKSPLISIT sesuai versi PG (F-1.2):
--   PG >= 16: grant authenticated to bookrate_app with inherit false, set true;
--   PG <  16: grant authenticated to bookrate_app;   -- opsi WITH INHERIT/SET tidak ada;
--             netralisasi inherit memakai atribut role NOINHERIT (sudah di create role).
-- TANPA grant langsung ke tabel mana pun.
-- Klausa revoke final (mis. privilege PUBLIC pada database) DITENTUKAN di sini hanya
-- setelah versi PG + pg_default_acl hasil Task 1 diketahui — jangan menebak.
```

Catatan: bentuk klausa grant yang tepat mengikuti versi PG hasil Task 1 (PG<16 = atribut role-level; PG≥16 = opsi membership per `pg_auth_members`) — **jangan ditebak sebelum versi diketahui**.

- [ ] **Step 2: Jalankan 008 via SQL Editor; perbarui `db/SCHEMA_STATE.md`**

Expected: baris `008_app_role.sql` applied & verified dengan tanggal aktual.

- [ ] **Step 3: Verifikasi katalog — jalankan dalam DUA fence terpisah & berurutan (T-01, T-09, termasuk anti-inherit F-1.2)**

**FENCE A — semua versi (PG<16 & PG≥16), jalankan lebih dulu — pemeriksaan versi EKSPLISIT + pemeriksaan kompatibel semua versi (TANPA `inherit_option`/`set_option`):**

```sql
select current_setting('server_version_num')::int as server_version_num;
  -- PEMERIKSAAN VERSI EKSPLISIT: >= 160000 = PG16. Wajib dibaca & dicatat SEBELUM FENCE B.
select rolsuper, rolbypassrls, rolinherit from pg_roles where rolname = 'bookrate_app';  -- false, false, false
select count(*) from pg_class c join pg_roles r on r.oid = c.relowner
  where r.rolname = 'bookrate_app';                                          -- 0 (bukan owner tabel)
select has_table_privilege('bookrate_app','public.profiles','select');        -- false (wajib: TIDAK mewarisi grant authenticated)
select has_table_privilege('bookrate_app','public.books','insert');           -- false (wajib)
select has_schema_privilege('bookrate_app','public','create');                -- false
select r.rolname, m.admin_option                                              -- admin_option ADA di semua versi (sejak 9.1)
  from pg_auth_members m join pg_roles r on r.oid = m.member
  join pg_roles g on g.oid = m.roleid
  where r.rolname='bookrate_app' and g.rolname='authenticated';              -- 1 baris = membership ada; admin_option diharapkan false
```

Pada **PG<16, FENCE A sudah cukup**: inherit dinilai dari `rolinherit` (atribut role — baris 2, ADR 0002 Decision 7) dan `admin_option` tetap terbaca; **tidak ada** satu pun query `inherit_option`/`set_option` di fence ini.

**FENCE B — **KHUSUS PostgreSQL ≥ 16**, Run TERPISAH kedua — TIDAK memuat pemeriksaan versi (prasyaratnya = hasil `server_version_num` dari FENCE A):**

```sql
select m.inherit_option, m.set_option from pg_auth_members m
  join pg_roles r on r.oid = m.member join pg_roles g on g.oid = m.roleid
  where r.rolname='bookrate_app' and g.rolname='authenticated';
```

**ATURAN EKSEKUSI (wajib, anti-gabung):**
1. Jalankan **FENCE A** lebih dulu; catat `server_version_num`.
2. **FENCE B hanya jika `>= 160000`**, sebagai **Run terpisah**; bila `< 160000` → **FENCE B tidak dijalankan dan tidak disalin** ke script mana pun.
3. **DILARANG menggabungkan FENCE A dan FENCE B dalam satu script/Run.**
4. Pada PG<16 cukup FENCE A — kolom `inherit_option`/`set_option` tidak ada di versi itu (error *parse-time* bila dipaksa; WHERE/komentar tidak bisa mencegahnya, karena itu pemisahan fence ini).

Expected FENCE A: `server_version_num` tercatat; semua FALSE/0 sesuai. Expected FENCE B (hanya PG≥16): `inherit_option=false, set_option=true`. **Catat output aktual di laporan, jangan klaim tanpa eksekusi.**

- [ ] **Step 4: Uji fail-closed (T-02)**

```sql
-- koneksi sebagai bookrate_app, TANPA SET LOCAL ROLE:
select * from public.profiles;
```

Expected: ERROR 42501; catat hasil sebenarnya.

- [ ] **Step 5: Remediasi bila inherit terdeteksi (F-1.2)** — dipicu bila `has_table_privilege(...) = true` ATAU (PG≥16 saja) `pg_auth_members.inherit_option = true` ATAU T-02 tidak menghasilkan `42501`.

**Syarat versi (N-6): cabang di bawah hanya boleh dipilih SETELAH `server_version_num` hasil Task 1 diketahui. Jalankan HANYA SATU cabang yang sesuai versi — jangan menyalin kedua blok ke dalam satu script.**

*Cabang A — PG ≥ 16 (`server_version_num >= 160000`):*

```sql
revoke authenticated from bookrate_app;
grant authenticated to bookrate_app with inherit false, set true;
```

*Cabang B — PG < 16 (`server_version_num < 160000`):* klausa `WITH INHERIT/SET` tidak ada di versi ini → cukup pastikan atribut role `NOINHERIT` aktif (sudah diset saat `create role`) lalu grant polos:

```sql
alter role bookrate_app noinherit;
grant authenticated to bookrate_app;
```

Expected: ulangi Step 3–4 (pada PG<16 lewati query `pg_auth_members` sesuai catatan Step 3) sampai semua `false` dan T-02 = `42501`. **Jangan lanjut ke task berikut sebelum remediasi lulus** — bila tetap gagal, hentikan dan laporkan (jangan mengubah 001–007).

- [ ] **Step 6: Commit**

```bash
git add db/scripts/008_app_role.sql db/SCHEMA_STATE.md
git commit -m "feat(db): add bookrate_app runtime role script with fail-closed verification"
```

---

### Task 3: Lokasi Prisma schema dan Prisma Client dalam monorepo

**Files:**
- Create: `packages/db/package.json` (`@bookrate/db`), `packages/db/src/client.ts` (kerangka saja — **diisi di Task 4** setelah dependency terpasang; **satu-satunya** lokasi `new PrismaClient`), `packages/db/README.md`
- Modify: `tsconfig.base.json` (path alias opsional), `turbo.json` (task `db:generate` bila perlu)

**Interfaces:**
- Produces: paket `@bookrate/db` yang diekspor sebagai satu-satunya pintu Prisma Client (Task 5 mengonsumsinya; Task 6 menambahkan helper konteks di paket ini). **API publik paket = helper saja, tanpa `PrismaClient` mentah** (ADR 0002 Decision 14).

- [ ] **Step 1: Buat kerangka paket `packages/db`** dengan `private: true`, tanpa dependency Prisma dulu (install menunggu OD-1 dan persetujuan instalasi dependency)

Expected: `bun run typecheck` tetap pass dengan kerangka kosong.

- [ ] **Step 2: Tulis `packages/db/README.md`** yang menyatakan aturan: client hanya di-import dari server, mobile dilarang meng-import, semua akses data user wajib lewat helper Task 6, dan **ekspor paket dibatasi** — aplikasi hanya menerima `withUserContext` (bukan instance `PrismaClient` mentah); `PrismaClient` berada di dalam paket ini saja (ADR 0002 Decision 14).

- [ ] **Step 3: Verifikasi build**

Run: `bun run typecheck && bun run lint`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/db tsconfig.base.json turbo.json
git commit -m "feat(db): scaffold @bookrate/db package for Prisma schema and client"
```

*(Modifikasi `tsconfig.base.json`/`turbo.json` hanya bila ternyata diperlukan — bawa perubahan minimum.)*

---

### Task 4: Strategi baseline dan urutan migration

**Gate: OD-1 (versi Prisma) dan OD-3 (baseline) harus disetujui lebih dulu — hasil Task 1 menentukan opsi.**

**Files:**
- Create: `packages/db/schema.prisma`, `packages/db/prisma.config.ts` (wajib pada Prisma 7), `packages/db/migrations/0_init/migration.sql` (baseline — lihat Step 3a), `docs/superpowers/plans/2026-11-15-migration-workflow.md`
- Modify: `packages/db/src/client.ts` (**satu-satunya** lokasi `new PrismaClient` — diisi dengan adapter `PrismaPg` + `DATABASE_URL`, N-2), `db/README.md` (bagian urutan eksekusi bila perlu)

**Interfaces:**
- Consumes: hasil Task 1 (isi DB aktual), Task 3 (paket `@bookrate/db`).
- Produces: baseline migration + aturan kerja migrasi yang dipakai Task 5–8.

- [ ] **Step 1: Install dependency Prisma dengan PIN versi di `packages/db`** (F-4.2)

Run: `bun add -d prisma@7.10.1 && bun add @prisma/client@7.10.1 && bun add @prisma/adapter-pg@<major-7> && bun add dotenv` (di `packages/db`)
Expected: lockfile berubah dengan versi `7.10.1` (kandidat sesuai OD-1 — **menunggu persetujuan final sebelum langkah ini**); **dilarang** `bun add prisma` tanpa versi (tag `latest` = `8.0.0-rc.33`, RC, tidak cocok dengan client stable `7.10.1`). `@prisma/adapter-pg` **wajib dipin pada major 7 yang kompatibel** — **nomor patch final = UNVERIFIED** (cek dist-tags + peer dependency di registry saat implementasi; **jangan mengarang angka patch**). `dotenv` wajib terpasang karena `prisma.config.ts` memakai `import 'dotenv/config'` (N-5). Laporkan ke pengguna sebelum commit.

- [ ] **Step 2: Tulis `schema.prisma` + `prisma.config.ts` (Prisma 7)**

`schema.prisma` — hanya objek kategori-Prisma: 4 enum (`reading_status`, `activity_type`, `notification_type`, `library_visibility`), 9 tabel, kolom, PK/FK internal, unique constraint, index standar. **Tanpa** view, fungsi, trigger, policy, grant, **check constraint** (semua check — termasuk `004:21-24` — tetap SQL, ADR 0002 Decision 3/4). FK `profiles.id → auth.users(id)` **tidak** dimodelkan di Prisma (tetap di SQL 002) — tandai komentar di schema. Generator **wajib `output`** (Prisma 7 tidak lagi menulis ke `node_modules`).

`prisma.config.ts` — wajib pada Prisma 7 (F-4.3): `defineConfig({ datasource: { url: process.env.DIRECT_URL } })` **hanya untuk CLI migrasi**, dengan **env loading eksplisit** (`import 'dotenv/config'` — CLI Prisma 7 tidak memuat env otomatis; `dotenv` = dependency wajib di Step 1). Runtime **tidak** memakai config ini (runtime = adapter `@prisma/adapter-pg` dengan `DATABASE_URL`, Task 5). `directUrl` tidak lagi ada di schema Prisma 7 — pemetaan runtime/migrasi ada di config ini.

`packages/db/src/client.ts` — **satu-satunya lokasi `new PrismaClient(...)` di seluruh repo (N-2)**: `new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }) })` + singleton (global cache saat dev hot-reload), tanpa logic konteks. Instance dipakai **internal** oleh `user-context.ts` (Task 6) dan **tidak dire-ekspor** dari `packages/db/src/index.ts` — ekspor publik paket hanya `withUserContext` (+ tipe yang diperlukan). `apps/web`/`apps/mobile` tidak pernah membuat client sendiri.

Expected: `prisma validate` PASS; `prisma generate` dijalankan **eksplisit** (Prisma 7 tidak lagi implicit generate setelah `migrate`).

- [ ] **Step 3: Buat baseline mengikuti kondisi nyata dari Task 1 (OD-3) — urutan WAJIB: (a) file baseline, (b) tiga perbandingan, (c) `resolve`.**

**(a) Buat FILE baseline sebelum `migrate resolve` (N-3)** — `prisma migrate resolve --applied` menolak bila migration tidak ada di direktori `migrations/`:

1. Verifikasi perintah `prisma migrate diff --from-empty --to-schema --script` lewat `prisma migrate diff --help` (**flag = UNVERIFIED sampai CLI terpasang; jangan mengarang sintaks**).
2. Buat file baseline dengan nama konsisten (kandidat): `prisma migrate diff --from-empty --to-schema --script > packages/db/migrations/0_init/migration.sql`.
3. **Review manual SQL hasil generate baris per baris** — hanya struktur PSL (enum/tabel/kolom/PK-FK/unique/index standar). **Objek SQL-only bukan bagian baseline dan tidak boleh dianggap otomatis tercakup**: RLS, policies, grants, triggers, functions, views, partial index, CHECK constraint, FK ke `auth.users` — kewajiban keamanan tetap di skrip SQL `db/scripts/`.
4. `0_init` (nama direktori + flag perintah) = **UNVERIFIED** — konfirmasi saat implementasi.

**(b) WAJIB tiga perbandingan** (F-3.1): history migrasi ↔ Prisma schema ↔ database hosted. Gunakan flag Prisma 7 (`--to-schema`, `--from-config-datasource`, `--from-migrations`) — **verifikasi dulu lewat `prisma migrate diff --help`** (seluruh flag di bawah = UNVERIFIED sampai CLI terpasang; `--from-url`/`--to-schema-datamodel` sudah dihapus di v7):

1. **Hosted vs schema:** `prisma migrate diff --from-config-datasource --to-schema` → **harus nol diff DDL struktural** (diinterpretasi: hanya objek yang terwakili PSL; check constraint/policy/trigger/view/grant di luar cakupan diff — uji dry-run ini juga memverifikasi perilaku diff terhadap check constraint, F-4.4).
2. **History vs schema:** `prisma migrate diff --from-migrations ./migrations --to-schema` → nol diff (konsistensi file).
3. **History vs hosted — WAJIB diperiksa nyata, bukan hanya disebut (N-4):** jalankan perintah langsung kandidat `prisma migrate diff --from-migrations ./migrations --to-config-datasource` → nol diff (**flag = UNVERIFIED, cek `--help`; Prisma 7 hanya mengizinkan satu datasource per diff sehingga perbandingan dua-URL tidak tersedia**). Bila Prisma 7 ternyata tidak mendukung perintah langsung ini, pakai alternatif yang benar-benar bisa dijalankan: simpan **output mentah** perbandingan (1) dan (2) ke `docs/superpowers/plans/2026-11-15-db-verification-report.md`, lalu nyatakan transitif *"(1) = ∅ dan (2) = ∅ → history = hosted"* **dengan mengutip kedua output di laporan**. **Tanpa output tersimpan, perbandingan dianggap BELUM diperiksa** — dilarang menyatakan history = hosted berdasarkan asumsi. Cakupan ketiga perbandingan tetap **hanya objek yang didukung Prisma**; objek SQL-only tidak dibuktikan oleh diff ini (tetap dijaga `007` + aturan `db/README.md`).

**(c) Baru setelah (a) dan (b) lolos:** `prisma migrate resolve --applied 0_init`.

Urutan langkah mengikuti hasil Task 1: **DB kosong** → jalankan skrip SQL 001–005 dulu (workflow yang ada), baru ketiga perbandingan di atas; **DB sudah berisi tabel** → lakukan diff hosted-vs-schema **sebelum** menyusun baseline, review baris per baris.

- **ATURAN HENTI (F-3.3):** bila diff menunjukkan **drift atau objek/tabel/kolom yang tidak dikenal** (tidak cocok dengan laporan Task 1) → **HENTIKAN**, tulis temuan di laporan, **jangan `migrate resolve`, jangan apply, dan JANGAN `migrate reset`** sampai pengguna menyetujui. `prisma migrate reset` / menerima prompt reset `migrate dev` pada database hosted **DILARANG tanpa persetujuan tertulis** (ADR 0002 Decision 13).

Expected: `prisma migrate status` menunjukkan baseline applied; **tidak ada** perubahan pada tabel/policy/grant yang ada; **output mentah ketiga perbandingan (perintah + hasil) tersimpan di laporan verifikasi**.

- [ ] **Step 4: Tulis `docs/superpowers/plans/2026-11-15-migration-workflow.md`** — urutan wajib tiap perubahan skema: (1) edit `schema.prisma` ATAU edit skrip SQL (untuk objek keamanan/check constraint), (2) `migrate dev --create-only` (**dilarang** menerima reset/auto-apply; `prisma migrate reset` hosted = persetujuan tertulis), (3) **review manual SQL diff** terhadap daftar objek SQL-only di ADR 0002 Decision 4 (policy/grant/trigger/function/view/RLS/check constraint), (4) apply via `migrate resolve`/`migrate deploy` sesuai hasil review — **HENTI bila ada drift/objek tak dikenal**, (5) jalankan skrip SQL idempoten terkait via SQL Editor, (6) **tabel baru: wajib `ENABLE ROW LEVEL SECURITY` + revoke-grant default-deny sebelum dipakai** (ADR 0002 Decision 12) + verifikasi `pg_policies`, (7) jalankan `prisma generate` eksplisit bila generator berubah, (8) jalankan `007` + `006`, (9) catat `SCHEMA_STATE.md`.

- [ ] **Step 5: Verifikasi**

Run: `prisma migrate status`; jalankan `007_verify_schema.sql` via SQL Editor.
Expected: status clean; `VERIFY SCHEMA: ALL 31 CHECKS PASSED` (output aktual).

- [ ] **Step 6: Commit**

```bash
git add packages/db/schema.prisma packages/db/prisma.config.ts packages/db/migrations docs/superpowers/plans/2026-11-15-migration-workflow.md db/README.md
git commit -m "feat(db): prisma baseline with hybrid migration workflow"
```

---

### Task 5: Integrasi Prisma dengan Next.js

**Files:**
- Create: `apps/web/src/lib/db.ts` (**re-export helper saja — TANPA `new PrismaClient`**), `apps/web/src/lib/verify-token.test.ts` (token palsu)
- Modify: `apps/web` package.json (dependency `@bookrate/db`), `.env.example` (variabel baru)

**Interfaces:**
- Consumes: `@bookrate/db` (Task 3/4).
- Produces: akses data user **hanya** lewat `withUserContext` (Task 6). Instance `PrismaClient` **hanya hidup di `packages/db/src/client.ts`** (diisi Task 4) dan tidak pernah diekspor mentah ke aplikasi (ADR 0002 Decision 14).

- [ ] **Step 1: Tambahkan `@bookrate/db` sebagai workspace dependency `apps/web`**

Run: `bun install`
Expected: `apps/web` bisa `import { withUserContext } from '@bookrate/db'`; **bukan** `new PrismaClient(...)` — pembuatan client hanya di `packages/db/src/client.ts`.

- [ ] **Step 2: Buat/muat `apps/web/src/lib/db.ts` sebagai re-export helper saja (N-2)** — file ini **DILARANG** memuat `new PrismaClient(...)` maupun import dari `@prisma/client`; cukup re-export aman, mis. `export { withUserContext } from '@bookrate/db'` (atau hapus file bila tidak diperlukan). Adapter Prisma 7 (F-4.3) dipasang di `packages/db/src/client.ts`, bukan di sini.

- [ ] **Step 3: Perbarui `.env.example`** (tanpa nilai rahasia):

```
# Server-only (Prisma) — never NEXT_PUBLIC_*, never mobile
DATABASE_URL=          # transaction pooler Supabase (port 6543) — runtime via adapter; ?pgbouncer=true = OD-4 (UNVERIFIED dengan adapter)
DIRECT_URL=            # koneksi migrasi — hanya dibaca prisma.config.ts (CLI migrate/DDL), tidak pernah runtime
```

- [ ] **Step 4: Verifikasi token palsu ditolak SEBELUM transaksi database (F-5.5)**

Buat test integrasi di `apps/web` (mis. `apps/web/src/lib/verify-token.test.ts`): request/handler dengan token yang tidak lolos verifikasi `supabase.auth.getClaims()` (signature salah/kedaluwarsa) → **ditolak (401), dan tidak ada satu pun query/transaksi Prisma yang terpanggil** (mock/spy `withUserContext` = tidak dipanggil).
Expected: test PASS dengan output aktual; token valid → `withUserContext` dipanggil dengan `sub` dari claims terverifikasi.

- [ ] **Step 5: Verifikasi**

Run: `bun run typecheck && bun run lint && bun run build`
Expected: PASS; tidak ada `DATABASE_URL` di bundel client (periksa output build/`NEXT_PUBLIC_`).

- [ ] **Step 6: Commit**

```bash
git add apps/web packages/db .env.example
git commit -m "feat(web): integrate withUserContext helper via @bookrate/db"
```

---

### Task 6: Konteks pengguna dalam transaksi Prisma

**Files:**
- Create: `packages/db/src/user-context.ts` (`withUserContext(sub, fn)`), `packages/db/src/user-context.test.ts`
- Modify: `packages/db/src/index.ts` (ekspor)

**Interfaces:**
- Consumes: instance internal `PrismaClient` (`packages/db/src/client.ts`, Task 4 — **tidak** diekspor dari `index.ts`), claims `sub` hasil `supabase.auth.getClaims()` (Task 5 integrasi Next.js).
- Produces: `withUserContext<T>(sub: string, fn: (tx: Prisma.TransactionClient) => Promise<T>): Promise<T>)` — **satu-satunya** pintu akses data user-scoped untuk Task 7 (ADR 0002 Decision 14).

- [ ] **Step 1: Tulis test fail-closed** (`packages/db/src/user-context.test.ts`):
  - test: `withUserContext` dengan sub valid → callback menerima `tx`; query di dalam callback mengembalikan `auth.uid()` = sub;
  - test: query yang berjalan lewat `prisma` (bukan `tx`) di dalam callback → gagal `42501`;
  - test: callback melempar error → transaksi rollback dan error propagate;
  - test: `sub` **kosong/kosong-string** → throw sebelum transaksi dibuka (tidak ada query DB);
  - test: `sub` **bukan UUID valid** (mis. `"bukan-uuid"`, `"123"`, `undefined`) → throw sebelum transaksi dibuka.

- [ ] **Step 2: Jalankan test — pastikan FAIL** (helper belum ada)

Run: `bun test packages/db/src/user-context.test.ts`
Expected: FAIL (module not found / assertion).

- [ ] **Step 3: Implement `withUserContext`** — `prisma.$transaction(async tx => { SET LOCAL ROLE authenticated; set_config('request.jwt.claims', JSON.stringify({sub, role:'authenticated'}), true); return fn(tx); })` — semua statement via `tx.$executeRaw`/`$queryRaw` parameterized; **dilarang** `set_config(..., false)` dan `SET` sesi; **validasi `sub` di awal**: throw bila kosong ATAU tidak cocok pola UUID (`/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i`) **sebelum** transaksi dibuka. API `$transaction` = Prisma 7 (OD-1; docs default prisma.io kini v8).

- [ ] **Step 4: Jalankan test — lewati hanya yang butuh DB nyata**

Run: `bun test packages/db/src/user-context.test.ts`
Expected: test unit pass; test yang butuh koneksi DB ditandai dan **tidak diklaim lulus** sampai Task 7.

- [ ] **Step 5: Commit**

```bash
git add packages/db
git commit -m "feat(db): transaction-scoped user context helper for Prisma"
```

---

### Task 7: Pengujian RLS melalui Prisma

**Files:**
- Create: `packages/db/tests/rls-through-prisma.test.ts`

**Interfaces:**
- Consumes: `withUserContext` (Task 6), `DATABASE_URL` runtime (Task 5/OD-4).

- [ ] **Step 1: Tulis matriks tes** — masing-masing via koneksi runtime `DATABASE_URL` (transaction pooler):
  - T-P1: query tanpa konteks → ditolak `42501`;
  - T-P2: user A tidak membaca **data privat user B** (0 row). **Fixture eksplisit (F-5.6):** satu baris `library_entries` milik user B dengan `visibility = 'PRIVATE'` (judul/progress harusnya tidak terbaca A) **dan** satu baris `reviews` milik user B — keduanya dibuat di dalam suite dengan cleanup rollback;
  - T-P3: user A tidak mengubah **data user B** (error policy). **Fixture eksplisit:** baris `library_entries` PRIVATE milik B (percobaan `UPDATE notes`) **dan** baris `reviews` milik B (percobaan `UPDATE rating`) → keduanya ditolak policy;
  - T-P4: konteks tidak bocor — `withUserContext(subA, …)` commit lalu `withUserContext(subB, …)` pada pool sama → B tidak melihat baris A;
  - T-P5: transaksi gagal (throw di callback) → jalur berikutnya bersih, tanpa residu konteks;
  - T-P6: role runtime tanpa privilege administratif (cek `has_table_privilege`/`has_schema_privilege` DARI koneksi runtime);
  - T-P7: RLS tetap bekerja di pooled connection (ulangi T-P2 lewat port 6543 `pgbouncer=true`);
  - T-P8: konfirmasi `auth.uid()` membaca claims yang kita set (OD-7/T-08);
  - T-P9: **transaksi paralel (F-5.3)** — dua `withUserContext` berjalan **bersamaan** (Promise.all) dengan sub berbeda pada dua koneksi pool berbeda → masing-masing hanya melihat baris miliknya sendiri (tidak ada cross-read, tidak ada error antar transaksi).

- [ ] **Step 2: Jalankan suite**

Run: `bun test packages/db/tests/rls-through-prisma.test.ts`
Expected: seluruh tes **aktual** pass — catat output per tes; **dilarang** menulis lulus tanpa output.

- [ ] **Step 3: Laporkan hasil ke pengguna** sebelum melanjutkan.

- [ ] **Step 4: Commit**

```bash
git add packages/db/tests
git commit -m "test(db): RLS verification through Prisma transaction context"
```

---

### Task 8: Verifikasi script 006 dan 007 tanpa pengurangan pemeriksaan

**Files:**
- Modify: `db/SCHEMA_STATE.md` (status verified aktual)

**Interfaces:**
- Consumes: seluruh setup Task 2/4/6/7.

- [ ] **Step 1: Hitung jumlah pemeriksaan sebelum dijalankan (statis)**

Run: `grep -c "_t006_record\|t006_" db/scripts/006_negative_tests.sql` dan pastikan jumlah assertion bernilai **76**; hitung blok `union all select` di `007_verify_schema.sql` = **31**.
Expected: 76 dan 31 — **tanpa membuka/edit file**, hanya verifikasi isi.

- [ ] **Step 2: Pemeriksaan statis keamanan Prisma (F-5.2, ADR 0002 Decision 14)**

Run:
```bash
grep -rn "new PrismaClient\|from '@prisma/client'" apps/web/src apps/mobile 2>/dev/null   # harus NOL hasil
grep -rn "new PrismaClient" packages/db/src                                                # HARUS hanya packages/db/src/client.ts (lokasi tunggal, N-2)
grep -n "PrismaClient" packages/db/src/index.ts                                            # HARUS nol — ekspor publik paket tanpa client mentah
grep -rn "withUserContext" apps/web/src | head                                             # akses data user memakai helper
```
Expected: tidak ada import/instantiasi Prisma Client di `apps/web`/`apps/mobile` (client hanya hidup di `packages/db/src/client.ts`, dan tidak diekspor dari `index.ts`); `apps/web/src/lib/db.ts`, bila ada, hanya re-export helper; setiap jalur data user memakai `withUserContext`. Bila melanggar → perbaiki kode, **jangan** longgarkan aturan.

- [ ] **Step 3: Jalankan `006_negative_tests.sql` via SQL Editor — tanpa modifikasi apapun**

Expected: output aktual `ALL NEGATIVE TESTS PASSED` (76); bila gagal, diagnosa penyebab dari setup baru (mis. grant drift) — **perbaiki setup, bukan skripnya**.

- [ ] **Step 4: Jalankan `007_verify_schema.sql` via SQL Editor — tanpa modifikasi apapun**

Expected: output aktual `VERIFY SCHEMA: ALL 31 CHECKS PASSED`; cek 11/31 (owner = `postgres`) harus tetap terpenuhi → ini alasan OD-2 memilih `postgres` sebagai role migrasi.

- [ ] **Step 5: Perbarui `db/SCHEMA_STATE.md`** (tanggal + hasil aktual untuk 006/007 dan baris 008) dan laporkan Gate V2.

- [ ] **Step 6: Commit**

```bash
git add db/SCHEMA_STATE.md
git commit -m "docs(db): record verified 006/007 results after Prisma adoption"
```

---

### Task 9: Dokumentasi environment variables dan deployment

**Files:**
- Modify: `README.md` (seksi Environment), `.env.example` (final), `db/README.md` (ringkasan workflow final), `docs/ROADMAP.md` (tandai tahap yang selesai)

**Interfaces:**
- Consumes: semua keputusan Task 1–8.

- [ ] **Step 1: Finalisasi `.env.example`** — `DATABASE_URL`, `DIRECT_URL` (server-only), pastikan tidak ada kredensial, tidak ada variabel `NEXT_PUBLIC_*` yang memuat DSN, `EXPO_PUBLIC_*` tetap hanya publishable key.

- [ ] **Step 2: Update README Environment/Security** — bagaimana env diisi di Vercel (Secret), pratinjau lokal via `.env.local` yang tidak di-commit.

- [ ] **Step 3: Update `docs/ROADMAP.md`** — tandai tahap Adopsi Prisma yang selesai dengan rujukan bukti (output tes Task 7/8); sisa OD yang belum disetujui tetap terdaftar sebagai Open Decision.

- [ ] **Step 4: Verifikasi akhir**

Run: `git status --short`, `bun run typecheck && bun run lint && bun run build`
Expected: pass; daftar file berubah dilaporkan.

- [ ] **Step 5: Commit**

```bash
git add README.md .env.example db/README.md docs/ROADMAP.md
git commit -m "docs: finalize env and deployment documentation for Prisma stack"
```
