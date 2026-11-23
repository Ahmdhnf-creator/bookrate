# BookRate Task 06 — Extend README and Add Architecture Decision Record (Implementation Plan)

**Status:** Planned — dijalankan pada sesi yang sama setelah plan lolos pemeriksaan konflik (sesuai instruksi user: plan → implementasi → verifikasi)
**Date:** 2026-11-06
**Parent plan:** `docs/superpowers/plans/task-01-backend-project-setup.md` (Task 6 section)
**Pattern reference:** `task-05-client-safe-env-example.md`, `task-04-reserve-app-directories.md`
**Scope note:** Tidak ada commit; Task 7 tidak dimulai; PRD/ROADMAP/hasil Task 1–5 tidak disentuh.

## 1. Tujuan

1. **README.md** — perluasan **additive** (heading `# bookrate` wajib dipertahankan): status, stack, layout repo, perintah, lingkungan, dan keamanan → dokumentasi onboarding.
2. **ADR** — `docs/architecture/0001-supabase-first-backend.md`: catatan keputusan arsitektur yang diterima (Supabase-first, web MVP prioritas, mobile deferred, custom API deferred sebagai penyesuaian scope).

## 2. Kondisi repository (setelah Task 5, diverifikasi)

- `README.md` = **10 byte**: `# bookrate` **tanpa trailing newline** (identik HEAD; `git show HEAD:README.md` juga 10 byte) — sesuai ekspektasi Step 1 plan utama.
- `docs/architecture/` **tidak ada** (belum ada ADR).
- Struktur: `docs/` berisi PRD, ROADMAP, superpowers/{specs,plans}; `apps/` reserved; `packages/config`; `.env.example`.
- Baseline: HEAD `0972869`; PRD hash `6f1fe4f9…1313e`; `git status` = 2 modified (PRD/ROADMAP pre-existing) + untracked hasil Task 1–5.
- Referensi ADR di ROADMAP: tidak ada eksplisit; ROADMAP sudah memuat keputusan yang sama (baris 18/98/112: Supabase langsung + penyesuaian scope) → ADR **sejalan**, bukan konflik.

## 3. Pemeriksaan konflik (hasil: LULUS — boleh implementasi langsung)

| Sumber | Konflik? | Catatan |
|---|---|---|
| PRD (integritas byte) | Tidak | PRD tidak dibaca-ditulis ulang; hanya hash diverifikasi |
| ROADMAP (30-hari, scope adjustment) | Tidak | ADR merekam keputusan yang sama dengan ROADMAP §penyesuaian scope; file tidak diubah |
| Keputusan web-first / mobile pending | Tidak | Stack README menyebut Expo "deferred to later tasks"; ADR: "Expo mobile deferred to the phase after MVP" — mobile tidak menghambat web MVP |
| Keputusan teknis tersimpan (Supabase-first, RLS gate, custom API deferred, SQL manual via Dashboard) | Tidak | Semua dimasukkan ke ADR apa adanya |
| Toolchain Task 1–5 | Tidak | File baru = Markdown saja; Biome tidak memproses `.md` (lint tetap 9 file) |

## 4. Wajib plan utama vs perlu keputusan

### 4a. Diharuskan plan utama

| Hal | Isi |
|---|---|
| README | **Append** setelah heading; hasil akhir = blok "Resulting content" plan utama (§6) persis; heading `# bookrate` tidak dihapus |
| ADR | File `docs/architecture/0001-supabase-first-backend.md` dengan poin wajib Step 3: context; decision (Supabase Postgres/Auth/Storage/RLS; Next.js on Vercel; Expo deferred; direct Supabase JS; custom API deferred = scope adjustment vs PRD); consequences; security responsibilities; RLS exposure gate; custom-API trigger criteria (client-held secrets, multi-step transactions, feed fan-out, rate-limited external calls, push orchestration); rejected alternatives (standalone API; Edge Functions/Deno) |
| Verifikasi utama | `head -n 1 README.md` = `# bookrate`; `git diff` README hanya penambahan; `grep -RIn "ANON_KEY" README.md docs/architecture` tanpa output (exit 1); `bunx biome check .` exit 0 |

### 4b. Detail yang perlu diputuskan

| # | Hal | Rencana default | Perlu persetujuan? |
|---|---|---|---|
| D1 | Teks Status README ("Task 1 … in setup. No application code yet.") — bolehkah di-refresh jadi "Tasks 1–5 done"? | **Pakai teks plan utama apa adanya** — unit Task 01 (Termasuk subtask 1–8) memang masih "in setup" sampai Task 8; mengubahnya = deviasi dari blok wajib | Hanya jika Anda ingin status di-refresh |
| D2 | Bahasa ADR | **Inggris** — konsisten dengan teks plan utama, spec, dan plan superpowers | Tidak |
| D3 | Nuansi byte README (heading tanpa trailing newline) | Heading dipertahankan verbatim; newline ditambahkan sebagai bagian dari append (tidak bisa dihindari — lihat §7 V2a) | Tidak (dilaporkan apa adanya) |
| D4 | Penamaan key | Gunakan "publishable key" (naming modern Supabase); **tanpa** `ANON_KEY` (legacy) — dipaksa verifikasi Step 5 | Tidak |

## 5. File yang akan dibuat/diubah

**Diubah (1):** `README.md` — append; heading pertama `# bookrate` dipertahankan; hasil = blok §6.1.

**Dibuat (1):** `docs/architecture/0001-supabase-first-backend.md` — struktur §6.2.

**Tidak diubah:** `docs/PRD.md`, `docs/ROADMAP.md`, plan utama/spec, hasil Task 1–5 (termasuk `.env.example`, `.gitignore`, `apps/`, `biome.json`, `package.json`), `.gitignore`.

