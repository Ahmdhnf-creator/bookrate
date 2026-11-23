# BookRate Task 05 — Client-Safe Environment Example (Implementation Plan)

**Status:** Planned — menunggu persetujuan user sebelum implementasi
**Date:** 2026-11-06
**Parent plan:** `docs/superpowers/plans/task-01-backend-project-setup.md` (Task 5 section)
**Pattern reference:** `task-04-reserve-app-directories.md`, `task-03-biome.md`
**Scope note:** Dokumen ini hanya plan. `.env.example` belum dibuat, tidak ada commit, Task 6 tidak dimulai, hasil Task 1–4 tidak disentuh.

## 1. Tujuan

Membuat `.env.example` yang berisi **nama variabel environment client-safe saja** (tanpa rahasia, tanpa nilai) sebagai kontrak dokumentatif untuk koneksi Supabase dari sisi klien:

- **Blok Web (Next.js)** — `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` → **prioritas utama web MVP**.
- **Blok Mobile (Expo)** — `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` → penanda nama variabel untuk fase setelah web MVP.

### Kaitan dengan keputusan proyek terbaru (web-first)

- File ini **hanya teks dokumentatif** — tidak dieksekusi, tidak dibangun, tidak direferensikan kode mana pun saat ini (verifikasi: belum ada referensi `.env` di codebase). Blok Expo **inert** dan **tidak menghambat web MVP** dengan cara apa pun.
- Urutan file: blok **Web dulu**, blok Mobile di bawahnya — mencerminkan prioritas.
- Konsisten dengan keputusan yang ada: ROADMAP menempatkan native (Task 12/14) di **Phase 2 — setelah MVP**; Task 4 sudah mereservasi `apps/mobile/`. Menghapus blok Mobile akan menyimpang dari isi wajib plan utama §3a — hanya dilakukan jika diminta eksplisit saat review (lihat D1).

## 2. Kondisi repository (setelah Task 4, diverifikasi)

- **Tidak ada** `.env`, `.env.example`, atau file `.env*` apa pun.
- `.gitignore` **sudah** memuat aturan yang benar (lines 6–8):
  ```
  .env
  .env.*
  !.env.example
  ```
  ⇒ tidak perlu diubah (di luar scope Task 5).
- Tidak ada referensi `.env` di codebase (`.ts`/`.json`/`.md` selain dokumen superpowers).
- Toolchain utuh: biome (9 file), typecheck/build exit 0, HEAD `0972869`, PRD hash `6f1fe4f9…1313e`.
- `.env.example` **di luar cakupan Biome** (`files.includes` hanya ts/tsx/json) → lint tetap 9 file.

## 3. Wajib plan utama vs perlu keputusan

### 3a. Diharuskan plan utama (tanpa perubahan tanpa persetujuan)

| Hal | Isi |
|---|---|
| File | Hanya: `.env.example` (root) |
| Isi | Persis blok plan utama §4 di bawah — 4 nama variabel, nilai **kosong**, 2 komentar seksi |
| Larangan | Tidak ada nilai/key nyata; tidak ada variabel server (`SERVICE_ROLE`, `SECRET_KEY`, `DATABASE_URL`, `ANON_KEY`, dsb.); tidak ada file `.env` sungguhan; `.gitignore` tidak diubah |
| Verifikasi utama | grep rahasia → tanpa output (exit 1); `git check-ignore -v .env` match; `git check-ignore .env.example` tanpa output |

### 3b. Detail yang perlu diputuskan saat implementasi

| # | Hal | Rencana default | Perlu persetujuan? |
|---|---|---|---|
| D1 | Blok Mobile (`EXPO_PUBLIC_*`) ikut ditulis atau tidak (keputusan web-first) | **Ikut ditulis** — persis plan utama; inert, tidak menghambat web MVP, konsisten dengan ROADMAP Phase 2 & reservasi `apps/mobile` | **Ya, hanya jika Anda ingin blok Mobile dihapus** (deviasi dari plan utama) |
| D2 | Nilai variabel | **Kosong** (`VAR=`) — tanpa rahasia, tanpa placeholder key | Tidak |
| D3 | Penulisan `.gitignore` | **Tidak disentuh** — aturan sudah benar (terverifikasi §2) | Tidak |

## 4. File yang akan dibuat/diubah

**Dibuat (1 file, tidak ada yang lain):**

`.env.example` (isi persis plan utama):

