# BookRate Task 03 — Biome Lint & Format (Implementation Plan)

**Status:** Planned — menunggu persetujuan user sebelum implementasi
**Date:** 2026-11-05
**Parent plan:** `docs/superpowers/plans/task-01-backend-project-setup.md` (Task 3 section)
**Pattern reference:** `docs/superpowers/plans/task-02-typescript-config.md`
**Scope note:** Dokumen ini hanya plan. Belum ada `biome.json`, tidak ada implementasi Task 3, tidak ada commit, Task 4 tidak dimulai.

## 1. Tujuan

Menyediakan konfigurasi Biome untuk lint + format monorepo:

- Aturan lint/format untuk file TypeScript dan JSON.
- Markdown **tidak** diproses Biome — agar dokumen (PRD CRLF, ROADMAP, spec/plan) tidak pernah tersentuh formatter.
- Menjalankan script root `lint` (`biome check .`) dan `format:check` (`biome format .`) yang sudah dibuat di Task 1.

## 2. Kondisi repo (diverifikasi, bukan asumsi)

- `biome.json` **tidak ada** → Task 3 memang belum dikerjakan.
- `@biomejs/biome@2.6.5` sudah terpasang di root `node_modules` (dari `bun install` Task 1); `./node_modules/.bin/biome --version` → **2.6.5**.
- File yang akan masuk cakupan `files.includes` (`**/*.ts|tsx|json`, di luar `node_modules`):
  - `package.json`, `turbo.json`, `tsconfig.base.json`
  - `packages/config/{package.json,tsconfig.base.json,tsconfig.typecheck.json,index.ts}`
  - `scripts/dev-placeholder.ts`
  - `.turbo/cache/*.json` — **dikecualikan otomatis** lewat `vcs.useIgnoreFile: true` + aturan `.turbo/` di `.gitignore`.
  - `bun.lock` (format teks, bukan `.json`) — tidak masuk cakupan.
- Repo adalah git working tree (fitur `vcs` dapat bekerja).
- Hasil Task 1 & Task 2 (termasuk Opsi B) ada dan tidak boleh berubah.

## 3. Wajib plan utama vs perlu keputusan

### 3a. Diharuskan plan utama (tidak diubah tanpa persetujuan)

| Hal | Isi |
|---|---|
| File yang dibuat | **Hanya `biome.json`** — tidak ada file lain |
| Isi `biome.json` | Persis blok JSON di plan utama (lihat §4): `$schema` 2.0.0, `vcs` enabled/git/useIgnoreFile, `files.includes` ts/tsx/json, formatter space/width 2/lineWidth 100, linter recommended, `quoteStyle: single`, `semicolons: asNeeded` |
| Verifikasi | `bunx biome --version` → 2.x; `bunx biome check .` → exit 0; tidak ada `docs/*.md` yang diproses |
| Fallback bila config ditolak | `bunx biome init`, adopsi config hasil generate, jalankan ulang verifikasi |

### 3b. Detail yang perlu diputuskan saat implementasi (belum ditetapkan)

| # | Hal | Opsi / rencana default | Perlu persetujuan? |
|---|---|---|---|
| D1 | `biome check .` melaporkan **format diff** pada JSON yang sudah ditulis manual (mis. object inline `"engines": { "node": ">=22.22.1" }` tidak sesuai selera formatter) | Default: jalankan `bun run format` (script terencana) lalu re-check — **tapi ini menyentuh file Task 1/2**, jadi berhenti dan minta persetujuan dulu; alternatif: edit manual hanya file yang ditandai | **Ya** — jika terjadi |
| D2 | Schema URL `$schema` menunjuk `2.0.0` sedangkan binary 2.6.5 | Default: **biarkan** — `$schema` hanya referensi editor; Biome memvalidasi dengan binary terpasang. Ganti hanya jika biome menolak | Tidak (default dijalankan; ganti = ikut D3) |
| D3 | Config ditolak biome 2.6.5 (mis. key `files.includes`/`vcs` berubah) | Jalankan fallback resmi plan utama: `bunx biome init` + adopsi hasilnya + re-verifikasi | Cukup ikuti otorisasi plan utama; hasil init yang mengubah kebijakan (mis. formatter/linter aktif/tidak) dilaporkan dulu sebelum disimpan |
| D4 | Pemakaian `bunx biome` vs binary lokal | `bunx` dengan paket lokal akan resolve ke `node_modules` 2.6.5 (tanpa unduh) — default aman | Tidak |

