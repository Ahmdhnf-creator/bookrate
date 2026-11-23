# BookRate Task 08 — Full Toolchain Verification (Implementation Plan)

**Status:** Planned — verifikasi saja, tanpa perubahan file proyek
**Date:** 2026-11-06
**Parent plan:** `docs/superpowers/plans/task-01-backend-project-setup.md` (Task 8 section, Step 1–7 + Self-Review)
**Pattern reference:** `task-07-roadmap-reconciliation.md`
**Scope note:** Tidak ada file proyek baru; tidak ada commit; Task 9 tidak dimulai; `git reset/restore/checkout/stash` dilarang; tidak ada upgrade/dependency/scaffold.

## 1. Tujuan

Final verification pekerjaan Task 1–7: seluruh toolchain (install, typecheck, lint, format, build, dev placeholder) serta audit artefak terlarang — semuanya read-only.

## 2. Baseline awal (tercatat sebelum eksekusi — sesi setelah Task 7)

- `git status --short`: ` M README.md` (Task 6), ` M docs/PRD.md`, ` M docs/ROADMAP.md` (pre-existing terdisetujui), untracked: `.bun-version .env.example .gitignore .nvmrc apps/ biome.json bun.lock docs/architecture/ docs/superpowers/ package.json packages/ scripts/ tsconfig.base.json turbo.json`.
- `git diff --stat`: README 42 (Task 6); PRD 828 (pre-existing); ROADMAP 203 (pre-existing restructure).
- HEAD: `0972869 docs: add BookRate PRD and roadmap`.
- Toolchain files: `bun.lock`, `.bun-version` (1.4.0), `.nvmrc` (22.22.1) ada ✓.
- **Working tree tidak diharapkan bersih** — perubahan Task 1–7 + PRD/ROADMAP pre-existing memang belum di-commit.

## 3. Catatan lingkungan

- **`rg` tidak tersedia** di WSL2 ini (terverifikasi). Perintah Step 5 audit yang memakai `rg` akan dijalankan dengan padanan **identik dari parent plan**: `grep -RInE` / `grep -nE` (parent plan Task 8 memang menuliskan `grep`). Substitusi dicatat di laporan; exit 1 pada grep no-match = hasil normal.
- Dev placeholder: parent plan Step 5 (`bun run dev`, pesan placeholder + exit 0) ikut dijalankan sebagai pelengkap yang relevan (read-only).

## 4. Langkah verifikasi & ekspektasi

| Step | Perintah | Ekspektasi |
|---|---|---|
| 1 | `bun install --frozen-lockfile` | exit **0**; `bun.lock` tidak berubah (hash sebelum/sesudah dicatat) |
| 2 | `bun run typecheck` | exit **0** |
| 3a | `bun run lint` | exit **0** |
| 3b | `bun run format:check` | exit **0** |
| 4 | `bun run build` | exit **0** (no-op-safe) |
| 4b* | `bun run dev` | pesan placeholder tercetak, exit **0** (parent plan Step 5) |
| 5a | `find packages -maxdepth 1 -mindepth 1 -type d` | hanya `packages/config` |
| 5b | `find . -path ./node_modules -prune -o -name 'deno.json' -print` | tanpa output |
| 5c | `grep -RInE '"(@supabase/supabase-js\|zod\|drizzle-orm\|drizzle-kit\|next\|expo\|react-native)"' package.json packages` | tanpa output, **exit 1** (padanan rg) |
| 5d | `grep -nE "ANON_KEY\|SERVICE_ROLE\|SECRET_KEY\|DATABASE_URL" .env.example` | tanpa output, **exit 1** |
| 6 | `git status --short` + `git diff --stat` + `git log -1 --oneline` | **identik baseline §2**; tidak ada perubahan tak terduga; HEAD `0972869` |

\* step tambahan dari parent plan.

**Aturan kegagalan:** bila salah satu check gagal → analisis penyebab, **jangan perbaiki otomatis**, laporkan (status Blocked/Failed).

## 5. Kriteria selesai (Definition of Done)

- [ ] Step 1–6 semua exit 0 / sesuai ekspektasi audit.
- [ ] `bun.lock` tidak berubah; tidak ada dependency/upgrade/scaffold baru.
- [ ] `git status` & `git diff --stat` == baseline §2 (nol perubahan tak disengaja).
- [ ] Tidak ada commit; Task 9 belum dimulai.

## 6. Di luar cakupan

- Task 9 (dan lanjut); perbaikan bila ada check gagal; perubahan file proyek apa pun.
