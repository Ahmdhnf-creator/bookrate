# BookRate Task 07 — ROADMAP Reconciliation Verification (Implementation Plan)

**Status:** Planned — verifikasi saja, tanpa perubahan file
**Date:** 2026-11-06
**Parent plan:** `docs/superpowers/plans/task-01-backend-project-setup.md` (Task 7 section, Step 1–3)
**Pattern reference:** `task-06-readme-and-adr.md`
**Scope note:** Tidak ada commit; Task 8 tidak dimulai; PRD/ROADMAP/hasil Task 1–6 tidak diubah; tidak ada `git checkout/restore/reset/stash`.

## 1. Tujuan

Memverifikasi (bukan memperbaiki) bahwa restructure ROADMAP yang sudah disetujui (30 hari kalender) hadir utuh, CRLF terjaga, konten legacy backend-first hilang, PRD tak tersentuh, dan tidak ada perubahan baru yang masuk selama Task 7.

## 2. Kondisi awal (tercatat sebelum eksekusi)

- `git status --short`: ` M README.md` (Task 6), ` M docs/PRD.md`, ` M docs/ROADMAP.md` (pre-existing), untracked hasil Task 1–6.
- `git diff --stat` tracked: README 42 (Task 6); PRD 828 (414+/414-, pre-existing); ROADMAP 203 (127+/76-, restructure yang disetujui).
- PRD hash: `6f1fe4f9575a276382bc4dee47a95a4206a1be282202da0886a94dabd701313e` (= baseline semua sesi).
- ROADMAP: `CRLF line terminators` ✓; diff awal sudah memuat penghapusan `Task 11`, `69–104`, `Backend Quality Gate` dan penambahan konten `30 hari kalender` + `penyesuaian scope` + strikethrough Open Decision.
- **Semua perbedaan ROADMAP/PRD = perubahan pre-existing yang disetujui** — Task 7 tidak boleh menyentuhnya; tidak ada yang perlu dibedakan sebagai "perubahan Task 7" karena Task 7 tidak mengubah file.

## 3. Rencana (plan)

| Langkah | Aksi | Output |
|---|---|---|
| P1 | Rekam baseline (sudah §2): `git status`, `git diff` PRD/ROADMAP, hash, `file` | kondisi awal |
| P2 | Baca instruksi Task 7 parent plan (Step 1–3) | daftar perintah verifikasi |
| P3 | Baca ROADMAP + PRD + ADR untuk konsistensi keputusan | cek web-first, mobile deferred, Supabase-first, scope adjustment |
| P4 | Jalankan Step 1–3 parent plan **hanya sebagai perintah baca** | hasil grep/hash/file |
| P5 | Pemeriksaan tambahan (tanpa config change): konsistensi ROADMAP↔ADR↔PRD, status Task 1–6, file lain berubah? | bukti |
| P6 | **Tidak ada langkah tulis** — Task 7 verify-only | — |

**Aturan berhenti (HARD STOP):** bila hasil rekonsiliasi menuntut perubahan ROADMAP/PRD, atau perubahan lama vs baru tak bisa dibedakan → jangan edit; laporkan konflik. Berdasarkan P1, kondisi terpenuhi tanpa perubahan apa pun, jadi ekspektasi: **zero file writes**.

## 4. Verifikasi (Step 1–3 parent plan + tambahan user)

**Step 1 — Baseline:**
- V1 `sha256sum docs/PRD.md` = `6f1fe4f9…1313e`
- V2 `file docs/ROADMAP.md` → `CRLF line terminators`

**Step 2 — Restructure hadir:**
- V3 `grep -n "30 hari kalender" docs/ROADMAP.md` → match
- V4 `grep -n "penyesuaian scope"` → match di seksi keputusan backend + Open Decisions
- V5 `grep -nF "~~Pilihan dan bentuk backend final.~~"` → **tepat 1** match
- V6 `grep -n "Monorepo & Supabase Foundation (Task 01)"` → match (tabel 30 hari)
- V7 `grep -nE "Task 11|69–104|Backend Quality Gate|API route, validation"` → tanpa output, exit 1

**Step 3 — Preservasi:**
- V8 hash PRD identik V1
- V9 `file` ROADMAP masih CRLF
- V10 `git diff --ignore-space-at-eol -- docs/ROADMAP.md` → hanya isi restructure yang disetujui (127+/76- pre-existing; tidak ada diff baru di sesi ini)

**Tambahan (user):**
- V11 Konsistensi keputusan: ROADMAP ↔ ADR ↔ PRD — Supabase-first, web MVP prioritas, mobile deferred (Task 12/14 fase 2), penyesuaian scope tercatat di ketiganya; perbedaan PRD §5 vs implementasi = keputusan tersimpan, **bukan** untuk diperbaiki sepihap.
- V12 Status Task 1–6: ROADMAP adalah dokumen rencana (tabel tugas 30 hari) — cek apakah ada kolom status progres; bila tidak ada, catat bahwa pelacakan status bukan peran ROADMAP (bukan konflik); bukti progres = working tree + plan superpowers.
- V13 `git status --short` == kondisi awal §2 (tidak ada file baru/diubah oleh Task 7).
- V14 Tidak ada `docs/superpowers/plans/…` lain yang berubah selain penambahan plan file Task 7 itu sendiri (dokumen rencana = bagian workflow, bukan perubahan artefak proyek).

## 5. Kriteria selesai

- [ ] V1–V14 semua sesuai ekspektasi; **nol perubahan artefak** selain plan file Task 7.
- [ ] Tidak ada konflik yang memicu HARD STOP.
- [ ] PRD & ROADMAP pre-existing utuh; tanpa commit; Task 8 belum dimulai.

## 6. Di luar cakupan

- Task 8 (Full Toolchain Verification) dan berikutnya.
- Edit apa pun ke PRD/ROADMAP/README/ADR/hasil Task 1–6; reset/restore/stash; commit.