## 4. File yang akan dibuat/diubah

**Dibuat (1 file, isi persis plan utama):**

`biome.json`:

```json
{
  "$schema": "https://biomejs.dev/schemas/2.0.0/schema.json",
  "vcs": { "enabled": true, "clientKind": "git", "useIgnoreFile": true },
  "files": { "includes": ["**/*.ts", "**/*.tsx", "**/*.json"] },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 100
  },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "javascript": {
    "formatter": { "quoteStyle": "single", "semicolons": "asNeeded" }
  }
}
```

**Tidak diubah:** semua hasil Task 1 & Task 2 (termasuk `packages/config/*` Opsi B), `docs/PRD.md`, plan utama, spec, ROADMAP, file docs lain.

## 5. Langkah implementasi

1. **Pre-check:** ulangi `test ! -e biome.json` + `git status --short` (baseline sebelum perubahan).
2. **Step 1 (plan utama):** tulis `biome.json` dengan isi §4.
3. **Step 2 (plan utama):** verifikasi versi + lint (lihat §6).
4. Jika biome menolak config → jalankan fallback §3a (catat hasilnya; keputusan mengikuti D3).
5. Jika hanya format diff → **berhenti**, laporkan D1 ke user.
6. Setelah lolos: laporkan perubahan + hasil verifikasi; **berhenti sebelum Task 4**.

## 6. Verifikasi (yang akan dijalankan)

| # | Perintah | Ekspektasi |
|---|---|---|
| V1 | `bunx biome --version` | output mengandung `2.x` (aktual: 2.6.5) |
| V2 | `bunx biome check .` | **exit 0**; tidak ada path `docs/` di output (Markdown tidak diproses) |
| V3 | `bunx biome check docs/PRD.md` (opsional, bukti eksklusi) | file di `docs/` tidak diproses sebagai target lint/format |
| V4 | `bun run lint` | exit 0 (integrasi script root Task 1) |
| V5 | `git status --short` | hanya `biome.json` yang bertambah dibanding baseline §5.1; file Task 1/2 tidak berubah isinya |
| V6 | `sha256sum docs/PRD.md` | tetap `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e` |

## 7. Kriteria selesai (Definition of Done)

- [ ] `biome.json` ada dengan isi wajib §4 (atau fallback resmi §3a yang sudah dilaporkan).
- [ ] `bunx biome --version` menunjukkan 2.x.
- [ ] `bunx biome check .` exit 0 dan tidak memproses `docs/*.md`.
- [ ] `bun run lint` (script root) exit 0.
- [ ] Tidak ada file selain `biome.json` yang ditambah/diubah oleh Task 3 (D1 tidak terjadi, atau sudah disetujui user).
- [ ] Hasil Task 1 & Task 2 utuh (termasuk `files: []`, `index.ts`, `tsconfig.typecheck.json` Opsi B).
- [ ] `docs/PRD.md` hash identik; tidak ada commit.
- [ ] Task 4 belum dimulai.

## 8. Di luar cakupan

- Task 4–8 plan utama (reserved apps, `.env.example`, README/ADR, verifikasi ROADMAP, toolchain final).
- Perubahan isi plan utama/spec (termasuk penyelarasan dengan Opsi B — tetap tercatat di `task-02-typescript-config.md`).
- Format ulang file Task 1/2 tanpa persetujuan (lihat D1).