## 6. Konten

### 6.1 README.md (hasil akhir, persis plan utama)

```markdown
# bookrate

Social Reading Platform — Supabase-first foundation.

## Status

Task 1 (monorepo & Supabase foundation) in setup. No application code yet.

## Stack

- Supabase (hosted PostgreSQL, Auth, Storage, RLS)
- Next.js (web, Vercel) and Expo (mobile) — deferred to later tasks
- Bun + Turborepo, TypeScript, Biome

## Repository Layout

- `apps/web`, `apps/mobile` — reserved
- `packages/config` — shared TypeScript config
- `docs/` — PRD, roadmap, architecture, Superpowers specs/plans

## Commands

- `bun install`
- `bun run typecheck`
- `bun run lint`
- `bun run format`
- `bun run build`
- `bun run dev`

## Environment

Use `.env.example` as the reference template for client-safe variable names. Per-app env
files (`apps/web/.env.local`, `apps/mobile/.env`) arrive with the apps in Task 12/13.
Never commit real values. Server-only secrets are deferred and never exposed to clients.

## Security

RLS policies, least privilege, parameterized database access, input validation, session
handling, and rate limiting remain application responsibilities. No user data is exposed
to publishable-key clients before default-deny RLS policies and negative authorization
tests exist.
```

### 6.2 ADR `docs/architecture/0001-supabase-first-backend.md` (struktur)

- **Header:** ADR 0001, title "Supabase-First Backend for the MVP", Status: Accepted, Date, Related (ROADMAP §Keputusan Backend MVP).
- **Context:** tuntutan PRD backend terpisah secara logis; realitas web-first + MVP timebox; kebutuhan auth/database/storage aman tanpa membangun server sendiri.
- **Decision:** poin wajib §4a — termasuk: Supabase langsung dari client web dengan RLS; Next.js di Vercel; Expo mobile deferred ke fase setelah MVP; **custom API deferred untuk MVP = penyesuaian scope terhadap kebutuhan API terpisah di PRD, bukan pemenuhan penuh**; migrasi SQL manual via Supabase Dashboard (tanpa CLI) mengikuti ROADMAP.
- **Consequences:** setup MVP cepat; biaya awal rendah; keamanan bergantung pada RLS; kustomisasi terbatas; kriteria pemicu API custom harus dipantau; mobile pending tidak memblokir web.
- **Security Responsibilities:** RLS policies, least privilege, parameterized access, input validation, session handling, rate limiting — tanggung jawab aplikasi.
- **RLS Exposure Gate:** tidak ada data user sampai klien publishable-key **sebelum** default-deny policies + negative authorization tests ada.
- **Custom-API Trigger Criteria:** client-held secrets; multi-step transactions; feed fan-out; rate-limited external calls; push orchestration.
- **Rejected Alternatives:** standalone custom API untuk MVP; Edge Functions/Deno.

Tanpa penyebutan `ANON_KEY` (D4).

## 7. Langkah implementasi & verifikasi

1. **Pre-check:** `wc -c README.md` (=10) + `git status` + `sha256sum docs/PRD.md`.
2. **README:** tulis hasil §6.1 (append; jangan overwrite sembrono — hasil akhir identik blok plan utama).
3. **ADR:** buat `docs/architecture/` + file §6.2.
4. **Verifikasi:**

| # | Perintah | Ekspektasi |
|---|---|---|
| V1 | `head -n 1 README.md` | `# bookrate` |
| V2a | `git diff -- README.md` | heading tidak terhapus; isi = penambahan; **catatan D3:** baris heading kehilangan status "no newline at EOF" (dari 10 byte tanpa `\n` menjadi ber-\n) — tidak ada konten yang hilang |
| V2b | `wc -c README.md` & bandingkan blok §6.1 | hasil akhir cocok dengan blok plan utama |
| V3 | `ls docs/architecture/0001-supabase-first-backend.md` + grep section wajib (Context/Decision/Consequences/Security/RLS/Trigger/Rejected) | ada + semua seksi wajib terisi |
| V4 | `grep -RIn "ANON_KEY" README.md docs/architecture` | tanpa output, **exit 1** |
| V5 | `bunx biome check .` | exit 0 |
| V6 | `bun run lint` / `bun run typecheck` / `bun run build` | exit 0; lint tetap "Checked 9 files"; scope `@bookrate/config` |
| V7 | `git status --short` | hanya bertambah ` M README.md` + `?? docs/architecture/` vs baseline |
| V8 | `sha256sum docs/PRD.md` + `git diff --stat` | PRD hash identik; diff tracked tetap hanya PRD/ROADMAP pre-existing |
| V9 | Baca ulang README+ADR | konsistensi web-first: Supabase-first, Next.js prioritas, Expo deferred; tanpa keputusan baru |

5. **Jika ada konflik/kegagalan → berhenti & laporkan** (tidak terprediksi dari pemeriksaan §3).

## 8. Kriteria selesai (Definition of Done)

- [ ] README heading `# bookrate` utuh; konten = blok plan utama §6.1.
- [ ] ADR ada, berstatus Accepted, memuat seluruh poin wajib Step 3, sejalan ROADMAP & web-first.
- [ ] V4 tanpa `ANON_KEY`; V5–V6 toolchain exit 0; V7 hanya scope Task 6; V8 PRD hash identik.
- [ ] Tidak ada perubahan di luar scope; tidak ada commit; Task 7 tidak dimulai.

## 9. Di luar cakupan

- Task 7 (ROADMAP reconciliation verification) dan Task 8 (toolchain final).
- Perubahan PRD/ROADMAP/plan utama/spec atau keputusan arsitektur yang sudah ada.
- Penulisan ulang/menghapus konten README lama selain append; scaffold aplikasi apa pun.
