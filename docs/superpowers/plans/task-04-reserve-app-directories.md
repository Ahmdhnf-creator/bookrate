# BookRate Task 04 — Reserve App Directories (Implementation Plan)

**Status:** Planned — menunggu persetujuan user sebelum implementasi
**Date:** 2026-11-05
**Parent plan:** `docs/superpowers/plans/task-01-backend-project-setup.md` (Task 4 section)
**Pattern reference:** `task-02-typescript-config.md`, `task-03-biome.md`
**Scope note:** Dokumen ini hanya plan. Belum ada `apps/` yang dibuat, tidak ada commit, Task 5 tidak dimulai, implementasi Task 1–3 tidak disentuh.

## 1. Tujuan

Memesan direktori aplikasi tanpa scaffold apa pun:

- `apps/web/` — calon app Next.js (Task 12/13 dalam penomoran lama yang disepakati).
- `apps/mobile/` — calon app Expo (fase setelah MVP; Task 12/14 dalam penomoran lama).
- Tanpa `package.json`, tanpa framework, tanpa kode — hanya struktur direktori + catatan.

Ini menjaga keputusan Task 1 (reserve dirs only; no Next.js/Expo scaffolds) sambil memberi titik masuk yang jelas untuk fase web.

## 2. Kondisi repo aktual (setelah Task 3, diverifikasi)

- `apps/` **tidak ada** → Task 4 memang belum dikerjakan.
- `package.json` root: `"workspaces": ["apps/*", …]` — glob saat ini **tidak match apa pun**.
- `biome.json`: `files.includes` hanya `**/*.ts`, `**/*.tsx`, `**/*.json` → `.gitkeep` (tanpa ekstensi) dan `apps/README.md` (Markdown) **di luar cakupan** Biome.
- `.gitignore` tidak punya aturan yang mengabaikan `apps/`.
- Hasil Task 1–3 utuh: workspace + turbo + biome (9 file tercekik lolos), Opsi B (`packages/config`), `bun.lock`, HEAD `0972869`, PRD hash `6f1fe4f9…1313e`.
- Pola plan: `task-02-…`, `task-03-…` ada → penamaan `task-04-reserve-app-directories.md` sesuai pola.

## 3. Wajib plan utama vs perlu keputusan

### 3a. Diharuskan plan utama (tanpa perubahan tanpa persetujuan)

| Hal | Isi |
|---|---|
| File yang dibuat | Hanya: `apps/web/.gitkeep`, `apps/mobile/.gitkeep` (keduanya **kosong**), `apps/README.md` |
| Isi `apps/README.md` | Persis blok plan utama (lihat §4), termasuk rujukan legacy "Task 12/13" dan "Task 12/14" yang **dipertahankan** sesuai keputusan user + Catatan Penomoran di ROADMAP |
| Verifikasi utama | `find apps -name package.json` → tanpa output |
| Larangan | Tidak ada `package.json`, scaffold, framework, `.gitignore`/config di dalam `apps/` |

### 3b. Detail yang perlu diputuskan saat implementasi (belum ditetapkan)

| # | Hal | Rencana default | Perlu persetujuan? |
|---|---|---|---|
| D1 | Perilaku Bun/Turbo terhadap direktori workspace yang cocok glob tapi **tanpa** `package.json` (bisa jadi diabaikan, bisa jadi warning) | Jalankan verifikasi integrasi V3–V5; jika **error**, berhenti dan laporkan | Hanya jika terjadi masalah |
| D2 | Penamaan isi `.gitkeep` | **Kosong** (0 byte) — persis plan utama | Tidak |
| D3 | Penyesuaian teks `apps/README.md` (mis. menambah frasa "fase setelah MVP") | **Tidak** — pakai teks plan utama apa adanya | Tidak (default persis plan) |

## 4. File yang akan dibuat/diubah

**Dibuat (3 file, tidak ada yang lain):**

`apps/web/.gitkeep` dan `apps/mobile/.gitkeep` — file kosong (0 byte).