```
# Web (Next.js)
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=

# Mobile (Expo)
EXPO_PUBLIC_SUPABASE_URL=
EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
```

**Tidak diubah:** `.gitignore`, `package.json`, `turbo.json`, `biome.json`, `apps/*`, `packages/*`, dokumen (PRD/ROADMAP/spec/plan utama), dan seluruh hasil Task 1–4.

## 5. Alasan teknis

- **Client-safe only:** variabel `NEXT_PUBLIC_*`/`EXPO_PUBLIC_*` by design ter-embed ke bundle klien — aman dipublikasikan; kunci yang sama (`PUBLISHABLE_KEY`) memang dimaksudkan untuk klien. Rahasia server (service role, DB URL) tidak pernah masuk file ini.
- **Nama variabel = kontrak awal** untuk Task 12 (Next.js + Supabase client) tanpa perlu scaffold sekarang; placeholder nilai kosong mencegah orang menyalin "nilai contoh" yang salah.
- **`.gitignore` interaksi:** pola `.env` menangkap file nyata; `.env.*` menangkap varian (`.env.local`, `.env.example`) lalu di-negasi `!.env.example` → example tetap ter-track. Urutan pola di gitignore benar (negasi setelah wildcard) — diverifikasi V3/V4.
- **Biome/Turbo/TS:** file tanpa ekstensi `.example` tidak match `files.includes` → nol dampak ke lint/build/typecheck.

## 6. Langkah implementasi

1. **Pre-check:** pastikan `.env*` belum ada; `git status --short`; `sha256sum docs/PRD.md` (baseline).
2. **Step 1 (plan utama):** buat `.env.example` dengan isi §4 (jika D1 dipilih "hapus blok Mobile", tunggu instruksi eksplisit dulu).
3. **Step 2 (plan utama):** `grep -nE "SERVICE_ROLE|SECRET_KEY|DATABASE_URL|ANON_KEY" .env.example` → tanpa output, exit 1.
4. **Step 3 (plan utama):** `git check-ignore -v .env` → match aturan `.env`; `git check-ignore .env.example` → tanpa output.
5. **Verifikasi integrasi:** lint/typecheck/build tetap identik baseline; `git status` hanya bertambah `?? .env.example`.
6. Lolos → laporkan hasil; **berhenti sebelum Task 6**.

## 7. Verifikasi (yang akan dijalankan)

| # | Perintah | Ekspektasi |
|---|---|---|
| V1 | `cat .env.example` | identik §4 (4 VAR= kosong, 2 komentar, Web dulu) |
| V2 | `grep -nE "SERVICE_ROLE\|SECRET_KEY\|DATABASE_URL\|ANON_KEY" .env.example` | tanpa output, **exit 1** (grep no-match) — verifikasi utama tanpa rahasia |
| V3 | `git check-ignore -v .env` | output memuat rule `.env` (file nyata di-ignore) |
| V4 | `git check-ignore .env.example` | tanpa output (example tidak di-ignore / ter-track) |
| V5 | `bun run lint` | exit 0, tetap **"Checked 9 files"** |
| V6 | `bun run typecheck` && `bun run build` | exit 0 (scope tetap `@bookrate/config`) |
| V7 | `git status --short` | hanya bertambah `?? .env.example` vs baseline Task 4 |
| V8 | `sha256sum docs/PRD.md` | tetap `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e` |

## 8. Kriteria selesai (Definition of Done)

- [ ] `.env.example` ada dengan isi persis §4 (atau variant D1 yang sudah disetujui eksplisit).
- [ ] Tanpa rahasia: grep V2 exit 1; semua nilai kosong.
- [ ] Ignore rules terbukti: `.env` di-ignore, `.env.example` ter-track (V3/V4).
- [ ] Lint tetap 9 file; typecheck/build exit 0 (toolchain tak tersentuh).
- [ ] `git status` hanya menambah `.env.example`; hasil Task 1–4 utuh.
- [ ] PRD hash identik; tidak ada commit.
- [ ] Task 6 belum dimulai.

## 9. Di luar cakupan

- Task 6–8 plan utama (README/ADR, verifikasi ROADMAP, toolchain final).
- Membuat file `.env` sungguhan, mengisi nilai nyata, atau mengubah `.gitignore`.
- Scaffold Next.js/Expo atau kode yang membaca variabel ini (Task 12+).
- Perubahan PRD/ROADMAP/plan utama/spec.
