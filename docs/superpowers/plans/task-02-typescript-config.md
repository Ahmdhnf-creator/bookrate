# BookRate Task 02 — TypeScript Shared Config (Post-Implementation Record)

**Status:** Implemented — Task 2 selesai diverifikasi
**Date:** 2026-11-05
**Parent plan:** `docs/superpowers/plans/task-01-backend-project-setup.md` (Task 2 section)
**Approach:** Opsi B (disetujui user saat blocker Task 2)
**Scope note:** Dokumen ini mencatat hasil implementasi; plan utama, spec, PRD, dan kode tidak diubah oleh pembuatan file ini.

## 1. Tujuan

Menyediakan konfigurasi TypeScript bersama untuk monorepo BookRate:

- `@bookrate/config` mengekspos `tsconfig.base.json` yang dapat di-`extend` app/package lain.
- Menyediakan script `typecheck` yang nyata agar task graph Turbo punya target valid.
- Tidak ada package placeholder lain; hanya `packages/config`.

## 2. Perubahan aktual yang dilakukan

| File | Status | Isi / Perubahan |
|---|---|---|
| `packages/config/package.json` | dimodifikasi | `devDependencies` tidak ada; script `typecheck` = `tsc -p tsconfig.typecheck.json --noEmit` (awalnya `tsc -p tsconfig.base.json --noEmit`, diganti karena blocker di §3) |
| `packages/config/tsconfig.base.json` | sesuai plan, **tidak diubah** | target ES2022, strict, `noUncheckedIndexedAccess`, `moduleResolution: Bundler`, `verbatimModuleSyntax`, `noEmit`, **`"files": []` dipertahankan** |
| `packages/config/index.ts` | **baru (Opsi B)** | `export {}` — satu input TS agar verifikasi typecheck punya input nyata |
| `packages/config/tsconfig.typecheck.json` | **baru (Opsi B)** | `{ "extends": "./tsconfig.base.json", "files": ["index.ts"] }` — config khusus verifikasi; base tetap murni |
| `packages/config/README.md` | sesuai plan, tidak diubah | deskripsi `@bookrate/config` |
| `tsconfig.base.json` (root) | sesuai plan, tidak diubah | `{ "extends": "./packages/config/tsconfig.base.json" }` |

Konfigurasi lain di luar Task 2 (package.json root, turbo.json, .bun-version, .nvmrc, .gitignore, `scripts/dev-placeholder.ts`, `bun.lock`) milik Task 1 dan tidak disentuh oleh Task 2.

## 3. Blocker dan keputusan Opsi B

**Blocker:** plan utama menghendaki dua hal yang bertentangan — `"files": []` pada base config (wajar untuk shared base) sekaligus script `tsc -p tsconfig.base.json --noEmit` yang mengeksekusi tsconfig itu sendiri. TypeScript membuang `TS18002: The 'files' list in config file is empty`.

**Diagnostik yang diverifikasi sebelum keputusan** (memakai `tsc` dari `node_modules` versi 5.9.3):

| Varian | Hasil |
|---|---|
| `files: []` + `--noEmit` | TS18002, exit 2 |
| `include: ["**/*.ts"]` tanpa file .ts | TS18003, exit 2 |
| `--showConfig` dengan `files: []` | exit 1 |
| `files: []` + `include: []` | TS18002, exit 2 |
| Anak extends base `files: []` + `include` sendiri | exit 0 (base kosong tidak meracuni anak) |
| Anak extends base `files: ["a.ts"]` tanpa include | exit 0 → **`files` diwariskan ke config anak** |

**Keputusan user: Opsi B** — pertahankan `files: []` di shared base; tambah `index.ts` dan `tsconfig.typecheck.json` khusus verifikasi package config. (Opsi A ditolak karena `files` diwariskan dan bisa membuat anak yang lupa `include` salah-lulus; Opsi C ditolak karena mengganti typecheck dengan validasi JSON biasa.)

**Catatan perintah:** perintah plan `bun --cwd packages/config run typecheck` tidak dieksekusi dengan benar oleh bun 1.4.0 (mencetak help, exit 0 menyesatkan). Verifikasi dijalankan dengan bekerja dari direktori `packages/config` via `bun run typecheck`.

## 4. Verifikasi yang benar-benar dijalankan dan hasilnya

| # | Perintah | Lokasi | Hasil |
|---|---|---|---|
| 1 | `bun run typecheck` → `tsc -p tsconfig.typecheck.json --noEmit` | `packages/config/` | **exit 0** (tanpa output error) |
| 2 | `bun run typecheck` → `turbo run typecheck` | root | **exit 0**; turbo 2.11.10; `@bookrate/config:typecheck` cache miss, execute, **1 successful / 1 total** |
| 3 | `grep "files" packages/config/tsconfig.base.json` | root | baris 17: `"files": []` — base tidak berubah |
| 4 | `cat tsconfig.base.json` | root | tetap `{ "extends": "./packages/config/tsconfig.base.json" }` |
| 5 | `sha256sum docs/PRD.md` | root | `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e` — identik, PRD tak diubah |
| 6 | `git status --short` | root | hanya file Task 1/Task 2 yang baru + modifikasi pre-existing `docs/PRD.md` & `docs/ROADMAP.md`; tidak ada reset/stash/revert; tidak ada commit |

## 5. Kriteria selesai (Definition of Done)

- [x] `packages/config/tsconfig.base.json` tetap memakai `"files": []` (Opsi B).
- [x] `packages/config/index.ts` dan `packages/config/tsconfig.typecheck.json` ada sesuai Opsi B.
- [x] Script `typecheck` package config menunjuk `tsconfig.typecheck.json` dan lulus exit 0.
- [x] `bun run typecheck` dari root (Turbo) lulus exit 0 dengan target nyata.
- [x] Root `tsconfig.base.json` dan README package tidak berubah dari isi plan.
- [x] Tidak ada file baru di `packages/` selain `config/`.
- [x] `docs/PRD.md` tidak diubah; perubahan pre-existing dipertahankan.
- [x] Tidak ada commit.

## 6. Di luar cakupan dokumen ini

- Task 3–8 plan utama (Biome, reserved apps, `.env.example`, README/ADR, verifikasi ROADMAP, toolchain final) belum dimulai — menunggu persetujuan.
- Plan utama (`task-01-backend-project-setup.md`) dan spec **tidak** diubah untuk mencerminkan Opsi B; divergensi tercatat di sini.