`apps/README.md` (isi persis plan utama):

```markdown
# Apps

- `web/` — reserved for the Next.js web app (Task 12/13). No scaffold yet.
- `mobile/` — reserved for the Expo app (Task 12/14). No scaffold yet.
```

**Tidak diubah:** package.json, turbo.json, biome.json, `.gitignore`, `packages/*`, `scripts/*`, dokumen (PRD/ROADMAP/spec/plan), dan seluruh hasil Task 1–3.

## 5. Alasan teknis

- **Workspace Bun:** glob `apps/*` sengaja dibuat sejak awal; direktori kosong tanpa `package.json` tidak menambah paket (Bun hanya memuat workspace ber-`package.json`) — diverifikasi lewat V3.
- **Turbo:** task graph tetap hanya berisi `@bookrate/config`; direktori tanpa manifest tidak menjadi node paket — diverifikasi lewat V3 (scope & hasil identik dengan baseline Task 3).
- **TypeScript:** root `tsconfig.base.json` hanya extends `packages/config`; tidak ada `tsconfig` di `apps/` yang bisa berefek.
- **Biome:** `.gitkeep` dan Markdown di luar `files.includes` → jumlah file tercekik tetap 9 (identik baseline Task 3).
- **Git:** `.gitkeep` kosong tetap ter-track; tidak ada aturan ignore yang menghalangi; `.gitignore` tak perlu diubah.

## 6. Langkah implementasi

1. **Pre-check:** `test ! -e apps` + `git status --short` + `sha256sum docs/PRD.md` (baseline).
2. **Step 1 (plan utama):** buat `apps/web/.gitkeep` dan `apps/mobile/.gitkeep` kosong; tulis `apps/README.md` dengan isi §4.
3. **Step 2 (plan utama):** `find apps -name package.json` → tanpa output.
4. **Verifikasi integrasi V3–V5** (tata letak baru jangan merusak toolchain yang sudah ada).
5. Jika D1 memicu error → **berhenti**, laporkan.
6. Lolos → laporkan perubahan + hasil verifikasi; **berhenti sebelum Task 5**.

## 7. Verifikasi (yang akan dijalankan)

| # | Perintah | Ekspektasi |
|---|---|---|
| V1 | `find apps -mindepth 1 -maxdepth 1` | hanya `web`, `mobile`, `README.md` |
| V2 | `find apps -name package.json` | tanpa output (exit 1) — **verifikasi utama plan** |
| V2b | `wc -c apps/web/.gitkeep apps/mobile/.gitkeep` | keduanya `0` |
| V3 | `bun run typecheck` | exit 0; turbo tetap "Packages in scope: @bookrate/config" |
| V4 | `bun run lint` | exit 0; "Checked 9 files" (tak bertambah) |
| V5 | `bun run build` | exit 0 (turbo no-op-safe) |
| V6 | `git status --short` | hanya bertambah `?? apps/`; tidak ada file Task 1–3 yang berubah/hilang |
| V7 | `sha256sum docs/PRD.md` | tetap `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e` |

## 8. Kriteria selesai (Definition of Done)

- [ ] `apps/web/.gitkeep`, `apps/mobile/.gitkeep` (0 byte) dan `apps/README.md` (isi persis §4) ada.
- [ ] `find apps -name package.json` tanpa output; tidak ada scaffold/framework.
- [ ] Typecheck, lint, build tetap exit 0 dengan jumlah file biome tetap 9.
- [ ] Hanya `apps/` yang bertambah di `git status`; hasil Task 1–3 utuh (termasuk Opsi B dan biome preset recommended).
- [ ] `docs/PRD.md` hash identik; tidak ada commit.
- [ ] Task 5 belum dimulai.

## 9. Di luar cakupan

- Task 5–8 plan utama (`.env.example`, README/ADR, verifikasi ROADMAP, toolchain final).
- Perubahan plan utama/spec/PRD/ROADMAP.
- Scaffold Next.js/Expo, `package.json` di dalam `apps/`, atau perubahan workspace/turbo/biome.
